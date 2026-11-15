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

    [Test]
    public void Clearing_the_output_folder_removes_what_is_in_it_and_keeps_the_folder()
    {
        // The folder may be a mounted volume, which cannot be deleted, only emptied.
        var root = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;
        Directory.CreateDirectory(Path.Combine(root, "articles", "old"));
        File.WriteAllText(Path.Combine(root, "articles", "old", "index.html"), "old");
        File.WriteAllText(Path.Combine(root, "site.css"), "old");

        SiteBuilder.Clear(root);

        Assert.That(Directory.Exists(root), Is.True);
        Assert.That(Directory.EnumerateFileSystemEntries(root), Is.Empty);
        Directory.Delete(root);
    }

    [Test]
    public void Clearing_a_folder_that_does_not_exist_creates_it()
    {
        var root = Path.Combine(Path.GetTempPath(), "tsr-site-test-" + Guid.NewGuid().ToString("N"));

        SiteBuilder.Clear(root);

        Assert.That(Directory.Exists(root), Is.True);
        Directory.Delete(root);
    }

    [TestCase("true", true)]
    [TestCase("TRUE", true)]
    [TestCase("false", false)]
    [TestCase(null, false)]
    public async Task Robots_txt_is_written_only_when_crawling_is_switched_off(string? setting, bool written)
    {
        var root = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;

        await SiteBuilder.WriteRobotsAsync(root, setting, CancellationToken.None);

        var file = Path.Combine(root, "robots.txt");
        Assert.That(File.Exists(file), Is.EqualTo(written));
        if (written)
        {
            Assert.That(await File.ReadAllTextAsync(file), Is.EqualTo("User-agent: *\nDisallow: /\n"));
        }

        Directory.Delete(root, recursive: true);
    }
}
