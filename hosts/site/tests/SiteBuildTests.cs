using System.Net;
using Tsr.Shared.Site;
using NUnit.Framework;

namespace Tsr.Host.Site.Tests;

/// <summary>What the generator must do with what the API returns: escape it, and fail loudly.</summary>
public sealed class SiteBuildTests
{
    [Test]
    public async Task Article_text_is_escaped_and_the_page_has_no_script()
    {
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, FakeApi.Healthy(), CancellationToken.None);
        var article = pages.Single(p => p.Path == "/articles/synthetic-published-article/");

        var html = await SiteBuilder.RenderAsync(article, []);

        Assert.That(html, Does.Contain("&lt;script&gt;alert(1)&lt;/script&gt;"));
        Assert.That(html, Does.Not.Contain("<script").IgnoreCase);
        Assert.That(html, Does.Contain("<p>First paragraph.</p>"));
    }

    [TestCase("/health")]
    [TestCase("/articles")]
    public async Task An_api_error_stops_the_build(string failingPath)
    {
        var answers = new[] { ("/health", HttpStatusCode.OK, FakeApi.HealthJson), ("/articles", HttpStatusCode.OK, FakeApi.ArticlesJson) }
            .Select(a => a.Item1 == failingPath ? (a.Item1, HttpStatusCode.InternalServerError, """{"detail":"down"}""") : a)
            .ToArray();

        await Assert.ThrowsAsync<SiteBuildException>(() => SiteBuilder.CollectAsync(SiteModules.All, FakeApi.With(answers), CancellationToken.None));
    }

    [TestCase("../escape")]
    [TestCase("a/b")]
    [TestCase("Upper")]
    public async Task An_unsafe_slug_stops_the_build(string slug)
    {
        var json = FakeApi.ArticlesJson.Replace("synthetic-published-article", slug, StringComparison.Ordinal);
        var api = FakeApi.With(("/health", HttpStatusCode.OK, FakeApi.HealthJson), ("/articles", HttpStatusCode.OK, json));

        await Assert.ThrowsAsync<SiteBuildException>(() => SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None));
    }

    [Test]
    public async Task A_page_path_outside_the_output_folder_is_refused()
    {
        var root = Path.Combine(Path.GetTempPath(), "tsr-site-test-" + Guid.NewGuid().ToString("N"));
        var page = new SitePage("/../outside/", "x", typeof(HomePage), new Dictionary<string, object?>());

        await Assert.ThrowsAsync<SiteBuildException>(() => SiteBuilder.WriteAsync(root, page, "<p>x</p>", CancellationToken.None));
        Assert.That(Directory.Exists(Path.Combine(root, "..", "outside")), Is.False);
    }
}
