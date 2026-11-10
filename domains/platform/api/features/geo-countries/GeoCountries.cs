using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Tsr.Platform.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Features.GeoCountries;

// Slice: GET /geo/countries. A signed-in member (a guest finishing sign-up included once registered), no permission,
// rate limited. Contract: spec/api.yaml. PHP: routes/geo.php route_geo_countries, models/location.php countries().

internal static class GeoCountriesEndpoint
{
    public static IEndpointRouteBuilder MapGeoCountries(this IEndpointRouteBuilder routes)
    {
        routes.MapGet(
            "/geo/countries",
            (HttpContext context, GeoCountriesHandler handler) => handler.HandleAsync(context.GetCaller(), context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed class GeoCountriesHandler(PlatformContext db, GeoGate gate, ILogger<GeoCountriesHandler> logger)
{
    /// <summary>The list has about 250 rows; this is a safety bound, not a page size.</summary>
    private const int MaxRows = 1000;

    public async Task<IResult> HandleAsync(Caller? caller, CancellationToken ct)
    {
        if (gate.Refuse(caller) is { } refused)
        {
            return refused;
        }

        var rows = await GeoTables.OrEmptyAsync(() => ReadAsync(ct), [], logger);
        var countries = new JsonArray();
        foreach (var row in rows)
        {
            countries.Add(new JsonObject { ["code"] = row.Code, ["name"] = row.Name, ["hasPostalCodes"] = row.HasPostalCodes });
        }

        return Results.Json(new JsonObject { ["countries"] = countries });
    }

    private Task<List<GeoCountry>> ReadAsync(CancellationToken ct) =>
        db.GeoCountries.AsNoTracking().OrderBy(c => c.Name).ThenBy(c => c.Code).Take(MaxRows).ToListAsync(ct);
}
