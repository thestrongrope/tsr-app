using Tsr.Shared.Site;

namespace Tsr.Platform.Site;

/// <summary>As GET /health returns it (domains/platform/spec/api.yaml).</summary>
public sealed record Health(string Status);

/// <summary>platform's pages on the static site: the API's status when the site was built.</summary>
public static class PlatformSite
{
    public static async Task<IReadOnlyList<SitePage>> PagesAsync(SiteApi api, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(api);
        var health = await api.GetAsync<Health>("/health", ct);
        return
        [
            new SitePage("/status/", "Status | The Strong Rope", typeof(StatusPage),
                new Dictionary<string, object?> { ["Health"] = health }, NavTitle: "Status"),
        ];
    }
}
