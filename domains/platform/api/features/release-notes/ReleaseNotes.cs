using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Tsr.Platform.Api.Domain;

namespace Tsr.Platform.Api.Features.ReleaseNotes;

// Slice: GET /release-notes. Public for the same reason as /app-version. Reads the same catalog through the
// same rules, so the two cannot disagree; an unusable catalog is an empty list, never an error.

internal static class ReleaseNotesEndpoint
{
    public static IEndpointRouteBuilder MapReleaseNotes(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/release-notes", (ReleaseNotesHandler handler, CancellationToken ct) => handler.HandleAsync(ct));
        return routes;
    }
}

internal sealed class ReleaseNotesHandler(AppCatalogSource source, ILogger<ReleaseNotesHandler> logger)
{
    public async Task<IResult> HandleAsync(CancellationToken ct)
    {
        using var catalog = await source.LoadAsync(ct);
        var payload = new JsonObject { ["releases"] = AppCatalog.Releases(catalog, logger) };
        return Results.Text(payload.ToJsonString(AppCatalogJson.Options), "application/json");
    }
}
