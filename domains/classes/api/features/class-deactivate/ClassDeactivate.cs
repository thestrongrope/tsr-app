using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
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
        var rows = await source.ListAsync(
            $"""select id as "Id", status as "Status" from classes.classes where id = {id} limit 1""",
            row => new Existing(row.Int("Id"), row.Text("Status")),
            ct);
        if (rows.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, $"Class #{id} not found");
        }

        if (rows[0].Status != "A")
        {
            return NotActive(id, rows[0].Status);
        }

        var auditId = await SaveAsync(source, clock, rows[0].Id, input.Value!, caller.Token, ct);
        if (auditId is null)
        {
            return NotActive(id, "I");
        }

        return Results.Json(new Dictionary<string, object?> { ["deactivated"] = true, ["classId"] = id, ["auditId"] = auditId.Value }, ClassesJson.Answers.Answer);
    }

    private static IResult NotActive(long id, string status) =>
        Problem.Detail(StatusCodes.Status409Conflict, $"Class #{id} is not active (status={status})");

    private static string TextOf(JsonElement value) => value.ValueKind == JsonValueKind.String ? value.GetString()! : string.Empty;

    // The audit id, or null when another request deactivated the class first.
    private static async Task<long?> SaveAsync(NpgsqlDataSource source, TimeProvider clock, int classId, DeactivationRules.Input input, int admin, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        var date = input.EffectiveDate.ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
        var completed = input.Type == "completed" ? date : null;
        var shutdown = input.Type == "shutdown" ? date : null;
        var changed = await tx.ExecuteAsync(
            $"""
            update classes.classes
            set status = 'I', comments = {input.Reason}, completed_on = {completed}::date, shutdown_on = {shutdown}::date,
                updated_by = {admin}, updated_at = now(), deleted_by = {admin}, deleted_at = now()
            where id = {classId} and status = 'A'
            """,
            ct);
        if (changed == 0)
        {
            return null;
        }

        var tokens = await tx.ListAsync(
            $"""select token_no as "Value" from classes.class_students where class_id = {classId} and removed_at is null and status = 'A' order by token_no""",
            row => row.Int("Value"),
            ct);
        var studentReason = DeactivationRules.StudentReason(input.Reason);
        await tx.ExecuteAsync(
            $"update classes.class_students set removed_at = now(), removed_by = {admin}, status = 'I', removed_reason = {studentReason} where class_id = {classId} and removed_at is null and status = 'A'",
            ct);
        await tx.ExecuteAsync(
            $"""
            update classes.class_schedule_topics set deleted_at = now(), deleted_by = {admin}
            where deleted_at is null and class_schedule_id in (select id from classes.class_schedules where class_id = {classId})
            """,
            ct);
        await tx.ExecuteAsync(
            $"update classes.class_schedules set deleted_at = now(), deleted_by = {admin} where class_id = {classId} and deleted_at is null", ct);

        var details = JsonSerializer.Serialize(
            new Dictionary<string, string> { ["type"] = input.Type, ["effective_date"] = date, ["reason"] = input.Reason },
            ClassesJson.Answers.StringMap);
        var auditId = await tx.ScalarAsync<long>(
            $"""
            insert into classes.class_audit_log (class_id, action, details, performed_by) values ({classId}, 'deactivated', {details}, {admin})
            returning id as "Value"
            """,
            ct) ?? throw new InvalidOperationException("The audit row returned no id.");

        await Outbox.WriteAsync(
            tx,
            "classes.class_deactivated",
            new ClassDeactivated(classId, input.Type, date, auditId, [.. tokens], admin),
            ClassesJson.Default.ClassDeactivated,
            clock,
            ct);
        await tx.CommitAsync(ct);
        return auditId;
    }
}
