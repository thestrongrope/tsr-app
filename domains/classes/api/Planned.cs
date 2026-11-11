using Microsoft.AspNetCore.Routing;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api;

/// <summary>
/// classes's operations whose slice is not built yet: placeholders that sign the caller in and answer 501 (shared/api/PlannedRoutes.cs).
/// Building a slice: delete its line here, set its state to built in docs/specs/initial-build/operations.csv.
/// </summary>
internal static class Planned
{
    public static IEndpointRouteBuilder MapPlannedRoutes(this IEndpointRouteBuilder routes)
    {
        routes.MapPlanned(
            ("GET", "/me/guides"),
            ("GET", "/me/guides/{slug}"),
            ("GET", "/reports/conduction/download"),
            ("GET", "/reports/weekly/download"),
            ("GET", "/reports/summary/download"),
            ("GET", "/reports/students/download"),
            ("GET", "/reports/tsr/download"),
            ("GET", "/reports/pending/download"),
            ("GET", "/reports/subject-conduction/download"),
            ("GET", "/reports/class-sessions/{class_id}/download"),
            ("GET", "/reports/active-teachers/download"));
        return routes;
    }
}
