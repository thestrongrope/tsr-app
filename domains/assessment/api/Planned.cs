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
            ("GET", "/classes/{class_id}/mcq/manage"),
            ("POST", "/classes/{class_id}/mcq"),
            ("GET", "/classes/{class_id}/mcq/topics"),
            ("GET", "/classes/{class_id}/mcq/standard"),
            ("POST", "/classes/{class_id}/mcq/standard/{mcq_id}/copy"),
            ("GET", "/mcq/copy/classes"),
            ("GET", "/mcq/copy/classes/{class_id}/topics"),
            ("GET", "/mcq/copy/classes/{class_id}/quizzes"),
            ("GET", "/mcq/manage/{quiz_id}/scores"),
            ("GET", "/mcq/manage/{quiz_id}/offline"),
            ("POST", "/mcq/manage/{quiz_id}/offline"),
            ("GET", "/mcq/manage/{quiz_id}/sheet"),
            ("GET", "/mcq/manage/{quiz_id}"),
            ("PUT", "/mcq/manage/{quiz_id}"),
            ("POST", "/mcq/manage/{quiz_id}/publish"),
            ("POST", "/mcq/manage/{quiz_id}/deactivate"),
            ("POST", "/mcq/manage/{quiz_id}/copy"));
        return routes;
    }
}
