using Tsr.Host.Site;
using Tsr.Shared.Site;

// Composition root of the static site: which domain site modules to build, from which API, into
// which folder. Usage: dotnet run --project hosts/site [outDir]  (default build/site).
// TSR_BASE_URL picks the API (default: the dev stack's gateway). TSR_SITE_NO_CRAWL=true adds a robots.txt
// that keeps crawlers out (the production stack sets it). Any failure exits non-zero and leaves no claim
// of a finished site.

var outDir = args.Length > 0 ? args[0] : Path.Combine("build", "site");
var baseUrl = new Uri(Environment.GetEnvironmentVariable("TSR_BASE_URL") ?? "http://localhost:8088");

using var http = new HttpClient { BaseAddress = baseUrl, Timeout = TimeSpan.FromSeconds(10) };
using var cancel = new CancellationTokenSource(TimeSpan.FromMinutes(5));
var api = new SiteApi(http);

try
{
    var pages = await SiteBuilder.CollectAsync(SiteModules.All, api, cancel.Token);
    var nav = pages.Where(p => p.NavTitle is not null).ToList();
    // Only after every page was collected: an API that is down leaves the pages built before in place.
    SiteBuilder.Clear(outDir);

    foreach (var page in pages)
    {
        var html = await SiteBuilder.RenderAsync(page, nav);
        await SiteBuilder.WriteAsync(outDir, page, html, cancel.Token);
    }

    await File.WriteAllTextAsync(Path.Combine(outDir, "site.css"), SiteStyle.Css, cancel.Token);
    await SiteBuilder.WriteRobotsAsync(outDir, Environment.GetEnvironmentVariable("TSR_SITE_NO_CRAWL"), cancel.Token);
    Console.WriteLine($"site: {pages.Count} pages from {baseUrl} written to {Path.GetFullPath(outDir)}");
    return 0;
}
catch (Exception e) when (e is SiteBuildException or HttpRequestException or TaskCanceledException)
{
    await Console.Error.WriteLineAsync("site: build failed: " + e.Message);
    return 1;
}
