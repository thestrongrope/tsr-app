using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Platform.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Features.GeoPostal;

// Slice: POST /geo/postal {country, code} -> {found, city, state}. A POST so what a member types stays out of access logs.
// Signed in, no permission, rate limited (the 429 comes before body validation). Contract: spec/api.yaml.
// PHP: routes/geo.php route_geo_postal, models/location.php byPostalCode().

internal static class GeoPostalEndpoint
{
    public static IEndpointRouteBuilder MapGeoPostal(this IEndpointRouteBuilder routes)
    {
        routes.MapPost(
            "/geo/postal",
            (HttpContext context, GeoPostalHandler handler) =>
                handler.HandleAsync(context.GetCaller(), context.Request, context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed class GeoPostalHandler(Geo geo, GeoGate gate)
{
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

        var code = GeoField.Read(body.Value!, "code", 20);
        if (!code.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, code.Error!);
        }

        var found = await geo.ByPostalCodeAsync(country.Value!, code.Value!, ct);
        return PlatformJson.Text(new JsonObject { ["found"] = found is not null, ["city"] = found?.City, ["state"] = found?.State });
    }
}
