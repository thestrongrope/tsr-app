using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.MePermissions;

// One vertical slice: GET /me/permissions. Contract: domains/access/spec/api.yaml.
// PHP: routes/permissions.php route_me_permissions; the rules are in PermissionsModel::forUser.

/// <summary>What each scope resolves to. Key names are PHP's (snake_case); <c>gender</c> is null, never omitted.</summary>
internal sealed record ScopesBody(
    [property: JsonPropertyName("gender")] int? Gender,
    [property: JsonPropertyName("assigned")] IReadOnlyList<int> Assigned,
    [property: JsonPropertyName("assigned_genders")] IReadOnlyList<int> AssignedGenders,
    [property: JsonPropertyName("own")] IReadOnlyList<int> Own,
    [property: JsonPropertyName("taught")] IReadOnlyList<int> Taught,
    [property: JsonPropertyName("enrolled")] IReadOnlyList<int> Enrolled)
{
    public static ScopesBody From(AccessScopes scopes) =>
        new(scopes.Gender, scopes.Assigned, scopes.AssignedGenders, scopes.Own, scopes.Taught, scopes.Enrolled);
}

internal sealed record MePermissionsResponse(
    [property: JsonPropertyName("version")] int Version,
    [property: JsonPropertyName("issued_at")] string IssuedAt,
    [property: JsonPropertyName("permissions")] IReadOnlyList<string> Permissions,
    [property: JsonPropertyName("scopes")] ScopesBody Scopes);

internal static class MePermissionsEndpoint
{
    /// <summary>The wire version PHP sends; the app reads it.</summary>
    public const int Version = 4;

    public static IEndpointRouteBuilder MapMePermissions(this IEndpointRouteBuilder routes)
    {
        routes.MapGet(
            "/me/permissions",
            (HttpContext context, MePermissionsHandler handler) => handler.HandleAsync(context.GetCaller(), context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

/// <summary>Sign-in is the only gate (PHP calls no permission check here): the answer is the caller's own.</summary>
internal sealed class MePermissionsHandler(Permissions permissions, TimeProvider clock)
{
    public async Task<IResult> HandleAsync(Caller? caller, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var access = await permissions.ForUserAsync(caller, ct);
        return Results.Json(new MePermissionsResponse(
            MePermissionsEndpoint.Version,
            LegacyPermissions.IssuedAt(clock.GetUtcNow()),
            access.Permissions,
            ScopesBody.From(access.Scopes)));
    }
}
