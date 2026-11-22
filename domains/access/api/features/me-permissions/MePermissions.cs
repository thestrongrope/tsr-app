using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Net.Http.Headers;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.MePermissions;

// One vertical slice: GET /me/permissions. Contract: domains/access/spec/api.yaml.
// PHP: routes/permissions.php route_me_permissions; the rules are in PermissionsModel::forUser (navigation, revision).
// The answer carries its revision as the ETag; If-None-Match naming it gets 304 with no body. Permissions that cannot be
// loaded are 503 (never an empty 200), with none of the three headers.

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
    [property: JsonPropertyName("scopes")] ScopesBody Scopes,
    [property: JsonPropertyName("navigation")] Navigation Navigation,
    [property: JsonPropertyName("revision")] string Revision);

internal static class MePermissionsEndpoint
{
    private const string WeakPrefix = "W/";

    // PHP's trim(): space, tab, line feed, carriage return, NUL and vertical tab.
    private static readonly char[] PhpTrimmed = [' ', '\t', '\n', '\r', '\0', '\v'];

    public static IEndpointRouteBuilder MapMePermissions(this IEndpointRouteBuilder routes)
    {
        routes.MapGet(
            "/me/permissions",
            (HttpContext context, MePermissionsHandler handler) => handler.HandleAsync(context, context.RequestAborted))
            .RequireMember(createsMember: true)
            .AnswersUnavailable();
        return routes;
    }

    /// <summary>
    /// Does an If-None-Match header name <paramref name="etag"/>? It may list several tags, mark one weak
    /// (<c>W/"x"</c>), or be <c>*</c>. Weak comparison is what 304 uses (RFC 9110); PHP api_etag_matches.
    /// </summary>
    public static bool EtagMatches(string ifNoneMatch, string etag)
    {
        foreach (var part in ifNoneMatch.Split(','))
        {
            var candidate = part.Trim(PhpTrimmed);
            if (candidate == "*" || Strong(candidate) == etag)
            {
                return true;
            }
        }

        return false;
    }

    private static string Strong(string candidate) =>
        candidate.StartsWith(WeakPrefix, StringComparison.Ordinal) ? candidate[WeakPrefix.Length..] : candidate;
}

/// <summary>Sign-in is the only gate (PHP calls no permission check here): the answer is the caller's own.</summary>
internal sealed class MePermissionsHandler(Permissions permissions, TimeProvider clock)
{
    public async Task<IResult> HandleAsync(HttpContext context, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var access = await permissions.ForUserOrUnavailableAsync(caller, ct);
        var navigation = PermissionsSnapshot.NavigationOf(access);
        var revision = PermissionsSnapshot.RevisionOf(PermissionsSnapshot.PayloadVersion, access, navigation);

        // One member's answer, so no shared cache may keep it; no-cache (not no-store) lets the app still ask with If-None-Match.
        var etag = "\"" + revision + "\"";
        var headers = context.Response.Headers;
        headers.ETag = etag;
        headers.CacheControl = "private, no-cache";
        headers.Append(HeaderNames.Vary, HeaderNames.Authorization);
        if (MePermissionsEndpoint.EtagMatches(string.Join(',', context.Request.Headers.IfNoneMatch.ToArray()), etag))
        {
            return Results.StatusCode(StatusCodes.Status304NotModified);
        }

        return Results.Json(new MePermissionsResponse(
            PermissionsSnapshot.PayloadVersion,
            LegacyPermissions.IssuedAt(clock.GetUtcNow()),
            access.Permissions,
            ScopesBody.From(access.Scopes),
            navigation,
            revision), AccessJson.Answers.MePermissionsResponse);
    }
}
