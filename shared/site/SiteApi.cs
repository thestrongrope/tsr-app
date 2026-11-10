using System.Net.Http.Json;
using System.Text.Json;

namespace Tsr.Shared.Site;

/// <summary>
/// How a domain's site module reads the API at build time: the same public HTTP contract the app
/// uses, never the database. Any failure stops the build, so a broken API can never publish an
/// empty or partial site.
/// </summary>
public sealed class SiteApi
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private readonly HttpClient _http;

    /// <param name="http">Must have a BaseAddress and a Timeout (CODING-GUIDELINES MUST 3).</param>
    public SiteApi(HttpClient http)
    {
        ArgumentNullException.ThrowIfNull(http);
        if (http.BaseAddress is null)
        {
            throw new ArgumentException("The site's HttpClient needs a BaseAddress.", nameof(http));
        }

        _http = http;
    }

    public async Task<T> GetAsync<T>(string path, CancellationToken ct)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(path);
        using var response = await _http.GetAsync(new Uri(path, UriKind.Relative), ct);
        if (!response.IsSuccessStatusCode)
        {
            throw new SiteBuildException($"GET {path} answered {(int)response.StatusCode}; the site is not built.");
        }

        return await response.Content.ReadFromJsonAsync<T>(Json, ct)
            ?? throw new SiteBuildException($"GET {path} returned an empty body; the site is not built.");
    }
}

/// <summary>The site cannot be built from what the API returned.</summary>
public sealed class SiteBuildException(string message) : Exception(message);
