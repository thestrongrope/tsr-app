using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Tsr.Platform.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Features.GeoCities;

// Slice: POST /geo/cities {country, query} -> {cities: [{name, state}]}: cities of the country starting with the query,
// biggest first, at most 10. A POST so what a member types stays out of access logs. Signed in, no permission, rate
// limited. Contract: spec/api.yaml. PHP: routes/geo.php route_geo_cities, models/location.php searchCities().

internal static class GeoCitiesEndpoint
{
    public static IEndpointRouteBuilder MapGeoCities(this IEndpointRouteBuilder routes)
    {
        routes.MapPost(
            "/geo/cities",
            (HttpContext context, GeoCitiesHandler handler) =>
                handler.HandleAsync(context.GetCaller(), context.Request, context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed class GeoCitiesHandler(PlatformContext db, GeoGate gate, ILogger<GeoCitiesHandler> logger)
{
    /// <summary>Fixed at 10 by the PHP route.</summary>
    private const int Limit = 10;

    private const string Escape = "|";

    public async Task<IResult> HandleAsync(Caller? caller, HttpRequest request, CancellationToken ct)
    {
        if (gate.Refuse(caller) is { } refused)
        {
            return refused;
        }

        var raw = await GeoBodyReader.ReadAsync(request, ct);
        if (raw is null)
        {
            return Problem.Detail(StatusCodes.Status413PayloadTooLarge, "Request body too large");
        }

        var body = GeoBody.Parse(raw);
        if (!body.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, body.Error!);
        }

        var country = GeoField.Read(body.Value!, "country", 2);
        if (!country.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, country.Error!);
        }

        var query = GeoField.Read(body.Value!, "query", 100);
        if (!query.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, query.Error!);
        }

        if (!GeoLookup.CanMatchStoredText(query.Value!))
        {
            // PHP's MariaDB finds nothing for a NUL inside the query; PostgreSQL would refuse the value (500).
            return Results.Json(new JsonObject { ["cities"] = new JsonArray() });
        }

        var pattern = GeoLookup.CityLikePattern(query.Value!);
        var rows = await GeoTables.OrEmptyAsync(() => SearchAsync(PhpText.ToUpperAscii(country.Value!), pattern, ct), [], logger);
        var cities = new JsonArray();
        foreach (var row in rows)
        {
            cities.Add(City(row));
        }

        return Results.Json(new JsonObject { ["cities"] = cities });
    }

    // api_cast with the spec {name: text, state: text?}: entities decoded; a null or empty state is null; a name that is
    // empty becomes the number 0 (PHP's zero of a non-nullable field, which the real data never hits).
    private static JsonObject City(GeoCity row) => new()
    {
        ["name"] = row.Name.Length == 0 ? JsonValue.Create(0) : JsonValue.Create(GeoLookup.DecodeEntities(row.Name)),
        ["state"] = string.IsNullOrEmpty(row.State) ? null : GeoLookup.DecodeEntities(row.State),
    };

    private Task<List<GeoCity>> SearchAsync(string country, string pattern, CancellationToken ct) =>
        db.GeoCities.AsNoTracking()
            .Where(c => c.CountryCode == country && EF.Functions.Like(c.Name, pattern, Escape))
            .OrderByDescending(c => c.Population).ThenBy(c => c.Name).ThenBy(c => c.GeonameId)
            .Take(Limit)
            .ToListAsync(ct);
}
