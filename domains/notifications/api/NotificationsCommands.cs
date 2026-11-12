using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Tsr.Platform.Api;

namespace Tsr.Notifications.Api;

/// <summary>
/// One announcement to members: the inbox copy plus the push queue. <paramref name="Tokens"/> null means every registered member (a member with a device, the demo cohort left out);
/// otherwise exactly those member tokens (that have a device). <paramref name="DataType"/> is the <c>type</c> in the push data (for example <c>quiz_announcement</c>); <paramref name="DedupeKey"/>
/// makes a repeat of the same announcement a no-op (one push per device and key); <paramref name="ActionLink"/> is the in-app route the notification opens.
/// </summary>
public sealed record Announcement(string Title, string Body, string? ActionLink, string DataType, string DedupeKey, IReadOnlyList<int>? Tokens = null, AnnouncementExtras? Extras = null);

/// <summary>
/// For a notification a member sends (the class coordinators' reminder, PHP PendingNudgeModel::record): the audience criteria JSON it is recorded with, its sender, the extra push data values (FCM data values are strings),
/// and whether a demo member's devices are left out. With these set a NEW notification is always recorded (the system-notification lookup is not used).
/// </summary>
public sealed record AnnouncementExtras(string CriteriaJson, int CreatedBy, IReadOnlyDictionary<string, string> Data, bool SkipDemoDevices);

/// <summary>
/// The commands notifications publishes to other domains (domains/CLAUDE.md rule 3): public static methods that write notifications' tables (and, through platform's published command, the push queue)
/// on the caller's own connection and open transaction. Nothing is sent: no worker reads the queue yet.
/// </summary>
public static class NotificationsCommands
{
    private const string DemoEmails = "%@demo.invalid";
    private const int SystemSender = 0;

    /// <summary>
    /// PHP QuizAdminModel::announceSwitchOn (models/quizadmin.php:~900) over MobileNotificationsModel: the inbox copy first (found again by its title, body and link when a system notification with that text exists, else
    /// created with created_by 0 and the audience criteria <c>{"type":"REGISTERED_MEMBERS"}</c> or <c>{"type":"MEMBERS"}</c>, its device counts being the audience's), fanned out to the audience's tokens (a repeat is ignored by the unique index),
    /// then one queued push per device carrying <c>{title, body, data: {type, action_link, title, body}}</c>. Returns the push rows queued.
    /// </summary>
    public static async Task<int> AnnounceAsync(DbContext db, Announcement announcement, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(announcement);
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("An announcement is written inside the caller's transaction.");
        }

        var tokens = announcement.Tokens?.Where(t => t > 0).Distinct().ToArray();
        var devices = await DevicesAsync(db, tokens, ct);
        var extras = announcement.Extras;
        if (extras is not null && tokens is not null && extras.SkipDemoDevices)
        {
            devices = await DevicesAsync(db, await WithoutDemoAsync(db, tokens, ct), ct);
        }

        var notificationId = extras is null ? await FindSystemNotificationAsync(db, announcement, ct) : null;
        if (notificationId is null)
        {
            notificationId = await CreateNotificationAsync(db, announcement, devices.Count, tokens is null, ct);
            await FanOutAsync(db, notificationId.Value, tokens, ct);
        }

        var payload = JsonSerializer.Serialize(new
        {
            title = announcement.Title,
            body = announcement.Body,
            data = PushData(announcement),
        });
        return await PlatformCommands.QueueMessagesAsync(db, "push", devices, payload, announcement.DedupeKey, SystemSender, ct);
    }

    /// <summary>
    /// The newest notification of the class coordinators' reminder (criteria type <c>CC_NUDGE</c>) to this teacher sent within the last <paramref name="windowHours"/> hours, or null. PHP PendingNudgeModel::lastReminded.
    /// Read on the caller's connection, so inside its transaction it sees what that transaction wrote.
    /// </summary>
    public static async Task<DateTimeOffset?> LastNudgeAsync(DbContext db, int teacher, int windowHours, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        var rows = await db.Database.SqlQuery<DateTimeOffset>($"""
            select max(sent_at) as "Value" from notifications.notifications
            where target_audience_criteria::text::jsonb ->> 'type' = 'CC_NUDGE'
              and target_audience_criteria::text::jsonb ->> 'teacher' = {teacher.ToString(System.Globalization.CultureInfo.InvariantCulture)}
              and sent_at > now() - make_interval(hours => {windowHours})
            having max(sent_at) is not null
            """).ToListAsync(ct);
        return rows.Count == 0 ? null : rows[0];
    }

    private static Dictionary<string, object?> PushData(Announcement a)
    {
        var data = new Dictionary<string, object?> { ["type"] = a.DataType, ["action_link"] = a.ActionLink, ["title"] = a.Title, ["body"] = a.Body };
        foreach (var (key, value) in a.Extras?.Data ?? new Dictionary<string, string>())
        {
            data[key] = value;
        }

        return data;
    }

    private static async Task<int[]> WithoutDemoAsync(DbContext db, int[] tokens, CancellationToken ct) =>
        [.. await db.Database.SqlQuery<int>($"""
            select t as "Value" from unnest({tokens}) as t
            where t not in (select token from identity.v_users where email like {DemoEmails})
            """).ToListAsync(ct)];

    private static async Task<List<string>> DevicesAsync(DbContext db, int[]? tokens, CancellationToken ct) =>
        tokens is null
            ? await db.Database.SqlQuery<string>($"""
                select distinct ud.device_id as "Value" from notifications.user_devices ud
                where ud.token > 0 and ud.device_id <> ''
                  and ud.token not in (select token from identity.v_users where email like {DemoEmails})
                """).ToListAsync(ct)
            : await db.Database.SqlQuery<string>($"""
                select distinct ud.device_id as "Value" from notifications.user_devices ud
                where ud.token = any({tokens}) and ud.device_id <> ''
                """).ToListAsync(ct);

    private static async Task<int?> FindSystemNotificationAsync(DbContext db, Announcement a, CancellationToken ct) =>
        await db.Database.SqlQuery<int>($"""
            select notification_id as "Value" from notifications.notifications
            where created_by = {SystemSender} and title = {a.Title} and body = {a.Body} and action_link = {a.ActionLink}
            order by notification_id desc limit 1
            """).Cast<int?>().FirstOrDefaultAsync(ct);

    private static async Task<int> CreateNotificationAsync(DbContext db, Announcement a, int devices, bool allRegistered, CancellationToken ct)
    {
        var criteria = a.Extras?.CriteriaJson ?? (allRegistered ? """{"type":"REGISTERED_MEMBERS"}""" : """{"type":"MEMBERS"}""");
        var sender = a.Extras?.CreatedBy ?? SystemSender;
        var ids = await db.Database.SqlQuery<int>($"""
            insert into notifications.notifications (title, body, target_audience_criteria, created_by, device_count, success_count, failure_count, action_link)
            values ({a.Title}, {a.Body}, {criteria}, {sender}, {devices}, {devices}, 0, {a.ActionLink})
            returning notification_id as "Value"
            """).ToListAsync(ct);
        return ids.Single();
    }

    /// <summary>One inbox row per audience token (registered members: those with a device, the demo cohort left out); the unique index drops a repeat.</summary>
    private static async Task FanOutAsync(DbContext db, int notificationId, int[]? tokens, CancellationToken ct)
    {
        if (tokens is null)
        {
            await db.Database.ExecuteSqlAsync($"""
                insert into notifications.user_notifications (notification_id, user_token, is_read, created_at)
                select distinct {notificationId}, u.token, 0, now() from identity.v_users u
                join notifications.user_devices ud on ud.token = u.token
                where u.token > 0 and u.email not like {DemoEmails}
                on conflict do nothing
                """, ct);
            return;
        }

        await db.Database.ExecuteSqlAsync($"""
            insert into notifications.user_notifications (notification_id, user_token, is_read, created_at)
            select {notificationId}, t, 0, now() from unnest({tokens}) as t
            on conflict do nothing
            """, ct);
    }
}
