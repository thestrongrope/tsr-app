using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Platform.Api.Domain;

namespace Tsr.Platform.Api.Features.Health;

// Slice: GET /health. Says the process is up; it does not prove the database is reachable.

internal sealed record HealthResponse(string Status);

internal static class HealthEndpoint
{
    public static IEndpointRouteBuilder MapHealth(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/health", () => Results.Json(new HealthResponse("ok"), PlatformJson.Answers.HealthResponse));
        return routes;
    }
}
