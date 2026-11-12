using Microsoft.AspNetCore.Routing;
using Tsr.Shared.Api;

namespace Tsr.Access.Api;

/// <summary>
/// access's operations whose slice is not built yet: placeholders that sign the caller in and answer 501 (shared/api/PlannedRoutes.cs).
/// Building a slice: delete its line here, set its state to built in docs/specs/initial-build/operations.csv.
/// </summary>
internal static class Planned
{
    public static IEndpointRouteBuilder MapPlannedRoutes(this IEndpointRouteBuilder routes)
    {
        routes.MapPlanned(
            ("GET", "/admin/class-access/members"),
            ("GET", "/admin/class-access/members/{token}"),
            ("GET", "/admin/class-access/options"),
            ("POST", "/admin/class-access/preview"),
            ("POST", "/admin/class-access/members/{token}/rules"),
            ("POST", "/admin/class-access/rules/{id}/revoke"));
        return routes;
    }
}
