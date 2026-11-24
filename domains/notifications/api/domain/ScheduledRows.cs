using Npgsql;

namespace Tsr.Notifications.Api.Domain;

/// <summary>A scheduled notification with its creator's name and its schedule slot (deleted slots included), as PHP's <c>find</c> and <c>listByClass</c> read it.</summary>
internal sealed record ScheduledRow(
    int Id,
    string Title,
    string Body,
    string? ActionLink,
    string Kind,
    DateTime? SendAt,
    string? Weekdays,
    TimeOnly? SendTime,
    string? Tz,
    int? ClassScheduleId,
    int? OffsetMinutes,
    short RepeatWeekly,
    string Status,
    int CreatedBy,
    DateTimeOffset CreatedAt,
    string? CreatorName,
    int? SlotId,
    int? SlotDay,
    int? SlotHour,
    int? SlotMinute,
    string? SlotTimezone,
    DateTimeOffset? SlotDeletedAt);

/// <summary>The latest firing of a scheduled notification (PHP <c>lastRuns</c>).</summary>
internal sealed record ScheduledLastRun(int ScheduledId, DateTimeOffset RunAt, int? NotificationId, int StudentCount, int DeviceCount, int SuccessCount, int FailureCount, string? SkippedReason);

/// <summary>Reads of a class's scheduled notifications and their wire form (PHP <c>api_scheduled_item</c>). The slots come from classes' published view.</summary>
internal static class ScheduledRows
{
    /// <summary>PHP lists every row of a class; this cap is ours.</summary>
    public const int MaxListed = 500;

    /// <summary>The rows of a class, newest first: one by id when <paramref name="id"/> is above zero, else up to <see cref="MaxListed"/>.</summary>
    public static async Task<List<ScheduledRow>> QueryAsync(NpgsqlDataSource source, int classId, int id, CancellationToken ct) =>
        await source.ListAsync($"""
            select s.id as "Id", s.title as "Title", s.body as "Body", s.action_link as "ActionLink", s.kind as "Kind", s.send_at as "SendAt", s.weekdays as "Weekdays",
                   s.send_time as "SendTime", s.tz as "Tz", s.class_schedule_id as "ClassScheduleId", s.offset_minutes as "OffsetMinutes", s.repeat_weekly as "RepeatWeekly",
                   s.status as "Status", s.created_by as "CreatedBy", s.created_at as "CreatedAt",
                   (select m.name from membership.v_members m where m.token = s.created_by order by m.user_id limit 1) as "CreatorName",
                   cs.id as "SlotId", cs.day as "SlotDay", cs.hour as "SlotHour", cs.minute as "SlotMinute", cs.timezone as "SlotTimezone", cs.deleted_at as "SlotDeletedAt"
            from notifications.class_scheduled_notifications s
            left join classes.v_class_schedules cs on cs.id = s.class_schedule_id
            where s.class_id = {classId} and ({id} = 0 or s.id = {id})
            order by s.id desc
            limit {MaxListed}
            """, ReadRow, ct);

    private static ScheduledRow ReadRow(DbRow row) => new(
        row.Int("Id"),
        row.Text("Title"),
        row.Text("Body"),
        row.TextOrNull("ActionLink"),
        row.Text("Kind"),
        row.LocalTimestampOrNull("SendAt"),
        row.TextOrNull("Weekdays"),
        row.TimeOrNull("SendTime"),
        row.TextOrNull("Tz"),
        row.IntOrNull("ClassScheduleId"),
        row.IntOrNull("OffsetMinutes"),
        row.Short("RepeatWeekly"),
        row.Text("Status"),
        row.Int("CreatedBy"),
        row.Instant("CreatedAt"),
        row.TextOrNull("CreatorName"),
        row.IntOrNull("SlotId"),
        row.IntOrNull("SlotDay"),
        row.IntOrNull("SlotHour"),
        row.IntOrNull("SlotMinute"),
        row.TextOrNull("SlotTimezone"),
        row.InstantOrNull("SlotDeletedAt"));

    public static async Task<Dictionary<int, ScheduledLastRun>> LastRunsAsync(NpgsqlDataSource source, IEnumerable<int> ids, CancellationToken ct)
    {
        var wanted = ids.ToArray();
        if (wanted.Length == 0)
        {
            return [];
        }

        var rows = await source.ListAsync($"""
            select distinct on (scheduled_id) scheduled_id as "ScheduledId", run_at as "RunAt", notification_id as "NotificationId", student_count as "StudentCount",
                   device_count as "DeviceCount", success_count as "SuccessCount", failure_count as "FailureCount", skipped_reason as "SkippedReason"
            from notifications.class_scheduled_notification_runs
            where scheduled_id = any({wanted})
            order by scheduled_id, id desc
            """, row => new ScheduledLastRun(
                row.Int("ScheduledId"),
                row.Instant("RunAt"),
                row.IntOrNull("NotificationId"),
                row.Int("StudentCount"),
                row.Int("DeviceCount"),
                row.Int("SuccessCount"),
                row.Int("FailureCount"),
                row.TextOrNull("SkippedReason")), ct);
        return rows.ToDictionary(r => r.ScheduledId);
    }

    public static Dictionary<string, object?> Item(ScheduledRow row, ScheduledLastRun? lastRun, DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(row);
        var slot = row.SlotId is null ? null : new SlotRef(row.SlotDay ?? 0, row.SlotHour ?? 0, row.SlotMinute ?? 0, row.SlotTimezone ?? string.Empty);
        var liveSlot = row.SlotDeletedAt is null ? slot : null;
        var next = ScheduleNextRun.Of(new NextRunInput(row.Status, row.Kind, row.SendAt, row.Tz, row.Weekdays, row.SendTime, row.OffsetMinutes, liveSlot), now);
        return new Dictionary<string, object?>
        {
            ["id"] = row.Id,
            ["kind"] = row.Kind,
            ["title"] = row.Title,
            ["body"] = row.Body,
            ["action_link"] = row.ActionLink,
            ["status"] = row.Status,
            ["created_by"] = row.CreatedBy,
            ["creator_name"] = row.CreatorName,
            ["created_at"] = NotifyGuards.Stamp(row.CreatedAt),
            ["next_run"] = next?.ToString("yyyy-MM-dd'T'HH:mm:sszzz", System.Globalization.CultureInfo.InvariantCulture),
            ["send_at"] = row.SendAt?.ToString("yyyy-MM-dd'T'HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture),
            ["weekdays"] = ScheduleNextRun.Weekdays(row.Weekdays),
            ["send_time"] = row.SendTime?.ToString("HH:mm", System.Globalization.CultureInfo.InvariantCulture),
            ["timezone"] = slot is null ? row.Tz : slot.Timezone,
            ["class_schedule_id"] = row.ClassScheduleId is > 0 ? row.ClassScheduleId : null,
            ["offset_minutes"] = row.OffsetMinutes,
            ["repeat_weekly"] = row.RepeatWeekly != 0,
            ["schedule"] = slot is null ? null : new Dictionary<string, object?> { ["id"] = row.SlotId!.Value, ["day"] = slot.Day, ["hour"] = slot.Hour, ["minute"] = slot.Minute, ["timezone"] = slot.Timezone },
            ["last_run"] = lastRun is null ? null : LastRun(lastRun),
        };
    }

    private static Dictionary<string, object?> LastRun(ScheduledLastRun run) => new()
    {
        ["run_at"] = NotifyGuards.Stamp(run.RunAt),
        ["notification_id"] = run.NotificationId,
        ["student_count"] = run.StudentCount,
        ["device_count"] = run.DeviceCount,
        ["success_count"] = run.SuccessCount,
        ["failure_count"] = run.FailureCount,
        ["skipped_reason"] = run.SkippedReason,
    };
}
