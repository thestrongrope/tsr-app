using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace Tsr.Shared.Api;

/// <summary>Endpoint metadata that marks a route as a placeholder: signed in as the real route will require, then 501.</summary>
public sealed record PlannedRoute;

/// <summary>
/// Placeholders for operations whose slice is not built yet (hosts/api: docs/specs/initial-build/operations.csv, state
/// <c>planned</c>). Each domain lists its own in one <c>Planned.cs</c>; a slice replaces a placeholder by deleting its line.
/// A placeholder asks for the same sign-in the real route will, then answers 501 <c>{"detail": "Not implemented"}</c>.
/// It never creates a member, even where PHP's route does (<c>api_authenticate(true)</c>), because it must change nothing.
/// Path parameters match one non-empty segment, as PHP's router does.
/// </summary>
public static class PlannedRouteExtensions
{
    /// <summary>Placeholders for routes that need a signed-in member (looked up, never created).</summary>
    public static IEndpointRouteBuilder MapPlanned(this IEndpointRouteBuilder routes, params (string Method, string Path)[] operations)
    {
        foreach (var (method, path) in operations)
        {
            routes.MapPlannedOne(method, path).RequireMember();
        }

        return routes;
    }

    /// <summary>Placeholders for routes anyone may call.</summary>
    public static IEndpointRouteBuilder MapPlannedPublic(this IEndpointRouteBuilder routes, params (string Method, string Path)[] operations)
    {
        foreach (var (method, path) in operations)
        {
            routes.MapPlannedOne(method, path);
        }

        return routes;
    }

    private static RouteHandlerBuilder MapPlannedOne(this IEndpointRouteBuilder routes, string method, string path) =>
        routes.MapMethods(path, [method], () => Problem.Detail(StatusCodes.Status501NotImplemented, "Not implemented"))
            .WithMetadata(new PlannedRoute());
}
