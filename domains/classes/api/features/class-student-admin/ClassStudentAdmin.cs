using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassStudentAdmin;

// Slice: PUT /classes/{class_id}/students/{token}/class-admin {status} -> set or clear a student's MCQ-admin flag; answers with the roster payload (domain/ClassRoster.cs). Contract: spec/api.yaml.
// PHP: routes/class_manage.php route_class_student_class_admin (:861), ClassStudentsModel::updateClassAdmin. Order: active complete class (404), class-students:update on the class (403, "set the MCQ-admin flag"),
// the member is on the active roster (404 "Student not found in this class"), status is a JSON true or false (422). The flag is written on every enrolment row of the pair, removed ones too; no other column,
// no audit row. Access reads this flag (IClassScopes), so it changes what the student may do. Event: classes.student_class_admin_changed (outbox, same transaction).

internal static class ClassStudentAdminSlice
{
    internal sealed record StudentClassAdminChanged(int ClassId, int Token, bool McqAdmin, int ChangedBy);

    public static IEndpointRouteBuilder MapClassStudentAdmin(this IEndpointRouteBuilder routes)
    {
        routes.MapPut("/classes/{class_id}/students/{token}/class-admin", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string class_id,
        string token,
        HttpContext context,
        ClassesContext db,
        Permissions permissions,
        TimeProvider clock,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var head = await ClassGuards.FindActiveClassAsync(db, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "class-students:update", AccessTarget.ForClass(head.Id), ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to set the MCQ-admin flag");
        }

        var student = ClassGuards.TokenOf(token);
        if (!await ClassRoster.IsActiveAsync(db, head.Id, student, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Student not found in this class");
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var status = body!.Get("status");
        if (status.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "status must be true or false");
        }

        var flag = status.ValueKind == JsonValueKind.True;
        await SaveAsync(db, clock, head.Id, student, flag, caller.Token, ct);
        return Results.Json(await ClassRoster.BuildAsync(db, permissions, caller, head.Id, ct));
    }

    private static async Task SaveAsync(ClassesContext db, TimeProvider clock, int classId, int student, bool flag, int by, CancellationToken ct)
    {
        var value = flag ? 1 : 0;
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlAsync($"update classes.class_students set mcq_admin = {value} where class_id = {classId} and token_no = {student}", ct);
        await Outbox.WriteAsync(db, "classes.student_class_admin_changed", new StudentClassAdminChanged(classId, student, flag, by), clock, ct);
        await transaction.CommitAsync(ct);
    }
}
