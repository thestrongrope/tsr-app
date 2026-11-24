using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassStudentRemove;

// Slice: POST /classes/{class_id}/students/{token}/remove {reason} -> take a student off the class; answers with the roster payload (domain/ClassRoster.cs). Contract: spec/api.yaml.
// PHP: routes/class_manage.php route_class_student_remove (:831), ClassStudentsModel::removeStudent. Order: active complete class (404), students:enrol on the class (403, "change this class's students"),
// the member is on the active roster (404 "Student not found in this class"), reason: (string) trimmed, 1 to 500 characters (422). Writes EVERY enrolment row of the pair: removed_at now, removed_by the caller,
// status I, removed_reason, mcq_admin 0 (older removal data is overwritten). No lock, as PHP. Deviation: a NUL byte in the reason is a 422 (PostgreSQL text cannot hold it; PHP stores it).
// Event: classes.student_removed (outbox, same transaction). PHP's search touch (person) and any message are not sent: the outbox row is the hand-off.

internal static class ClassStudentRemoveSlice
{
    private const int MaxReason = 500;

    internal sealed record StudentRemoved(int ClassId, int Token, int RemovedBy);

    public static IEndpointRouteBuilder MapClassStudentRemove(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/{class_id}/students/{token}/remove", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string class_id,
        string token,
        HttpContext context,
        NpgsqlDataSource source,
        Permissions permissions,
        TimeProvider clock,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var head = await ClassGuards.FindActiveClassAsync(source, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "students:enrol", AccessTarget.ForClass(head.Id), ct))
        {
            return Refusals.NotPermittedToChangeStudents();
        }

        var student = ClassGuards.TokenOf(token);
        if (!await ClassRoster.IsActiveAsync(source, head.Id, student, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Student not found in this class");
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var reason = PhpText.Trim(PhpValue.Text(body!.Get("reason")));
        if (reason.Length == 0 || PhpText.CodePointCount(reason) > MaxReason || reason.Contains('\0', StringComparison.Ordinal))
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "reason is required and must be at most 500 characters");
        }

        await SaveAsync(source, clock, head.Id, student, reason, caller.Token, ct);
        return Results.Json(await ClassRoster.BuildAsync(source, permissions, caller, head.Id, ct), ClassesJson.Answers.Answer);
    }

    private static async Task SaveAsync(NpgsqlDataSource source, TimeProvider clock, int classId, int student, string reason, int by, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        await tx.ExecuteAsync(
            $"update classes.class_students set removed_at = now(), removed_by = {by}, status = 'I', removed_reason = {reason}, mcq_admin = 0 where class_id = {classId} and token_no = {student}",
            ct);
        await Outbox.WriteAsync(tx, "classes.student_removed", new StudentRemoved(classId, student, by), ClassesJson.Default.StudentRemoved, clock, ct);
        await tx.CommitAsync(ct);
    }
}
