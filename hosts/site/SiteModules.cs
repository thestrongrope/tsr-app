using System.Reflection;
using Tsr.Content.Site;
using Tsr.Platform.Site;
using Tsr.Shared.Site;

namespace Tsr.Host.Site;

/// <summary>One domain's site module as this host sees it: its name, how it builds its pages, its code.</summary>
public sealed record SiteModuleInfo(
    string Name,
    Func<SiteApi, CancellationToken, Task<IReadOnlyList<SitePage>>> Pages,
    Assembly Assembly);

/// <summary>
/// Every domain site module this host builds. Adding a domain's pages: add it here. The tests
/// (tests/) read this list: a site module references only shared/site, never an api project or
/// another domain's site, and builds its pages on its own.
/// </summary>
public static class SiteModules
{
    public static readonly IReadOnlyList<SiteModuleInfo> All =
    [
        new("platform", PlatformSite.PagesAsync, typeof(PlatformSite).Assembly),
        new("content", ContentSite.PagesAsync, typeof(ContentSite).Assembly),
    ];
}
