using Microsoft.AspNetCore.Routing;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>
/// identity's operations whose slice is not built yet: placeholders that sign the caller in and answer 501 (shared/api/PlannedRoutes.cs).
/// Building a slice: delete its line here, set its state to built in docs/specs/initial-build/operations.csv.
/// </summary>
internal static class Planned
{
    public static IEndpointRouteBuilder MapPlannedRoutes(this IEndpointRouteBuilder routes)
    {
        routes.MapPlanned(
            ("POST", "/me/deletion-request"),
            ("GET", "/me/deletion-request"),
            ("DELETE", "/me/deletion-request"),
            ("GET", "/admin/deletion-requests"),
            ("POST", "/admin/deletion-requests"),
            ("POST", "/admin/deletion-requests/{request_id}/hold"),
            ("POST", "/admin/deletion-requests/{request_id}/confirmation-sent"),
            ("POST", "/admin/deletion-requests/{request_id}/complete"));
        routes.MapPlannedPublic(
            ("POST", "/auth/debug-token"));
        return routes;
    }
}
