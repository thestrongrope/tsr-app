using System.Data.Common;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminTeachersImport;

// Slice: POST /admin/teachers/import {gender?} -> {added}: give every teacher of an active class who has no training record one, trained for the level they teach (domain/TeacherTraining.ImportedFlags: salman only
// for level 1, each other level from its own up). The body is read first (422 Invalid JSON), then the gender as the list reads it (a gender administrator's own, else the body's: exactly 2 is ladies), then
// teachers:read for that gender (403 "You do not have permission to do that"). One transaction writes the records, histories and events ("Imported from Active Classes"); a failure is 500 "The teachers could not be
// imported, and nothing was changed. Please try again." A second call finds nobody. Contract: spec/api.yaml.
// PHP: routes/teachers.php route_admin_teachers_import (:163), TeachersModel::importActiveTeachers. The teacher's gender is the stored text "1" or "2" (exact). Event: classes.teacher_training_changed per teacher
// (outbox). Bound: 5000 teachers.

internal static partial class AdminTeachersImportSlice
{
    private const int MaxTeachers = 5000;
    private const string Note = "Imported from Active Classes";

    private sealed record Candidate(int Token, int Level);

    internal sealed record Done(int Added);

    [LoggerMessage(Level = LogLevel.Error, Message = "Teacher import failed and was rolled back")]
    private static partial void LogFailed(ILogger logger, Exception exception);

    public static IEndpointRouteBuilder MapAdminTeachersImport(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/teachers/import", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        HttpContext context,
        ClassesContext db,
        Permissions permissions,
        TimeProvider clock,
        ILogger<ClassesContext> log,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var gender = await TeacherWriter.GenderAsync(permissions, caller, PhpValue.Text(body!.Get("gender")), ct);
        if (!await permissions.CanAsync(caller, "teachers:read", AccessTarget.ForGender(gender), ct))
        {
            return Refusals.NotPermitted();
        }

        var genderText = gender.ToString(System.Globalization.CultureInfo.InvariantCulture);
        try
        {
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            var candidates = await db.Database
                .SqlQuery<Candidate>($"""
                    select c.teacher as "Token", min(c.class_level_id) as "Level"
                    from classes.classes c
                    join membership.v_members u on u.token = c.teacher and u.gender = {genderText}
                    where c.status = 'A' and not exists (select 1 from classes.teachers t where t.token = c.teacher)
                    group by c.teacher
                    order by c.teacher
                    limit {MaxTeachers}
                    """)
                .ToListAsync(ct);
            await TeacherWriter.WriteBatchAsync(db, candidates.Select(c => (c.Token, TeacherTraining.ImportedFlags(c.Level))).ToList(), Note, caller.Token, clock, ct);
            await transaction.CommitAsync(ct);
            return Results.Json(new Done(candidates.Count));
        }
        catch (DbException e)
        {
            LogFailed(log, e);
            return Problem.Detail(StatusCodes.Status500InternalServerError, "The teachers could not be imported, and nothing was changed. Please try again.");
        }
    }
}
