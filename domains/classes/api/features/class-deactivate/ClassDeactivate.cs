using System.Text.Encodings.Web;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassDeactivate;

// Slice: POST /classes/{class_id}/deactivate {type, effectiveDate, reason} -> retire a class; answers {deactivated, classId, auditId}. Contract: spec/api.yaml.
// PHP: routes/deactivated_classes.php route_class_deactivate, ClassesModel::deactivate. Order: deactivated-classes:manage with NO target (403 "You do not have permission to do that"; PHP never looks the class up first),
// the body (a field that is not text counts as ''), then 422s in PHP's order (type, date, reason; domain/DeactivationRules.cs), then the class by the (int) id: 404 "Class #<id> not found", 409 "Class #<id> is not active
// (status=<s>)". One transaction: the class gets status I, comments = reason, completed_on or shutdown_on = the date (the other null), updated_by/updated_at and deleted_by/deleted_at; every active enrolment row gets
// removed_at now, removed_by, status I and "Class deactivated: <reason>" (mcq_admin untouched); the class's live schedules and their live topic rows get deleted_at/deleted_by; one class_audit_log row (action deactivated,
// details JSON {type, effective_date, reason}). Untouched: tags, access grants, quizzes, scheduled notifications. No admin_access_log row (PHP's route writes none).
// Deviations: a student removal reason is cut to 300 bytes on a character boundary (PHP cuts bytes); a reason with a NUL character is 422 (PostgreSQL cannot store it); a deactivation that loses a race with another is 409.
// Event: classes.class_deactivated (outbox, same transaction); PHP's search touches are not sent. The deactivated cohort's re-homing by transfer is unreachable: transfer needs an active source class.

internal static class ClassDeactivateSlice
{
    private static readonly JsonSerializerOptions AuditJson = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    internal sealed record ClassDeactivated(int ClassId, string Type, string EffectiveDate, long AuditId, int[] RemovedTokens, int DeactivatedBy);

    private sealed record Existing(int Id, string Status);

    public static IEndpointRouteBuilder MapClassDeactivate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/{class_id}/deactivate", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string class_id,
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

        if (!await permissions.CanAsync(caller, "deactivated-classes:manage", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var reasonText = TextOf(body!.Get("reason"));
        if (reasonText.Contains('\0', StringComparison.Ordinal))
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Reason must not contain NUL characters");
        }

        var input = DeactivationRules.Parse(TextOf(body.Get("type")), TextOf(body.Get("effectiveDate")), reasonText);
        if (!input.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, input.Error!);
        }

        var id = ClassGuards.IdOf(class_id);
        var rows = await db.Database
            .SqlQuery<Existing>($"""select id as "Id", status as "Status" from classes.classes where id = {id} limit 1""")
            .ToListAsync(ct);
        if (rows.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, $"Class #{id} not found");
        }

        if (rows[0].Status != "A")
        {
            return NotActive(id, rows[0].Status);
        }

        var auditId = await SaveAsync(db, clock, rows[0].Id, input.Value!, caller.Token, ct);
        if (auditId is null)
        {
            return NotActive(id, "I");
        }

        return Results.Json(new Dictionary<string, object> { ["deactivated"] = true, ["classId"] = id, ["auditId"] = auditId.Value });
    }

    private static IResult NotActive(long id, string status) =>
        Problem.Detail(StatusCodes.Status409Conflict, $"Class #{id} is not active (status={status})");

    private static string TextOf(JsonElement value) => value.ValueKind == JsonValueKind.String ? value.GetString()! : string.Empty;

    // The audit id, or null when another request deactivated the class first.
    private static async Task<long?> SaveAsync(ClassesContext db, TimeProvider clock, int classId, DeactivationRules.Input input, int admin, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var completed = input.Type == "completed" ? input.EffectiveDate : (DateOnly?)null;
        var shutdown = input.Type == "shutdown" ? input.EffectiveDate : (DateOnly?)null;
        var changed = await db.Database.ExecuteSqlAsync(
            $"""
            update classes.classes
            set status = 'I', comments = {input.Reason}, completed_on = {completed}, shutdown_on = {shutdown},
                updated_by = {admin}, updated_at = now(), deleted_by = {admin}, deleted_at = now()
            where id = {classId} and status = 'A'
            """,
            ct);
        if (changed == 0)
        {
            return null;
        }

        var tokens = await db.Database
            .SqlQuery<int>($"""select token_no as "Value" from classes.class_students where class_id = {classId} and removed_at is null and status = 'A' order by token_no""")
            .ToListAsync(ct);
        var studentReason = DeactivationRules.StudentReason(input.Reason);
        await db.Database.ExecuteSqlAsync(
            $"update classes.class_students set removed_at = now(), removed_by = {admin}, status = 'I', removed_reason = {studentReason} where class_id = {classId} and removed_at is null and status = 'A'",
            ct);
        await db.Database.ExecuteSqlAsync(
            $"""
            update classes.class_schedule_topics set deleted_at = now(), deleted_by = {admin}
            where deleted_at is null and class_schedule_id in (select id from classes.class_schedules where class_id = {classId})
            """,
            ct);
        await db.Database.ExecuteSqlAsync(
            $"update classes.class_schedules set deleted_at = now(), deleted_by = {admin} where class_id = {classId} and deleted_at is null", ct);

        var date = input.EffectiveDate.ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
        var details = JsonSerializer.Serialize(
            new Dictionary<string, string> { ["type"] = input.Type, ["effective_date"] = date, ["reason"] = input.Reason },
            AuditJson);
        var audit = new ClassAuditEntry { ClassId = classId, Action = "deactivated", Details = details, PerformedBy = admin };
        db.Set<ClassAuditEntry>().Add(audit);
        await db.SaveChangesAsync(ct);

        await Outbox.WriteAsync(
            db,
            "classes.class_deactivated",
            new ClassDeactivated(classId, input.Type, date, audit.Id, [.. tokens], admin),
            clock,
            ct);
        await transaction.CommitAsync(ct);
        return audit.Id;
    }
}
