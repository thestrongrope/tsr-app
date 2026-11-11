using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.RegistrationClasses;

// Slice: GET /registrations/{registration_id}/classes -> the classes a waiting registrant could be placed in. Answers {classes: [{id, code, level, teacher, location, students}]}. Contract: spec/api.yaml.
// PHP: routes/registrations.php route_registrations_classes (:38), ClassesModel::getAll. Order: the waiting-registrant guard (domain/WaitingRegistrant.cs), then the active classes of the registrant's gender (every
// gender when it is not a positive number, as PHP's `if ($gender > 0)`), limited to the caller's assigned classes when assigned is their only classes:read reach (access's AssignedOnlyIds), ordered gender, level
// sort order, id, and kept only where the caller holds students:enrol on the class. students counts rows not removed, whatever their status (extra students are not counted). Read only.

internal static class RegistrationClassesSlice
{
    private const int MaxRows = 5000;

    private sealed record Row(int Id, string Code, string Level, string? Teacher, string? Location, long Students);

    public static IEndpointRouteBuilder MapRegistrationClasses(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/registrations/{registration_id}/classes", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string registration_id, HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (registrant, refusal) = await WaitingRegistrant.RequireAsync(db, permissions, caller, registration_id, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var assigned = (await permissions.ReachAsync(caller, "classes:read", ct)).AssignedOnlyIds;
        var rows = await ClassesAsync(db, registrant!.Gender, assigned, ct);
        var classes = new List<Dictionary<string, object?>>();
        foreach (var row in rows)
        {
            if (await permissions.CanAsync(caller, "students:enrol", AccessTarget.ForClass(row.Id), ct))
            {
                classes.Add(new Dictionary<string, object?>
                {
                    ["id"] = row.Id,
                    ["code"] = row.Code,
                    ["level"] = row.Level,
                    ["teacher"] = row.Teacher,
                    ["location"] = row.Location is null ? null : PhpText.HtmlDecode(row.Location),
                    ["students"] = row.Students,
                });
            }
        }

        return Results.Json(new Dictionary<string, object?> { ["classes"] = classes });
    }

    private static async Task<List<Row>> ClassesAsync(ClassesContext db, int gender, IReadOnlyList<int>? assigned, CancellationToken ct)
    {
        var limited = assigned is not null;
        var ids = assigned?.ToArray() ?? [];
        return await db.Database
            .SqlQuery<Row>($"""
                select c.id as "Id", c.code as "Code", cl.name as "Level", t.name as "Teacher", c.location as "Location",
                       (select count(1) from classes.class_students cs where cs.class_id = c.id and cs.removed_at is null) as "Students"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members t on t.token = c.teacher
                where c.status = 'A'
                  and ({gender} <= 0 or c.gender = {gender})
                  and (not {limited} or c.id = any({ids}))
                order by c.gender, cl.sort_order, c.id
                limit {MaxRows}
                """)
            .ToListAsync(ct);
    }
}
