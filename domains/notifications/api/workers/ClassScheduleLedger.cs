using Microsoft.EntityFrameworkCore;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Workers;

/// <summary>An active scheduled notification as the worker reads it, with its class schedule slot (deleted slots included) from classes' published view.</summary>
internal sealed record DueRow(
    int Id,
    int ClassId,
    int CreatedBy,
    int CreatedByUserId,
    string Title,
    string Body,
    string? ActionLink,
    string Kind,
    DateTime? SendAt,
    string? Weekdays,
    TimeOnly? SendTime,
    string Tz,
    int? OffsetMinutes,
    short RepeatWeekly,
    string? LastRunKey,
    DateTimeOffset CreatedAt,
    int? SlotId,
    int? SlotClassId,
    int? SlotDay,
    int? SlotHour,
    int? SlotMinute,
    string? SlotTimezone,
    DateTimeOffset? SlotDeletedAt)
{
    /// <summary>A slot that is absent, deleted or another class's counts as gone.</summary>
    private bool SlotIsGone => SlotId is null || SlotDeletedAt is not null || SlotClassId != ClassId;

    /// <summary>True for a row that ends with its one send: ONCE, and a REMINDER that does not repeat.</summary>
    public bool EndsAfterSend => Kind == "ONCE" || (Kind == "REMINDER" && RepeatWeekly == 0);

    public DueInput ToInput() => new(
        Kind,
        SendAt,
        Tz,
        Weekdays,
        SendTime,
        OffsetMinutes,
        SlotIsGone ? null : new SlotRef(SlotDay ?? 0, SlotHour ?? 0, SlotMinute ?? 0, SlotTimezone ?? string.Empty),
        LastRunKey,
        CreatedAt);
}

/// <summary>
/// The scheduled notifications' tables as the worker writes them: the page of active rows, the claim of an occurrence, the run ledger, the hourly and daily limits. Every time written is the caller's clock,
/// never the database's, so a fixed clock is a fixed ledger. A claim is a conditional update, so two instances cannot record one occurrence twice.
/// </summary>
internal static class ClassScheduleLedger
{
    public const int PageSize = 200;
    public const int MaxPages = 25;
    public const int MaxSendsPerHour = 10;
    public const int MaxSendsPerDay = 3;

    // send_at is a wall clock in the row's own zone, so SQL can only rule out rows that are later than any zone's wall clock could be (UTC+14, with margin).
    private const int MaxAheadOfUtcHours = 15;

    public static async Task<List<DueRow>> PageAsync(NotificationsContext db, DateTimeOffset now, int afterId, CancellationToken ct)
    {
        var bound = now.ToUniversalTime().AddHours(MaxAheadOfUtcHours);
        return await db.Database.SqlQuery<DueRow>($"""
            select s.id as "Id", s.class_id as "ClassId", s.created_by as "CreatedBy", s.created_by_user_id as "CreatedByUserId", s.title as "Title", s.body as "Body", s.action_link as "ActionLink",
                   s.kind as "Kind", s.send_at as "SendAt", s.weekdays as "Weekdays", s.send_time as "SendTime", s.tz as "Tz", s.offset_minutes as "OffsetMinutes", s.repeat_weekly as "RepeatWeekly",
                   s.last_run_key as "LastRunKey", s.created_at as "CreatedAt",
                   cs.id as "SlotId", cs.class_id as "SlotClassId", cs.day as "SlotDay", cs.hour as "SlotHour", cs.minute as "SlotMinute", cs.timezone as "SlotTimezone", cs.deleted_at as "SlotDeletedAt"
            from notifications.class_scheduled_notifications s
            left join classes.v_class_schedules cs on cs.id = s.class_schedule_id
            where s.status = 'active' and s.id > {afterId}
              and ((s.kind = 'ONCE' and s.send_at <= ({bound} at time zone 'UTC')) or s.kind in ('WEEKLY', 'REMINDER'))
            order by s.id
            limit {PageSize}
            """).ToListAsync(ct);
    }

    public static async Task<bool> ClassIsActiveAsync(NotificationsContext db, int classId, CancellationToken ct) =>
        (await db.Database.SqlQuery<int>($"""select c.id as "Value" from classes.v_classes c where c.id = {classId} and c.status = 'A'""").ToListAsync(ct)).Count > 0;

    /// <summary>The per-class limit a send would break: sends are runs with no skip reason that reached a device, counted in the last hour and since the start of the row's own local day (UTC when its zone is unusable).</summary>
    public static async Task<bool> LimitReachedAsync(NotificationsContext db, DueRow row, DateTimeOffset now, CancellationToken ct)
    {
        if (await SendsSinceAsync(db, row.ClassId, now.AddHours(-1), ct) >= MaxSendsPerHour)
        {
            return true;
        }

        var zone = WallClock.Zone(row.Tz) ?? TimeZoneInfo.Utc;
        var dayStart = WallClock.At(WallClock.Local(now, zone).Date, zone).ToUniversalTime();
        return await SendsSinceAsync(db, row.ClassId, dayStart, ct) >= MaxSendsPerDay;
    }

    private static async Task<long> SendsSinceAsync(NotificationsContext db, int classId, DateTimeOffset since, CancellationToken ct) =>
        (await db.Database.SqlQuery<long>($"""
            select count(*) as "Value" from notifications.class_scheduled_notification_runs r
            where r.class_id = {classId} and r.skipped_reason is null and r.device_count > 0 and r.run_at > {since.ToUniversalTime()}
            """).ToListAsync(ct)).Single();

    /// <summary>Claims one occurrence: only the call that flips <c>last_run_key</c> gets true. Inside the caller's transaction the claim also holds the row against a second instance until that transaction ends.</summary>
    public static async Task<bool> ClaimAsync(NotificationsContext db, int id, string key, DateTimeOffset now, CancellationToken ct) =>
        await db.Database.ExecuteSqlAsync($"""
            update notifications.class_scheduled_notifications
            set last_run_at = {now}, last_run_key = {key}, updated_at = {now}
            where id = {id} and status = 'active' and (last_run_key is null or last_run_key <> {key}::citext)
            """, ct) == 1;

    public static async Task AddRunAsync(NotificationsContext db, int id, DateTimeOffset now, int? notificationId, int students, int devices, string? skippedReason, CancellationToken ct) =>
        await db.Database.ExecuteSqlAsync($"""
            insert into notifications.class_scheduled_notification_runs (scheduled_id, class_id, run_at, notification_id, student_count, device_count, success_count, failure_count, skipped_reason)
            select id, class_id, {now}, {notificationId}::integer, {students}, {devices}, 0, 0, {skippedReason}::citext
            from notifications.class_scheduled_notifications where id = {id}
            """, ct);

    public static async Task<int> MarkDoneAsync(NotificationsContext db, int id, DateTimeOffset now, CancellationToken ct) =>
        await db.Database.ExecuteSqlAsync($"update notifications.class_scheduled_notifications set status = 'done', updated_at = {now} where id = {id} and status = 'active'", ct);

    /// <summary>Ends a row that cannot be sent, with the reason in the ledger. False when another instance already ended it.</summary>
    public static async Task<bool> FinishAsync(NotificationsContext db, int id, string reason, DateTimeOffset now, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        if (await MarkDoneAsync(db, id, now, ct) == 0)
        {
            return false;
        }

        await AddRunAsync(db, id, now, null, 0, 0, reason, ct);
        await transaction.CommitAsync(ct);
        return true;
    }

    /// <summary>Records an occurrence as missed, once (the claim), and ends the row too when <paramref name="finished"/>. False when it was already claimed.</summary>
    public static async Task<bool> RecordMissedAsync(NotificationsContext db, int id, string key, bool finished, DateTimeOffset now, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        if (!await ClaimAsync(db, id, key, now, ct))
        {
            return false;
        }

        await AddRunAsync(db, id, now, null, 0, 0, "missed_window", ct);
        if (finished)
        {
            await MarkDoneAsync(db, id, now, ct);
        }

        await transaction.CommitAsync(ct);
        return true;
    }

    /// <summary>Records a not-sent reason unless it is already the latest run's, so a fault that lasts two hours leaves one run row and not one a minute.</summary>
    public static async Task RecordFailureOnceAsync(NotificationsContext db, int id, string reason, DateTimeOffset now, CancellationToken ct)
    {
        var last = await db.Database.SqlQuery<string>($"""
            select coalesce(skipped_reason::text, '') as "Value" from notifications.class_scheduled_notification_runs where scheduled_id = {id} order by id desc limit 1
            """).ToListAsync(ct);
        if (last.Count == 1 && last[0] == reason)
        {
            return;
        }

        await AddRunAsync(db, id, now, null, 0, 0, reason, ct);
    }
}
