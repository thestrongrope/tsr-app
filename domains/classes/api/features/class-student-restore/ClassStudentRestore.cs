using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassStudentRestore;

// Slice: POST /classes/{class_id}/students/{token}/restore -> put a removed student back; answers with the roster payload (domain/ClassRoster.cs). Contract: spec/api.yaml.
// PHP: routes/class_manage.php route_class_student_restore (:848), ClassStudentsModel::restoreStudent. Order: active complete class (404), students:enrol on the class (403), the member is on the REMOVED list
// (domain/ClassRoster.IsRemovedAsync; 404 "Student is not in the removed list": a live student, a stranger and a member moved to another class all get it). No body is read. Writes EVERY enrolment row of the pair:
// status A, removed_at, removed_by and removed_reason cleared; joined_on and mcq_admin untouched. No gender or duplicate check, no lock, as PHP.
// Event: classes.student_restored (outbox, same transaction). PHP's search touch (person) is not sent.

internal static class ClassStudentRestoreSlice
{
    internal sealed record StudentRestored(int ClassId, int Token, int RestoredBy);

    public static IEndpointRouteBuilder MapClassStudentRestore(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/{class_id}/students/{token}/restore", HandleAsync).RequireMember(createsMember: true);
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

        if (!await permissions.CanAsync(caller, "students:enrol", AccessTarget.ForClass(head.Id), ct))
        {
            return Refusals.NotPermittedToChangeStudents();
        }

        var student = ClassGuards.TokenOf(token);
        if (!await ClassRoster.IsRemovedAsync(db, head.Id, student, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Student is not in the removed list");
        }

        await SaveAsync(db, clock, head.Id, student, caller.Token, ct);
        return Results.Json(await ClassRoster.BuildAsync(db, permissions, caller, head.Id, ct));
    }

    private static async Task SaveAsync(ClassesContext db, TimeProvider clock, int classId, int student, int by, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlAsync(
            $"update classes.class_students set status = 'A', removed_at = null, removed_by = null, removed_reason = null where class_id = {classId} and token_no = {student}",
            ct);
        await Outbox.WriteAsync(db, "classes.student_restored", new StudentRestored(classId, student, by), clock, ct);
        await transaction.CommitAsync(ct);
    }
}
