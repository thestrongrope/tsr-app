using Microsoft.EntityFrameworkCore;

namespace Tsr.Notifications.Api.Domain;

/// <summary>A notification to record. <c>CriteriaJson</c> is the audience selector as PHP stores it; <c>ActionLink</c> is stored as given ('' for none, as PHP).</summary>
internal sealed record NewNotification(string Title, string Body, string CriteriaJson, int DeviceCount, int SuccessCount, int FailureCount, string ActionLink, int CreatedBy);

/// <summary>The recorded notification and how many inbox copies were written (repeat recipients of a reused notification are not counted again).</summary>
internal sealed record NotificationWritten(int NotificationId, int InboxRows);

/// <summary>
/// The one writer of "a notification and its inbox fan-out" (PHP <c>MobileNotificationsModel::create</c> + <c>fanOut</c>, and the lookup of <c>recordScheduledInbox</c>), used by the
/// announcement and the class send and meant to be published to other domains as a command. Plain parameters. One transaction holds the notification, the inbox rows and the
/// outbox event <c>notifications.sent</c> (ids and a count, never text): all or nothing, where PHP could keep a notification whose fan-out failed.
/// </summary>
internal static class NotificationWriter
{
    internal sealed record Sent(int NotificationId, int RecipientCount, string Source, int SentBy);

    /// <param name="memberTokens">Recipients: tokens above zero are kept, each once (PHP filters the same way).</param>
    /// <param name="source">Where it came from, for the event: <c>announcement</c> or <c>class</c>.</param>
    /// <param name="reuseSameCriteria">PHP's scheduled slot dedupe: reuse the newest notification with exactly this criteria text, so a retried slot does not add a second one.</param>
    public static async Task<NotificationWritten> WriteAsync(
        NotificationsContext db,
        TimeProvider clock,
        NewNotification notification,
        IEnumerable<int> memberTokens,
        string source,
        bool reuseSameCriteria,
        CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(notification);
        var tokens = memberTokens.Where(t => t > 0).Distinct().Take(Audience.MaxRecipients + 1).ToArray();
        if (Audience.TooLarge(tokens.Length))
        {
            throw new InvalidOperationException("A notification has more recipients than one request may fan out to");
        }

        var now = clock.GetUtcNow();
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var id = reuseSameCriteria ? await ExistingAsync(db, notification.CriteriaJson, ct) : null;
        id ??= await InsertAsync(db, notification, now, ct);
        var rows = tokens.Length == 0
            ? 0
            : await db.Database.ExecuteSqlAsync(
                $"""
                insert into notifications.user_notifications (notification_id, user_token, is_read, created_at)
                select {id.Value}, t, 0, {now} from unnest({tokens}) as t
                on conflict (notification_id, user_token) do nothing
                """,
                ct);
        await Outbox.WriteAsync(db, "notifications.sent", new Sent(id.Value, tokens.Length, source, notification.CreatedBy), clock, ct);
        await transaction.CommitAsync(ct);
        return new NotificationWritten(id.Value, rows);
    }

    private static async Task<int?> ExistingAsync(NotificationsContext db, string criteria, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<int>($"""select notification_id as "Value" from notifications.notifications where target_audience_criteria = {criteria} order by notification_id desc limit 1""")
            .ToListAsync(ct);
        return rows.Count == 0 ? null : rows[0];
    }

    private static async Task<int> InsertAsync(NotificationsContext db, NewNotification n, DateTimeOffset now, CancellationToken ct)
    {
        var entity = new Notification
        {
            Title = n.Title,
            Body = n.Body,
            TargetAudienceCriteria = n.CriteriaJson,
            SentAt = now,
            CreatedBy = n.CreatedBy,
            DeviceCount = n.DeviceCount,
            SuccessCount = n.SuccessCount,
            FailureCount = n.FailureCount,
            ActionLink = n.ActionLink,
        };
        db.Notifications.Add(entity);
        await db.SaveChangesAsync(ct);
        return entity.NotificationId;
    }
}
