using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Npgsql;
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

internal sealed class GeoCountriesHandler(NpgsqlDataSource source, GeoGate gate, ILogger<GeoCountriesHandler> logger)
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
            countries.Add((JsonNode?)new JsonObject { ["code"] = row.Code, ["name"] = row.Name, ["hasPostalCodes"] = row.HasPostalCodes });
        }

        return PlatformJson.Text(new JsonObject { ["countries"] = countries });
    }

    private Task<List<Country>> ReadAsync(CancellationToken ct) =>
        source.ListAsync(
            $"""
            select c.code::text as "Code", c.name as "Name", c.has_postal_codes as "HasPostalCodes"
            from platform.geo_countries c
            order by c.name, c.code
            limit {MaxRows}
            """,
            row => new Country(row.Text("Code"), row.Text("Name"), row.Bool("HasPostalCodes")),
            ct);

    private sealed record Country(string Code, string Name, bool HasPostalCodes);
}
