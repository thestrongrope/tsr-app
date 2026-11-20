using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Tsr.Content.Site;
using Tsr.Shared.Site;

namespace Tsr.Host.Site;

/// <summary>Collects every module's pages, renders each inside the layout and writes plain HTML files.</summary>
public static class SiteBuilder
{
    /// <summary>hosts/site/wwwroot as the build copies it beside the program.</summary>
    public static string StaticFilesFolder => Path.Combine(AppContext.BaseDirectory, "wwwroot");

    public static async Task<IReadOnlyList<SitePage>> CollectAsync(
        IEnumerable<SiteModuleInfo> modules, SiteApi api, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(modules);
        var pages = new List<SitePage>();
        foreach (var module in modules)
        {
            pages.AddRange(await module.Pages(api, ct));
        }

        var duplicate = pages.GroupBy(p => p.Path, StringComparer.Ordinal).FirstOrDefault(g => g.Count() > 1);
        if (duplicate is not null)
        {
            throw new SiteBuildException($"Two pages claim {duplicate.Key}; the site is not built.");
        }

        return pages;
    }

    /// <summary>
    /// The whole build: collects the pages, stops when a file a page shows is missing, renders every page into a folder of its own
    /// and only then replaces <paramref name="outDir"/>, so an API that is down, a body that cannot be rendered, a missing file or the
    /// time limit leaves the pages built before in place. Returns the number of pages.
    /// </summary>
    public static async Task<int> BuildAsync(
        IEnumerable<SiteModuleInfo> modules, SiteApi api, string outDir, string? noCrawl, CancellationToken ct)
    {
        var pages = await CollectAsync(modules, api, ct);
        RequireFiles(pages, StaticFilesFolder);
        var menu = await ContentSite.MenuAsync(api, ct);
        var finished = Directory.CreateTempSubdirectory("tsr-site-").FullName;
        try
        {
            foreach (var page in pages)
            {
                await WriteAsync(finished, page, await RenderAsync(page, menu), ct);
            }

            await WriteNotFoundAsync(finished, menu, ct);
            CopyStaticFiles(StaticFilesFolder, finished);
            await WriteRobotsAsync(finished, noCrawl, ct);
            Replace(finished, outDir);
        }
        finally
        {
            Directory.Delete(finished, recursive: true);
        }

        return pages.Count;
    }

    /// <summary>The page inside the frame. <paramref name="menu"/> is the frame's list of categories (ContentSite.MenuAsync).</summary>
    public static async Task<string> RenderAsync(SitePage page, IReadOnlyList<MenuCategory> menu)
    {
        ArgumentNullException.ThrowIfNull(page);
        await using var services = new ServiceCollection().AddLogging().BuildServiceProvider();
        await using var renderer = new HtmlRenderer(services, services.GetRequiredService<ILoggerFactory>());
        var html = await renderer.Dispatcher.InvokeAsync(async () =>
        {
            var parameters = ParameterView.FromDictionary(new Dictionary<string, object?>
            {
                [nameof(Layout.Page)] = page,
                [nameof(Layout.Menu)] = menu,
            });
            var output = await renderer.RenderComponentAsync<Layout>(parameters);
            return output.ToHtmlString();
        });
        return "<!doctype html>\n" + html;
    }

    /// <summary>
    /// Puts a finished site in place while the server reads <paramref name="outDir"/>: every file of <paramref name="finishedDir"/> is put
    /// over what is there, <c>robots.txt</c> first (a crawler never finds the pages without it), and only then is what the new site does not
    /// hold removed. The folder (in production a mounted volume, created when missing) is never emptied, so no page is served without its
    /// stylesheet, and a copy that fails removes nothing that was served.
    /// Each file arrives under a temporary name and is renamed, so the server never reads half a file.
    /// </summary>
    public static void Replace(string finishedDir, string outDir)
    {
        Directory.CreateDirectory(outDir);
        var files = Directory.EnumerateFiles(finishedDir, "*", SearchOption.AllDirectories)
            .Select(file => Path.GetRelativePath(finishedDir, file))
            .OrderBy(relative => relative == "robots.txt" ? 0 : 1)
            .ToList();
        foreach (var relative in files)
        {
            PutInPlace(Path.Combine(finishedDir, relative), Path.Combine(outDir, relative));
        }

        RemoveWhatIsNotIn(files.Select(relative => Path.GetFullPath(Path.Combine(outDir, relative))).ToHashSet(StringComparer.Ordinal), outDir);
    }

    private const string ArrivingSuffix = ".tsr-arriving";

    private static void PutInPlace(string source, string target)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(target)!);
        var arriving = target + ArrivingSuffix;
        File.Copy(source, arriving, overwrite: true);
        File.Move(arriving, target, overwrite: true);
    }

    /// <summary>Deletes every file of <paramref name="outDir"/> that is not in <paramref name="kept"/> (full paths), then every folder left empty.</summary>
    private static void RemoveWhatIsNotIn(HashSet<string> kept, string outDir)
    {
        foreach (var file in Directory.EnumerateFiles(outDir, "*", SearchOption.AllDirectories).ToList())
        {
            if (!kept.Contains(Path.GetFullPath(file)))
            {
                File.Delete(file);
            }
        }

        // Deepest first, so a folder whose only content was an emptied folder goes too.
        foreach (var folder in Directory.EnumerateDirectories(outDir, "*", SearchOption.AllDirectories).OrderByDescending(path => path.Length).ToList())
        {
            if (!Directory.EnumerateFileSystemEntries(folder).Any())
            {
                Directory.Delete(folder);
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

    /// <summary>
    /// Copies every file of <paramref name="staticFolder"/> (the stylesheet, the script, the fonts, the images), with its folders,
    /// into <paramref name="outDir"/>. A missing folder stops the build: a site without its stylesheet must not be published.
    /// </summary>
    public static void CopyStaticFiles(string staticFolder, string outDir)
    {
        if (!Directory.Exists(staticFolder))
        {
            throw new SiteBuildException($"The static files folder {staticFolder} is missing; the site is not built.");
        }

        foreach (var file in Directory.EnumerateFiles(staticFolder, "*", SearchOption.AllDirectories))
        {
            var target = Path.Combine(outDir, Path.GetRelativePath(staticFolder, file));
            Directory.CreateDirectory(Path.GetDirectoryName(target)!);
            File.Copy(file, target, overwrite: true);
        }
    }

    /// <summary>
    /// Stops the build when a file a page says it shows (<see cref="SitePage.Files"/>, a site address such as "/images/x.jpeg", or its <see cref="SitePage.Script"/>)
    /// is not in <paramref name="staticFolder"/>, naming the file and the page: a page is never published with a broken image.
    /// </summary>
    public static void RequireFiles(IEnumerable<SitePage> pages, string staticFolder)
    {
        ArgumentNullException.ThrowIfNull(pages);
        var root = Path.GetFullPath(staticFolder) + Path.DirectorySeparatorChar;
        foreach (var page in pages)
        {
            RequireSitePath(page, nameof(SitePage.Script), page.Script);
            RequireSitePath(page, nameof(SitePage.RefreshTo), page.RefreshTo);
        }

        var needed = pages.SelectMany(page => (page.Files ?? []).Append(page.Script).OfType<string>().Select(file => (Page: page.Path, File: file)));
        foreach (var (page, file) in needed)
        {
            var path = Path.GetFullPath(Path.Combine(root, file.TrimStart('/')));
            var inside = file.StartsWith('/') && path.StartsWith(root, StringComparison.Ordinal);
            if (!inside || !File.Exists(path))
            {
                throw new SiteBuildException($"The file {file} that the page {page} shows is missing from {staticFolder}; the site is not built.");
            }
        }
    }

    private static void RequireSitePath(SitePage page, string field, string? address)
    {
        if (address is not null && !SitePaths.IsSitePath(address))
        {
            throw new SiteBuildException($"The {field} of the page {page.Path} is not a path on this site (one '/' and then a character that is not '/' or a backslash, no white space); the site is not built.");
        }
    }

    /// <summary>
    /// Writes 404.html, the page the server answers for an address the site does not publish (hosts/site/Dockerfile.server),
    /// in the site's frame.
    /// </summary>
    public static async Task WriteNotFoundAsync(string outDir, IReadOnlyList<MenuCategory> menu, CancellationToken ct)
    {
        var page = new SitePage("/404/", "404: This page could not be found.", typeof(NotFoundPage), new Dictionary<string, object?>());
        await File.WriteAllTextAsync(Path.Combine(outDir, "404.html"), await RenderAsync(page, menu), ct);
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
