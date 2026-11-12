using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.ClassNotificationSend;

// Slice: POST /classes/{class_id}/notifications {title, body, action_link?} -> {success, message, device_count, student_count, success_count, failure_count, notification_id}: push to the devices of a
// class's active students and record it. Contract: spec/api.yaml. PHP: routes/classes.php route_class_notifications_send, ClassNotificationsModel::message and dispatch. IRREVERSIBLE.
// Order: the class (404 "Class not found"), notifications:send on it (403 "You do not have permission to send notifications for this class"), the message (domain/ClassMessage.cs: trimmed, the link as typed),
// the rate limit (10 an hour per member, bucket class_push, 429 "Too many class notifications; try again later"; the call counts even when nothing is sent), the audience (enrolled, not removed, token above zero;
// their devices, demo devices left out). No device: 200 "No active student devices found for this class" with the student count, nothing written. Not configured: 500 before anything is sent or written.
// Then the push (body cut to 500 characters) and the record: the notification (criteria {"type":"CLASS","class_id":N}, the link or /classes/N/dashboard) and one inbox row per student (demo members
// included, as PHP). Deviations as POST /notifications/send: over 20000 students or devices is a 422, and the record is one transaction. Event notifications.sent (source class).

internal static class ClassNotificationSendSlice
{
    public static IEndpointRouteBuilder MapClassNotificationSend(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/{class_id}/notifications", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string class_id,
        HttpContext context,
        NotificationsContext db,
        Permissions permissions,
        MemberRateLimit limiter,
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

        var classId = NotifyGuards.IdOf(class_id);
        var refusal = await NotifyGuards.ClassAccessAsync(db, permissions, caller, classId, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var message = ClassMessage.Parse(body!, rewriteLink: false);
        if (!message.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, message.Error!);
        }

        if (!limiter.Allow("class_push", caller.Token, 10, 3600))
        {
            return Problem.Detail(StatusCodes.Status429TooManyRequests, "Too many class notifications; try again later");
        }

        var students = await Audience.ClassStudentsAsync(db, classId, ct);
        var devices = Audience.TooLarge(students.Count) ? [] : await Audience.MemberDevicesAsync(db, [.. students], ct);
        var logger = loggers.CreateLogger(NotifyLog.Category);
        if (Audience.TooLarge(students.Count) || Audience.TooLarge(devices.Count))
        {
            NotifyLog.AudienceTooLarge(logger, Audience.MaxRecipients);
            return NotifyGuards.TooLarge();
        }

        if (devices.Count == 0)
        {
            return Results.Json(Outcome("No active student devices found for this class", 0, students.Count, 0, 0, null));
        }

        if (!sender.IsConfigured)
        {
            return NotifyGuards.PushNotConfigured();
        }

        var text = message.Value!;
        var data = new Dictionary<string, string>
        {
            ["type"] = "class_announcement",
            ["sent_at"] = PushBatch.SentAt(clock.GetUtcNow()),
            ["class_id"] = classId.ToString(System.Globalization.CultureInfo.InvariantCulture),
            ["action_link"] = text.ActionLink ?? string.Empty,
        };
        var report = await PushBatch.SendAsync(sender, text.Title, PushBatch.CutBody(text.Body), data, devices, ct);
        var id = await RecordAsync(db, clock, logger, classId, text, devices.Count, report, students, caller.Token, ct);
        return Results.Json(Outcome($"Notification sent to {report.Success} devices successfully", devices.Count, students.Count, report.Success, report.Failure, id));
    }

    private static Dictionary<string, object?> Outcome(string message, int devices, int students, int success, int failure, int? id) => new()
    {
        ["success"] = true,
        ["message"] = message,
        ["device_count"] = devices,
        ["student_count"] = students,
        ["success_count"] = success,
        ["failure_count"] = failure,
        ["notification_id"] = id,
    };

    private static async Task<int?> RecordAsync(
        NotificationsContext db,
        TimeProvider clock,
        ILogger logger,
        int classId,
        ClassMessageText text,
        int deviceCount,
        PushReport report,
        List<int> students,
        int sender,
        CancellationToken ct)
    {
        try
        {
            var criteria = "{\"type\":\"CLASS\",\"class_id\":" + classId.ToString(System.Globalization.CultureInfo.InvariantCulture) + "}";
            var link = text.ActionLink ?? $"/classes/{classId}/dashboard";
            var notification = new NewNotification(text.Title, text.Body, criteria, deviceCount, report.Success, report.Failure, link, sender);
            var written = await NotificationWriter.WriteAsync(db, clock, notification, students, "class", reuseSameCriteria: false, ct);
            return written.NotificationId;
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            NotifyLog.RecordFailed(logger, report.Success, report.Failure, e.GetType().Name);
            return null;
        }
    }
}
