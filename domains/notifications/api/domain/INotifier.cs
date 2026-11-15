using System.Text.Json;

namespace Tsr.Notifications.Api.Domain;

/// <summary>The notifier's own status and body, untouched (PHP <c>WhatsAppRemindersModel::forward</c>). A notifier that cannot be reached is 502.</summary>
internal sealed record NotifierAnswer(int Status, string Body)
{
    public static NotifierAnswer Unreachable { get; } = new(502, """{"error":"notifier unreachable"}""");
}

/// <summary>
/// The external boundary to the notifier: one method per call PHP makes (WhatsAppRemindersModel::ROUTES). The notifier is unauthenticated and reachable only on the compose network.
/// <c>token</c> is the acting member's token number, which the notifier stores as <c>triggered_by</c> or <c>updated_by</c>.
/// </summary>
internal interface INotifier
{
    Task<NotifierAnswer> StatusAsync(CancellationToken ct);

    Task<NotifierAnswer> QrAsync(CancellationToken ct);

    Task<NotifierAnswer> RemindersAsync(CancellationToken ct);

    /// <summary><paramref name="limit"/> and <paramref name="reminderId"/> are digits only, or null to leave them out.</summary>
    Task<NotifierAnswer> RecentRunsAsync(string? limit, string? reminderId, CancellationToken ct);

    Task<NotifierAnswer> RunAsync(long id, CancellationToken ct);

    Task<NotifierAnswer> RunMessagesAsync(long id, CancellationToken ct);

    Task<NotifierAnswer> RelinkAsync(CancellationToken ct);

    Task<NotifierAnswer> LogoutAsync(CancellationToken ct);

    Task<NotifierAnswer> UpdateReminderAsync(long id, IReadOnlyDictionary<string, JsonElement> fields, int token, CancellationToken ct);

    Task<NotifierAnswer> RunWeeklyAsync(long reminderId, bool dryRun, int token, CancellationToken ct);

    Task<NotifierAnswer> SendTestAsync(string mobile, string message, int token, CancellationToken ct);
}
