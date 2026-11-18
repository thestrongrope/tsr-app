using Tsr.Content.Site;
using Tsr.Host.Site;
using Tsr.Shared.Site;

// Composition root of the static site: which domain site modules to build, from which API, into
// which folder. Usage: dotnet run --project hosts/site [outDir]  (default build/site).
// TSR_BASE_URL picks the API (default: the synthetic test stack's gateway, never the dev stack, which may hold
// real data). TSR_SITE_NO_CRAWL=true adds a robots.txt
// that keeps crawlers out (the production stack sets it). Any failure exits non-zero and leaves no claim
// of a finished site.

var outDir = args.Length > 0 ? args[0] : Path.Combine("build", "site");
var baseUrl = new Uri(Environment.GetEnvironmentVariable("TSR_BASE_URL") ?? "http://localhost:8089");

using var http = new HttpClient { BaseAddress = baseUrl, Timeout = TimeSpan.FromSeconds(10) };
using var cancel = new CancellationTokenSource(TimeSpan.FromMinutes(5));
var api = new SiteApi(http);

try
{
    var pages = await SiteBuilder.CollectAsync(SiteModules.All, api, cancel.Token);
    SiteBuilder.RequireFiles(pages, SiteBuilder.StaticFilesFolder);
    var menu = await ContentSite.MenuAsync(api, cancel.Token);
    // The whole site is written to a folder of its own first. Only a finished site replaces the pages built before, so an
    // API that is down, a body that cannot be rendered or the time limit leaves the old pages in place.
    var finished = Directory.CreateTempSubdirectory("tsr-site-").FullName;
    try
    {
        foreach (var page in pages)
        {
            var html = await SiteBuilder.RenderAsync(page, menu);
            await SiteBuilder.WriteAsync(finished, page, html, cancel.Token);
        }

        await SiteBuilder.WriteNotFoundAsync(finished, menu, cancel.Token);
        SiteBuilder.CopyStaticFiles(SiteBuilder.StaticFilesFolder, finished);
        await SiteBuilder.WriteRobotsAsync(finished, Environment.GetEnvironmentVariable("TSR_SITE_NO_CRAWL"), cancel.Token);
        SiteBuilder.Replace(finished, outDir);
    }
    finally
    {
        Directory.Delete(finished, recursive: true);
    }

    Console.WriteLine($"site: {pages.Count} pages from {baseUrl} written to {Path.GetFullPath(outDir)}");
    return 0;
}
catch (Exception e) when (e is SiteBuildException or HttpRequestException or TaskCanceledException)
{
    await Console.Error.WriteLineAsync("site: build failed: " + e.Message);
    return 1;
}
