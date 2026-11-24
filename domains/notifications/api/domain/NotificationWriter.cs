namespace Tsr.Notifications.Api.Domain;

/// <summary>A notification to record. <c>CriteriaJson</c> is the audience selector as PHP stores it; <c>ActionLink</c> is stored as given ('' for none, as PHP).</summary>
internal sealed record NewNotification(string Title, string Body, string CriteriaJson, int DeviceCount, int SuccessCount, int FailureCount, string ActionLink, int CreatedBy);

/// <summary>The recorded notification and how many inbox copies were written (repeat recipients of a reused notification are not counted again).</summary>
internal sealed record NotificationWritten(int NotificationId, int InboxRows);

/// <summary>
/// The one writer of "a notification and its inbox fan-out" (PHP <c>MobileNotificationsModel::create</c> + <c>fanOut</c>, and the lookup of <c>recordScheduledInbox</c>), used by the
/// announcement and the class send and meant to be published to other domains as a command. Plain parameters. One transaction (the caller's) holds the notification, the inbox rows and the
/// outbox event <c>notifications.sent</c> (ids and a count, never text): all or nothing, where PHP could keep a notification whose fan-out failed.
/// </summary>
internal static class NotificationWriter
{
    internal sealed record Sent(int NotificationId, int RecipientCount, string Source, int SentBy);

    /// <param name="memberTokens">Recipients: tokens above zero are kept, each once (PHP filters the same way).</param>
    /// <param name="source">Where it came from, for the event: <c>announcement</c> or <c>class</c>.</param>
    /// <param name="reuseSameCriteria">PHP's scheduled slot dedupe: reuse the newest notification with exactly this criteria text, so a retried slot does not add a second one.</param>
    public static async Task<NotificationWritten> WriteAsync(
        DbTx tx,
        TimeProvider clock,
        NewNotification notification,
        IEnumerable<int> memberTokens,
        string source,
        bool reuseSameCriteria,
        CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(tx);
        ArgumentNullException.ThrowIfNull(notification);
        var tokens = memberTokens.Where(t => t > 0).Distinct().Take(Audience.MaxRecipients + 1).ToArray();
        if (Audience.TooLarge(tokens.Length))
        {
            throw new InvalidOperationException("A notification has more recipients than one request may fan out to");
        }

        var now = clock.GetUtcNow();
        var id = reuseSameCriteria ? await ExistingAsync(tx, notification.CriteriaJson, ct) : null;
        id ??= await InsertAsync(tx, notification, now, ct);
        var rows = tokens.Length == 0
            ? 0
            : await tx.ExecuteAsync(
                $"""
                insert into notifications.user_notifications (notification_id, user_token, is_read, created_at)
                select {id.Value}, t, 0, {now} from unnest({tokens}) as t
                on conflict (notification_id, user_token) do nothing
                """,
                ct);
        await Outbox.WriteAsync(tx, "notifications.sent", new Sent(id.Value, tokens.Length, source, notification.CreatedBy), NotificationsJson.Default.SentEvent, clock, ct);
        return new NotificationWritten(id.Value, rows);
    }

    private static async Task<int?> ExistingAsync(DbTx tx, string criteria, CancellationToken ct)
    {
        var rows = await tx.ListAsync(
            $"""select notification_id as "Value" from notifications.notifications where target_audience_criteria = {criteria}::citext order by notification_id desc limit 1""",
            row => row.Int("Value"),
            ct);
        return rows.Count == 0 ? null : rows[0];
    }

    private static async Task<int> InsertAsync(DbTx tx, NewNotification n, DateTimeOffset now, CancellationToken ct)
    {
        var ids = await tx.ListAsync(
            $"""
            insert into notifications.notifications (title, body, target_audience_criteria, sent_at, created_by, device_count, success_count, failure_count, action_link)
            values ({n.Title}, {n.Body}, {n.CriteriaJson}, {now}, {n.CreatedBy}, {n.DeviceCount}, {n.SuccessCount}, {n.FailureCount}, {n.ActionLink})
            returning notification_id
            """,
            row => row.Int("notification_id"),
            ct);
        return ids.Single();
    }
}
