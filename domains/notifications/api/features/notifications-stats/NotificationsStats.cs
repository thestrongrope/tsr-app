using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.NotificationsStats;

// Slice: GET /notifications/stats -> {total_notifications, total_devices_targeted, total_successful, total_failed, last_sent_at}: delivery totals across every notification ever sent. Contract: spec/api.yaml.
// PHP: routes/notifications.php route_notifications_stats, MobileNotificationsModel::stats. notifications:broadcast (403 "Only super administrators can view notification statistics"), the admin audit row.
// On an empty table the sums and the date are null (kept: the dashboard reads them with ?? 0).

internal static class NotificationsStatsSlice
{
    internal sealed record Totals(long TotalNotifications, long? Devices, long? Successful, long? Failed, DateTimeOffset? LastSentAt);

    public static IEndpointRouteBuilder MapNotificationsStats(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/notifications/stats", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NotificationsContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var refusal = await NotifyGuards.AdminAsync(context, db, permissions, caller, "view notification statistics", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var rows = await db.Database
            .SqlQuery<Totals>($"""
                select count(*) as "TotalNotifications", sum(device_count)::bigint as "Devices", sum(success_count)::bigint as "Successful",
                       sum(failure_count)::bigint as "Failed", max(sent_at) as "LastSentAt"
                from notifications.notifications
                """)
            .ToListAsync(ct);
        var totals = rows[0];
        return Results.Json(new Dictionary<string, object?>
        {
            ["total_notifications"] = totals.TotalNotifications,
            ["total_devices_targeted"] = totals.Devices,
            ["total_successful"] = totals.Successful,
            ["total_failed"] = totals.Failed,
            ["last_sent_at"] = totals.LastSentAt is null ? null : NotifyGuards.IsoStamp(totals.LastSentAt.Value),
        });
    }
}
