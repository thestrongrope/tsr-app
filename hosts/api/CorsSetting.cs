using Microsoft.AspNetCore.Cors.Infrastructure;

namespace Tsr.Host.Api;

/// <summary>
/// The browser origins that may call this API (issue 63), named in the setting TSR_CORS_ORIGINS, comma-separated. A browser lets a page on
/// one origin call an API on another only when the API names that origin; the phone and desktop apps are not browsers and never ask.
/// Unset or empty names none. Sign-in is a bearer token in a header, so credentials (cookies) are never allowed across origins.
/// </summary>
public static class CorsSetting
{
    public const string Name = "TSR_CORS_ORIGINS";

    /// <summary>
    /// The response header a page may read besides the browser's own short list: the app reads it to notice that a member's permissions
    /// changed. The name is repeated from access's PermissionsRevisionHeader, which is not public; no test ties the two together.
    /// </summary>
    private const string PermissionsRevision = "X-Permissions-Revision";

    /// <summary>
    /// The origins the setting lists, trimmed and in order. An entry that is not one web origin (scheme, host, optional port, nothing
    /// else) stops the start and is named: a wildcard or a mistyped entry must never quietly allow more, or fewer, than was meant.
    /// </summary>
    public static string[] Origins(string? setting)
    {
        var origins = (setting ?? string.Empty).Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        foreach (var origin in origins)
        {
            if (!IsOneOrigin(origin))
            {
                throw new InvalidOperationException(
                    Name + " has the entry '" + origin + "', which is not a web origin such as https://app.example.org (no path, no trailing slash, no wildcard).");
            }
        }

        return origins;
    }

    /// <summary>Registers the policy for the listed origins. False when none is listed: the host then adds no CORS middleware.</summary>
    public static bool Register(IServiceCollection services, string? setting)
    {
        var origins = Origins(setting);
        if (origins.Length == 0)
        {
            return false;
        }

        services.AddCors(options => options.AddDefaultPolicy(policy => Allow(policy, origins)));
        return true;
    }

    private static void Allow(CorsPolicyBuilder policy, string[] origins) =>
        policy.WithOrigins(origins).AllowAnyMethod().AllowAnyHeader().WithExposedHeaders(PermissionsRevision);

    private static bool IsOneOrigin(string entry) =>
        !entry.Contains('*')
        && Uri.TryCreate(entry, UriKind.Absolute, out var uri)
        && (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps)
        && string.Equals(uri.GetLeftPart(UriPartial.Authority), entry, StringComparison.OrdinalIgnoreCase);
}
