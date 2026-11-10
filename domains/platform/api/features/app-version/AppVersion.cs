using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Tsr.Platform.Api.Domain;

namespace Tsr.Platform.Api.Features.AppVersion;

// Slice: GET /app-version. Public on purpose (an old build may hold an expired token): the payload is
// two integers and two public store URLs. Fails open: see AppCatalog. Contract: spec/api.yaml.

internal static class AppVersionEndpoint
{
    public static IEndpointRouteBuilder MapAppVersion(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/app-version", (AppVersionHandler handler, CancellationToken ct) => handler.HandleAsync(ct));
        return routes;
    }
}

internal sealed class AppVersionHandler(AppCatalogSource source, ILogger<AppVersionHandler> logger)
{
    public async Task<IResult> HandleAsync(CancellationToken ct)
    {
        using var catalog = await source.LoadAsync(ct);
        var payload = AppCatalog.VersionPayload(catalog, logger);
        return Results.Text(payload.ToJsonString(AppCatalogJson.Options), "application/json");
    }
}
