using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.ClassScheduledList;

// Slice: GET /classes/{class_id}/notifications/scheduled -> {items, schedules}: a class's scheduled notifications (newest first, with creator, slot, next run and last run) and its live
// schedule slots (the reminder form needs their ids). Contract: spec/api.yaml. PHP: routes/classes.php route_class_notifications_scheduled_list. Order: the class (404 "Class not found"),
// notifications:send on it (403 "You do not have permission to send notifications for this class"). Deviation: at most 500 items (PHP has no cap).

internal static class ClassScheduledListSlice
{
    internal sealed record Slot(int Id, int Day, int Hour, int Minute, string Timezone);

    public static IEndpointRouteBuilder MapClassScheduledList(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/notifications/scheduled", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var classId = NotifyGuards.IdOf(class_id);
        var refusal = await NotifyGuards.ClassAccessAsync(source, permissions, caller, classId, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var now = clock.GetUtcNow();
        var rows = await ScheduledRows.QueryAsync(source, classId, 0, ct);
        var lastRuns = await ScheduledRows.LastRunsAsync(source, rows.Select(r => r.Id), ct);
        var items = rows.Select(r => ScheduledRows.Item(r, lastRuns.GetValueOrDefault(r.Id), now)).ToList();
        var slots = await source.ListAsync(
            $"""
            select id as "Id", coalesce(day, 0) as "Day", coalesce(hour, 0) as "Hour", coalesce(minute, 0) as "Minute", coalesce(timezone, '') as "Timezone"
            from classes.v_class_schedules where class_id = {classId} and deleted_at is null order by day, hour, minute
            """,
            row => new Slot(row.Int("Id"), row.Int("Day"), row.Int("Hour"), row.Int("Minute"), row.Text("Timezone")),
            ct);
        return Results.Json(new Dictionary<string, object?> { ["items"] = items, ["schedules"] = slots.Select(s => new Dictionary<string, object?> { ["id"] = s.Id, ["day"] = s.Day, ["hour"] = s.Hour, ["minute"] = s.Minute, ["timezone"] = s.Timezone }).ToList() }, NotificationsJson.Answers.Answer);
    }
}
