using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.NotificationsCleanup;

// Slice: POST /notifications/cleanup-invalid-tokens -> {success, message, tokens_before, tokens_after, tokens_removed, successful_sends, failed_sends}: find dead device tokens and delete them. Contract: spec/api.yaml.
// PHP: routes/notifications.php route_notifications_cleanup. IT PUSHES A VISIBLE NOTIFICATION, title "System Check", body "Verifying device connectivity", to EVERY registered device (demo devices left out)
// to learn which tokens FCM rejects (Python's design, kept; flagged in the notes). Order: notifications:broadcast (403 "Only super administrators can cleanup invalid tokens"), the admin audit row,
// the devices of ALL_USERS (none: 200 "No device tokens found in database", tokens_before 0, tokens_removed 0, no tokens_after), not configured (500 before anything is sent), the push, the delete of the
// device rows whose token FCM called dead (every member's row of it), then a recount: tokens_removed is before minus after. Only a token FCM says is unregistered or not a registration token is
// deleted (domain/FcmPushSender.cs); any other failure leaves it. Deviations: an audience over 20000 devices is a 422 before anything is sent; the delete is one statement per 500 tokens.
// Event notifications.invalid_devices_removed (a count) when rows went.

internal static class NotificationsCleanupSlice
{
    private const int DeleteChunk = 500;

    internal sealed record DevicesRemoved(int Count);

    public static IEndpointRouteBuilder MapNotificationsCleanup(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/notifications/cleanup-invalid-tokens", HandleAsync).RequireMember(createsMember: true);
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

        var refusal = await NotifyGuards.AdminAsync(context, db, permissions, caller, "cleanup invalid tokens", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var everyone = new Target("ALL_USERS", []);
        var tokens = await Audience.DevicesAsync(db, everyone, ct);
        if (tokens.Count == 0)
        {
            return Results.Json(new Dictionary<string, object> { ["success"] = true, ["message"] = "No device tokens found in database", ["tokens_before"] = 0, ["tokens_removed"] = 0 });
        }

        var logger = loggers.CreateLogger(NotifyLog.Category);
        if (Audience.TooLarge(tokens.Count))
        {
            NotifyLog.AudienceTooLarge(logger, Audience.MaxRecipients);
            return NotifyGuards.TooLarge();
        }

        if (!sender.IsConfigured)
        {
            return NotifyGuards.PushNotConfigured();
        }

        var data = new Dictionary<string, string> { ["type"] = "system_check", ["silent"] = "true" };
        var report = await PushBatch.SendAsync(sender, "System Check", "Verifying device connectivity", data, tokens, ct);
        await RemoveAsync(db, clock, logger, report.Invalid, ct);
        var after = (await Audience.DevicesAsync(db, everyone, ct)).Count;
        var removed = tokens.Count - after;
        return Results.Json(new Dictionary<string, object>
        {
            ["success"] = true,
            ["message"] = $"Cleanup completed. Removed {removed} invalid tokens.",
            ["tokens_before"] = tokens.Count,
            ["tokens_after"] = after,
            ["tokens_removed"] = removed,
            ["successful_sends"] = report.Success,
            ["failed_sends"] = report.Failure,
        });
    }

    // PHP logs and moves on when the delete fails; so does this (the recount then shows nothing removed).
    private static async Task RemoveAsync(NotificationsContext db, TimeProvider clock, ILogger logger, IReadOnlyList<string> invalid, CancellationToken ct)
    {
        if (invalid.Count == 0)
        {
            return;
        }

        try
        {
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            var removed = 0;
            foreach (var chunk in invalid.Chunk(DeleteChunk))
            {
                removed += await db.Database.ExecuteSqlAsync($"delete from notifications.user_devices where device_id = any({chunk})", ct);
            }

            if (removed > 0)
            {
                await Outbox.WriteAsync(db, "notifications.invalid_devices_removed", new DevicesRemoved(removed), clock, ct);
            }

            await transaction.CommitAsync(ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            NotifyLog.CleanupFailed(logger, e.GetType().Name);
        }
    }
}
