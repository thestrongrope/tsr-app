namespace Tsr.Notifications.Api.Domain;

/// <summary>What happened to one push: it was accepted, the device token is dead (FCM says unregistered or not a token), or it failed for any other reason.</summary>
internal enum PushResult
{
    Sent,
    TokenInvalid,
    Failed,
}

/// <summary>A push as FCM shows it: title, body and string data. Data values are strings because FCM refuses any other kind.</summary>
internal sealed record PushMessage(string Title, string Body, IReadOnlyDictionary<string, string> Data);

/// <summary>
/// The one seam to Firebase Cloud Messaging (domains/CLAUDE.md rule 6: interfaces only at external boundaries). One message to one device token.
/// <see cref="IsConfigured"/> is false when no service account is set: the API still starts, and a route that must push answers 500 as PHP does when its credential is missing.
/// </summary>
internal interface IPushSender
{
    bool IsConfigured { get; }

    Task<PushResult> SendAsync(PushMessage message, string deviceToken, CancellationToken ct);
}
