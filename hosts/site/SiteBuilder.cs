using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Tsr.Shared.Site;

namespace Tsr.Host.Site;

/// <summary>Collects every module's pages, renders each inside the layout and writes plain HTML files.</summary>
public static class SiteBuilder
{
    public static async Task<IReadOnlyList<SitePage>> CollectAsync(
        IEnumerable<SiteModuleInfo> modules, SiteApi api, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(modules);
        var pages = new List<SitePage>();
        foreach (var module in modules)
        {
            pages.AddRange(await module.Pages(api, ct));
        }

        var nav = pages.Where(p => p.NavTitle is not null).ToList();
        pages.Insert(0, new SitePage("/", "Home", typeof(HomePage),
            new Dictionary<string, object?> { ["Nav"] = nav }));

        var duplicate = pages.GroupBy(p => p.Path, StringComparer.Ordinal).FirstOrDefault(g => g.Count() > 1);
        if (duplicate is not null)
        {
            throw new SiteBuildException($"Two pages claim {duplicate.Key}; the site is not built.");
        }

        return pages;
    }

    public static async Task<string> RenderAsync(SitePage page, IReadOnlyList<SitePage> nav)
    {
        ArgumentNullException.ThrowIfNull(page);
        await using var services = new ServiceCollection().AddLogging().BuildServiceProvider();
        await using var renderer = new HtmlRenderer(services, services.GetRequiredService<ILoggerFactory>());
        var html = await renderer.Dispatcher.InvokeAsync(async () =>
        {
            var parameters = ParameterView.FromDictionary(new Dictionary<string, object?>
            {
                [nameof(Layout.Page)] = page,
                [nameof(Layout.Nav)] = nav,
            });
            var output = await renderer.RenderComponentAsync<Layout>(parameters);
            return output.ToHtmlString();
        });
        return "<!doctype html>\n" + html;
    }

    /// <summary>
    /// Empties <paramref name="outDir"/> and keeps the folder itself (creating it when missing): in production it is a mounted volume,
    /// which can be emptied but not deleted.
    /// </summary>
    public static void Clear(string outDir)
    {
        var root = Directory.CreateDirectory(outDir);
        foreach (var entry in root.EnumerateFileSystemInfos())
        {
            if (entry is DirectoryInfo folder)
            {
                folder.Delete(recursive: true);
            }
            else
            {
                entry.Delete();
            }
        }
    }

    /// <summary>
    /// Writes a robots.txt that asks every crawler to stay out, when <paramref name="noCrawl"/> (the setting TSR_SITE_NO_CRAWL) is "true".
    /// Any other value writes nothing, so a site built by hand is as it was.
    /// </summary>
    public static async Task WriteRobotsAsync(string outDir, string? noCrawl, CancellationToken ct)
    {
        if (!string.Equals(noCrawl, "true", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        await File.WriteAllTextAsync(Path.Combine(outDir, "robots.txt"), "User-agent: *\nDisallow: /\n", ct);
    }

    /// <summary>Writes page.Path/index.html under <paramref name="outDir"/>, refusing any path outside it.</summary>
    public static async Task WriteAsync(string outDir, SitePage page, string html, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(page);
        var root = Path.GetFullPath(outDir);
        var folder = Path.GetFullPath(Path.Combine(root, page.Path.Trim('/')));
        if (!folder.StartsWith(root, StringComparison.Ordinal))
        {
            throw new SiteBuildException($"Page path {page.Path} leaves the output folder; the site is not built.");
        }

        Directory.CreateDirectory(folder);
        await File.WriteAllTextAsync(Path.Combine(folder, "index.html"), html, ct);
    }
}
