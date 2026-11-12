using Microsoft.AspNetCore.Routing;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api;

/// <summary>
/// assessment's operations whose slice is not built yet: placeholders that sign the caller in and answer 501 (shared/api/PlannedRoutes.cs).
/// Building a slice: delete its line here, set its state to built in docs/specs/initial-build/operations.csv.
/// </summary>
internal static class Planned
{
    public static IEndpointRouteBuilder MapPlannedRoutes(this IEndpointRouteBuilder routes)
    {
        routes.MapPlanned(
            ("POST", "/classes/{class_id}/mcq"),
            ("POST", "/classes/{class_id}/mcq/standard/{mcq_id}/copy"),
            ("GET", "/mcq/manage/{quiz_id}/scores"),
            ("GET", "/mcq/manage/{quiz_id}/offline"),
            ("POST", "/mcq/manage/{quiz_id}/offline"),
            ("GET", "/mcq/manage/{quiz_id}/sheet"),
            ("POST", "/mcq/manage/{quiz_id}/publish"),
            ("POST", "/mcq/manage/{quiz_id}/copy"));
        return routes;
    }
}
