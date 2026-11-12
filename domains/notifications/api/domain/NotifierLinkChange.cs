using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Domain;

/// <summary>
/// PHP api_whatsapp_link_change: re-link or log out. Order as PHP: no-store (route precheck), whatsapp:manage, 6 a minute per member (429), the admin audit row BEFORE the attempt, the notifier call.
/// Anything but a 200 from the notifier is a 502 with the route's own words; the outcome is logged as done or not, nothing of the answer.
/// </summary>
internal static partial class NotifierLinkChange
{
    [LoggerMessage(Level = LogLevel.Information, Message = "{Event} done={Done}")]
    private static partial void LogOutcome(ILogger logger, string @event, bool done);

    public sealed record Changed(bool Ok);

    public static async Task<IResult> RunAsync(
        HttpContext context, Permissions permissions, MemberRateLimit limit, NotificationsContext db, ILogger logger,
        Func<CancellationToken, Task<NotifierAnswer>> call, string eventName, string failedText, CancellationToken ct)
    {
        var (caller, refusal) = await NotifierAccess.RequireManagerAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var limited = NotifierAccess.LinkLimit(limit, caller!, "whatsapp_link_change", 6);
        if (limited is not null)
        {
            return limited;
        }

        await PlatformCommands.RecordAdminAccessAsync(db, context, caller!.UserId, caller.Token, await permissions.RoleIdAsync(caller, ct), ct);
        var done = (await call(ct)).Status == StatusCodes.Status200OK;
        LogOutcome(logger, eventName, done);
        return done ? Results.Json(new Changed(true)) : Problem.Detail(StatusCodes.Status502BadGateway, failedText);
    }
}
