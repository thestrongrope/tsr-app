using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.MePermission;

// One vertical slice: GET /me/permissions/{permission}, one action's scopes for the caller.
// Contract: domains/access/spec/api.yaml. PHP: route_me_permission (scopesOf).

internal sealed record MePermissionResponse(
    [property: JsonPropertyName("permission")] string Permission,
    [property: JsonPropertyName("scopes")] IReadOnlyList<string> Scopes);

internal static class MePermissionEndpoint
{
    public static IEndpointRouteBuilder MapMePermission(this IEndpointRouteBuilder routes)
    {
        routes.MapGet(
            "/me/permissions/{permission}",
            (string permission, HttpContext context, MePermissionHandler handler) =>
                handler.HandleAsync(context.GetCaller(), permission, context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

/// <summary>The scopes the caller holds <c>resource:action</c> in; empty means not held. A name the catalog lacks is 404.</summary>
internal sealed class MePermissionHandler(Permissions permissions)
{
    public async Task<IResult> HandleAsync(Caller? caller, string permission, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.IsKnownAsync(permission, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Unknown permission");
        }

        var scopes = await permissions.ScopesOfAsync(caller, permission, ct);
        return Results.Json(new MePermissionResponse(permission, scopes));
    }
}
