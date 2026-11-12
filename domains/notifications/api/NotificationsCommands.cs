using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Tsr.Platform.Api;

namespace Tsr.Notifications.Api;

/// <summary>
/// One announcement to members: the inbox copy plus the push queue. <paramref name="Tokens"/> null means every registered member (a member with a device, the demo cohort left out);
/// otherwise exactly those member tokens (that have a device). <paramref name="DataType"/> is the <c>type</c> in the push data (for example <c>quiz_announcement</c>); <paramref name="DedupeKey"/>
/// makes a repeat of the same announcement a no-op (one push per device and key); <paramref name="ActionLink"/> is the in-app route the notification opens.
/// Optional, for an announcement a member makes (a published quiz, PHP route_mcq_manage_publish): <paramref name="Sender"/> is the member token that made it (0 is the system, the default; it is the notification's creator
/// and the queued rows' creator), <paramref name="Criteria"/> the audience JSON kept on the notification (default: the registered members or the listed members), <paramref name="Data"/> replaces the push's data object
/// (default <c>{type, action_link, title, body}</c>; the caller states the type itself), <paramref name="ReuseExisting"/> false makes a new notification on every call instead of finding one with the same text,
/// and <paramref name="CountsFromQueue"/> true keeps on the notification the rows the queue accepted as the successes and the refused devices as the failures (default: every device a success).
/// </summary>
public sealed record Announcement(
    string Title,
    string Body,
    string ActionLink,
    string DataType,
    string DedupeKey,
    IReadOnlyList<int>? Tokens = null,
    int Sender = 0,
    string? Criteria = null,
    IReadOnlyDictionary<string, string>? Data = null,
    bool ReuseExisting = true,
    bool CountsFromQueue = false);

/// <summary>What an announcement did: the devices it found and the push rows the queue accepted (a repeat of the same dedupe key accepts none).</summary>
public sealed record AnnounceResult(int Devices, int Queued);

/// <summary>
/// The commands notifications publishes to other domains (domains/CLAUDE.md rule 3): public static methods that write notifications' tables (and, through platform's published command, the push queue)
/// on the caller's own connection and open transaction. Nothing is sent: no worker reads the queue yet.
/// </summary>
public static class NotificationsCommands
{
    private const string DemoEmails = "%@demo.invalid";

    /// <summary>
    /// PHP QuizAdminModel::announceSwitchOn (models/quizadmin.php:~900) over MobileNotificationsModel: the inbox copy first (found again by its title, body and link when a system notification with that text exists, else
    /// created with created_by 0 and the audience criteria <c>{"type":"REGISTERED_MEMBERS"}</c> or <c>{"type":"MEMBERS"}</c>, its device counts being the audience's), fanned out to the audience's tokens (a repeat is ignored by the unique index),
    /// then one queued push per device carrying <c>{title, body, data: {type, action_link, title, body}}</c>. Returns the push rows queued.
    /// </summary>
    public static async Task<int> AnnounceAsync(DbContext db, Announcement announcement, CancellationToken ct) =>
        (await AnnounceCountedAsync(db, announcement, ct)).Queued;

    /// <summary><see cref="AnnounceAsync"/> that also says how many devices the audience has.</summary>
    public static async Task<AnnounceResult> AnnounceCountedAsync(DbContext db, Announcement announcement, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(announcement);
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("An announcement is written inside the caller's transaction.");
        }

        var tokens = announcement.Tokens?.Where(t => t > 0).Distinct().ToArray();
        var devices = await DevicesAsync(db, tokens, ct);
        var payload = JsonSerializer.Serialize(new
        {
            title = announcement.Title,
            body = announcement.Body,
            data = announcement.Data ?? new Dictionary<string, string>
            {
                ["type"] = announcement.DataType,
                ["action_link"] = announcement.ActionLink,
                ["title"] = announcement.Title,
                ["body"] = announcement.Body,
            },
        });
        var queued = await PlatformCommands.QueueMessagesAsync(db, "push", devices, payload, announcement.DedupeKey, announcement.Sender, ct);

        var notificationId = announcement.ReuseExisting ? await FindNotificationAsync(db, announcement, ct) : null;
        if (notificationId is null)
        {
            var succeeded = announcement.CountsFromQueue ? queued : devices.Count;
            notificationId = await CreateNotificationAsync(db, announcement, devices.Count, succeeded, tokens is null, ct);
            await FanOutAsync(db, notificationId.Value, tokens, ct);
        }

        return new AnnounceResult(devices.Count, queued);
    }

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

    private static async Task<int?> FindNotificationAsync(DbContext db, Announcement a, CancellationToken ct) =>
        await db.Database.SqlQuery<int>($"""
            select notification_id as "Value" from notifications.notifications
            where created_by = {a.Sender} and title = {a.Title} and body = {a.Body} and action_link = {a.ActionLink}
            order by notification_id desc limit 1
            """).Cast<int?>().FirstOrDefaultAsync(ct);

    private static async Task<int> CreateNotificationAsync(DbContext db, Announcement a, int devices, int succeeded, bool allRegistered, CancellationToken ct)
    {
        var criteria = a.Criteria ?? (allRegistered ? """{"type":"REGISTERED_MEMBERS"}""" : """{"type":"MEMBERS"}""");
        var ids = await db.Database.SqlQuery<int>($"""
            insert into notifications.notifications (title, body, target_audience_criteria, created_by, device_count, success_count, failure_count, action_link)
            values ({a.Title}, {a.Body}, {criteria}, {a.Sender}, {devices}, {succeeded}, {devices - succeeded}, {a.ActionLink})
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
