using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.NotificationsSend;

// Slice: POST /notifications/send {title, body, target: {type, value}, action_link?} -> {success, message, device_count, success_count, failure_count, notification_id}: push an announcement and
// record it. Contract: spec/api.yaml. PHP: routes/notifications.php route_notifications_send, lib/fcm.php (the audience), functions.php api_fcm_send. IRREVERSIBLE: one call pushes to every device of
// the audience. Order: notifications:broadcast (super administrator; 403 "Only super administrators can send notifications"), the admin audit row, the body (domain/AnnouncementRequest.cs: 422s
// in PHP's order), the devices of the target (none: 200 "No devices found matching the target criteria", nothing written), the push, then the record: the notification (the body in full) and
// one inbox row per member of the target's MEMBER query (a different query from the device one: see domain/Audience.cs). The pushed body is cut to 500 characters.
// Not configured (no TSR_GOOGLE_SERVICE_ACCOUNT_B64): 500 "Push notifications are not configured" before anything is sent or written (PHP's uncaught exception). A device that fails counts as a
// failure and the rest still go; a dead token is NOT deleted here (only the cleanup route does).
// Deviations: an audience over 20000 devices or members is a 422 before anything is sent (PHP has no cap); the member list is read BEFORE the push so that cap cannot fail after it; the notification, its
// inbox rows and the event are one transaction (PHP kept the notification when the fan-out failed); when the record fails the response still succeeds with notification_id null, as PHP.
// Event notifications.sent (notification id, recipient count, source announcement, sender).

internal static class NotificationsSendSlice
{
    public static IEndpointRouteBuilder MapNotificationsSend(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/notifications/send", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        HttpContext context,
        NotificationsContext db,
        Permissions permissions,
        IPushSender sender,
        ILoggerFactory loggers,
        TimeProvider clock,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var refusal = await NotifyGuards.AdminAsync(context, db, permissions, caller, "send notifications", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var parsed = AnnouncementRequest.Parse(body!);
        if (!parsed.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, parsed.Error!);
        }

        var announcement = parsed.Value!;
        var devices = await Audience.DevicesAsync(db, announcement.Target, ct);
        if (devices.Count == 0)
        {
            return Results.Json(Outcome("No devices found matching the target criteria", 0, 0, 0, null));
        }

        var members = await Audience.MemberTokensAsync(db, announcement.Target, ct);
        var logger = loggers.CreateLogger(NotifyLog.Category);
        if (Audience.TooLarge(devices.Count) || Audience.TooLarge(members.Count))
        {
            NotifyLog.AudienceTooLarge(logger, Audience.MaxRecipients);
            return NotifyGuards.TooLarge();
        }

        if (!sender.IsConfigured)
        {
            return NotifyGuards.PushNotConfigured();
        }

        var data = new Dictionary<string, string>
        {
            ["type"] = "admin_announcement",
            ["sent_at"] = PushBatch.SentAt(clock.GetUtcNow()),
            ["target_type"] = announcement.Target.Type,
            ["action_link"] = announcement.ActionLink ?? string.Empty,
        };
        var report = await PushBatch.SendAsync(sender, announcement.Title, PushBatch.CutBody(announcement.Body), data, devices, ct);
        var id = await RecordAsync(db, clock, logger, announcement, devices.Count, report, members, caller.Token, ct);
        return Results.Json(Outcome($"Notification sent to {report.Success} devices successfully", devices.Count, report.Success, report.Failure, id));
    }

    private static Dictionary<string, object?> Outcome(string message, int devices, int success, int failure, int? id) => new()
    {
        ["success"] = true,
        ["message"] = message,
        ["device_count"] = devices,
        ["success_count"] = success,
        ["failure_count"] = failure,
        ["notification_id"] = id,
    };

    // Best effort: the push has gone out and cannot be unsent, so a failure here is logged (no values) and not shown as an error.
    private static async Task<int?> RecordAsync(
        NotificationsContext db,
        TimeProvider clock,
        ILogger logger,
        Announcement announcement,
        int deviceCount,
        PushReport report,
        List<int> members,
        int sender,
        CancellationToken ct)
    {
        try
        {
            var notification = new NewNotification(announcement.Title, announcement.Body, announcement.CriteriaJson, deviceCount, report.Success, report.Failure, announcement.ActionLink ?? string.Empty, sender);
            var written = await NotificationWriter.WriteAsync(db, clock, notification, members, "announcement", reuseSameCriteria: false, ct);
            return written.NotificationId;
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            NotifyLog.RecordFailed(logger, report.Success, report.Failure, e.GetType().Name);
            return null;
        }
    }
}
