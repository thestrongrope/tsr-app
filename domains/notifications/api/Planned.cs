using Microsoft.AspNetCore.Routing;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api;

/// <summary>
/// notifications's operations whose slice is not built yet: placeholders that sign the caller in and answer 501 (shared/api/PlannedRoutes.cs).
/// Building a slice: delete its line here, set its state to built in docs/specs/initial-build/operations.csv.
/// </summary>
internal static class Planned
{
    public static IEndpointRouteBuilder MapPlannedRoutes(this IEndpointRouteBuilder routes)
    {
        routes.MapPlanned(
            ("POST", "/classes/{class_id}/notifications"),
            ("POST", "/reports/pending/nudge"),
            ("GET", "/admin/whatsapp/reminders"),
            ("PUT", "/admin/whatsapp/reminders/{reminder_id}"),
            ("POST", "/admin/whatsapp/reminders/{reminder_id}/run"),
            ("GET", "/admin/whatsapp/runs"),
            ("GET", "/admin/whatsapp/runs/{run_id}"),
            ("POST", "/admin/whatsapp/test"),
            ("GET", "/admin/whatsapp/link"),
            ("GET", "/admin/whatsapp/link/qr"),
            ("POST", "/admin/whatsapp/link/relink"),
            ("POST", "/admin/whatsapp/link/logout"),
            ("POST", "/notifications/send"),
            ("GET", "/notifications/history"),
            ("POST", "/notifications/cleanup-invalid-tokens"),
            ("GET", "/notifications/stats"));
        return routes;
    }
}
