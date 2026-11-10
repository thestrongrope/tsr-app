using System.Net;
using Tsr.Shared.Site;
using Xunit;

namespace Tsr.Host.Site.Tests;

/// <summary>
/// The site's version of hosts/api's module rules: a domain's site module reads only the published
/// API through shared/site (never an api project, never another domain's site module), and builds
/// its pages on its own, so domains compose into the site without knowing about each other.
/// </summary>
public sealed class SiteModuleBoundaryTests
{
    private const string SharedSite = "Tsr.Shared.Site";

    public static TheoryData<string> ModuleNames()
    {
        var data = new TheoryData<string>();
        foreach (var module in SiteModules.All)
        {
            data.Add(module.Name);
        }

        return data;
    }

    [Theory]
    [MemberData(nameof(ModuleNames))]
    public void A_site_module_references_only_shared_site(string name)
    {
        var module = SiteModules.All.Single(m => m.Name == name);

        var referenced = module.Assembly.GetReferencedAssemblies()
            .Select(a => a.Name!)
            .Where(n => n.StartsWith("Tsr.", StringComparison.Ordinal))
            .ToList();

        Assert.True(referenced.All(r => r == SharedSite), name + " references " + string.Join(", ", referenced));
    }

    [Theory]
    [MemberData(nameof(ModuleNames))]
    public async Task A_site_module_builds_its_pages_alone(string name)
    {
        var module = SiteModules.All.Single(m => m.Name == name);

        var pages = await SiteBuilder.CollectAsync([module], FakeApi.Healthy(), CancellationToken.None);

        Assert.Contains(pages, p => p.Path != "/");
        foreach (var page in pages)
        {
            var html = await SiteBuilder.RenderAsync(page, pages.Where(p => p.NavTitle is not null).ToList());
            Assert.StartsWith("<!doctype html>", html, StringComparison.Ordinal);
        }
    }

    [Fact]
    public async Task Every_module_together_gives_unique_paths_and_one_nav()
    {
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, FakeApi.Healthy(), CancellationToken.None);

        Assert.Equal(pages.Count, pages.Select(p => p.Path).Distinct(StringComparer.Ordinal).Count());
        Assert.Equal(["/status/", "/articles/"], pages.Where(p => p.NavTitle is not null).Select(p => p.Path));
    }
}
