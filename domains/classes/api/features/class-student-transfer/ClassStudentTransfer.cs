using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassStudentTransfer;

// Slice: POST /classes/{class_id}/students/{token}/transfer {toClassId, type?, reason?} -> move a student to another class of the same gender; answers with the SOURCE class's roster payload. Contract: spec/api.yaml.
// PHP: routes/class_manage.php route_class_student_transfer (:878), ClassStudentsModel::transferStudent. Order: active complete class (404), students:transfer with NO target (403 "Only administrators can transfer students"),
// the member is on the active roster (404), then 422s: toClassId a JSON integer other than this class (422 "toClassId must be a different class"), type exactly transfer, promotion or demotion (default transfer), reason
// (string) trimmed at most 500 characters; then the destination is an active complete class (404 "Class not found") of the same gender (422). One transaction: the member must not be active in the destination (422
// "Student <token> is already enrolled in destination class #<id>"); the source rows that are not removed get removed_at now, removed_by, status I and removed_reason "<Type> to class #<id>[: reason]" (mcq_admin
// untouched); a NEW destination row (joined_on today; no added_by, no notes or MCQ flag carried); a student_transfers row. No lock, as PHP. PHP's re-homing of a deactivated class's cohort is not reachable here
// (the roster check above needs an active row) and belongs to the deactivation slice. Deviation: a reason that makes the removal reason longer than 500 characters is a 422 (PHP's column would refuse it).
// Event: classes.student_transferred (outbox, same transaction). PHP's search touch is not sent.

internal static class ClassStudentTransferSlice
{
    private const int MaxReason = 500;
    private static readonly string[] Types = ["transfer", "promotion", "demotion"];

    internal sealed record StudentTransferred(int FromClassId, int ToClassId, int Token, string Type, int TransferredBy);

    public static IEndpointRouteBuilder MapClassStudentTransfer(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/{class_id}/students/{token}/transfer", HandleAsync).RequireMember(createsMember: true);
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

        var source = await ClassGuards.FindActiveClassAsync(db, ClassGuards.IdOf(class_id), ct);
        if (source is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "students:transfer", AccessTarget.None, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "Only administrators can transfer students");
        }

        var student = ClassGuards.TokenOf(token);
        if (!await ClassRoster.IsActiveAsync(db, source.Id, student, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Student not found in this class");
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var input = Parse(body!, source.Id);
        if (!input.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, input.Error!);
        }

        var destination = await ClassGuards.FindActiveClassAsync(db, input.Value!.ToClassId, ct);
        if (destination is null)
        {
            return Refusals.ClassNotFound();
        }

        if (destination.Gender != source.Gender)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "A student can only move to a class of the same gender");
        }

        var failure = await SaveAsync(db, clock, source.Id, destination.Id, student, input.Value, caller.Token, ct);
        if (failure is not null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, failure);
        }

        return Results.Json(await ClassRoster.BuildAsync(db, permissions, caller, source.Id, ct));
    }

    private sealed record Input(long ToClassId, string Type, string Reason);

    private static Result<Input> Parse(JsonBody body, int sourceId)
    {
        var to = body.Get("toClassId");
        if (!PhpValue.IsInt(to, out var toClassId) || toClassId == sourceId)
        {
            return Result.Fail<Input>("toClassId must be a different class");
        }

        var type = body.Get("type");
        var typeText = type.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined ? "transfer" : type.ValueKind == JsonValueKind.String ? type.GetString()! : string.Empty;
        if (!Types.Contains(typeText))
        {
            return Result.Fail<Input>("type must be transfer, promotion or demotion");
        }

        var reason = PhpText.Trim(PhpValue.Text(body.Get("reason")));
        if (PhpText.CodePointCount(reason) > MaxReason || reason.Contains('\0', StringComparison.Ordinal))
        {
            return Result.Fail<Input>("reason must be at most 500 characters");
        }

        return Result.Ok(new Input(toClassId, typeText, reason));
    }

    // Null when moved; else the refusal text (PHP's exception message).
    private static async Task<string?> SaveAsync(ClassesContext db, TimeProvider clock, int from, int to, int student, Input input, int by, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var already = await db.Database
            .SqlQuery<int>($"""select 1 as "Value" from classes.class_students where class_id = {to} and token_no = {student} and removed_at is null and status = 'A' limit 1""")
            .ToListAsync(ct);
        if (already.Count > 0)
        {
            return $"Student {student} is already enrolled in destination class #{to}";
        }

        var removal = EnrolmentRules.TransferReason(input.Type, input.Reason, to);
        if (PhpText.CodePointCount(removal) > MaxReason)
        {
            return "reason must be at most 500 characters";
        }

        await db.Database.ExecuteSqlAsync(
            $"update classes.class_students set removed_at = now(), removed_by = {by}, status = 'I', removed_reason = {removal} where class_id = {from} and token_no = {student} and removed_at is null",
            ct);
        await db.Database.ExecuteSqlAsync(
            $"insert into classes.class_students (class_id, token_no, joined_on) values ({to}, {student}, (now() at time zone 'UTC')::date)", ct);
        await db.Database.ExecuteSqlAsync(
            $"insert into classes.student_transfers (token_no, from_class_id, to_class_id, type, reason, transferred_by) values ({student}, {from}, {to}, {input.Type}, {input.Reason}, {by})",
            ct);
        await Outbox.WriteAsync(db, "classes.student_transferred", new StudentTransferred(from, to, student, input.Type, by), clock, ct);
        await transaction.CommitAsync(ct);
        return null;
    }
}
