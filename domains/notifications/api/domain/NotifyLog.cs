using Microsoft.Extensions.Logging;

namespace Tsr.Notifications.Api.Domain;

/// <summary>The log lines of the notification slices. None carries a title, body, device token, link or member data: only counts and states.</summary>
internal static partial class NotifyLog
{
    public const string Category = "Tsr.Notifications.Api";

    [LoggerMessage(Level = LogLevel.Error, Message = "A notification was pushed ({Success} sent, {Failure} failed) but could not be recorded: {Kind}")]
    public static partial void RecordFailed(ILogger logger, int success, int failure, string kind);

    [LoggerMessage(Level = LogLevel.Warning, Message = "A push was refused before sending: the audience is over {Limit} recipients")]
    public static partial void AudienceTooLarge(ILogger logger, int limit);

    [LoggerMessage(Level = LogLevel.Warning, Message = "The invalid device tokens could not be removed: {Kind}")]
    public static partial void CleanupFailed(ILogger logger, string kind);
}
