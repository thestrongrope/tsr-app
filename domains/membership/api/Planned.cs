using Microsoft.AspNetCore.Routing;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api;

/// <summary>
/// membership's operations whose slice is not built yet: placeholders that sign the caller in and answer 501 (shared/api/PlannedRoutes.cs).
/// Building a slice: delete its line here, set its state to built in docs/specs/initial-build/operations.csv.
/// </summary>
internal static class Planned
{
    public static IEndpointRouteBuilder MapPlannedRoutes(this IEndpointRouteBuilder routes)
    {
        routes.MapPlanned(
            ("GET", "/reports/registrations/download"),
            ("GET", "/reports/registrations/allocated/download"),
            ("GET", "/admin/donors/download"));
        return routes;
    }
}
