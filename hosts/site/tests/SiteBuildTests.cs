using System.Net;
using System.Text.RegularExpressions;
using Tsr.Content.Site;
using Tsr.Shared.Site;
using NUnit.Framework;

namespace Tsr.Host.Site.Tests;

/// <summary>What the generator must do with what the API returns: escape it, and fail loudly.</summary>
public sealed partial class SiteBuildTests
{
    private const string ArticleAddress = "/articles/synthetic-published-article/";

    [GeneratedRegex("<script")]
    private static partial Regex ScriptTag();

    private static async Task<string> RenderAsync(string path)
    {
        var api = FakeApi.Healthy();
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None);
        var menu = await ContentSite.MenuAsync(api, CancellationToken.None);
        return await SiteBuilder.RenderAsync(pages.Single(p => p.Path == path), menu);
    }

    [Test]
    public async Task Article_text_is_escaped_and_the_only_scripts_are_the_frame_s_two()
    {
        var html = await RenderAsync(ArticleAddress);

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("&lt;script&gt;alert(1)&lt;/script&gt;"));
            Assert.That(html, Does.Contain(">First paragraph.</p>"));
            // The before-paint theme snippet in the head and site.js: nothing an article brings.
            Assert.That(ScriptTag().Count(html), Is.EqualTo(2));
            Assert.That(html, Does.Contain("localStorage.getItem('theme')==='dark'"));
            Assert.That(html, Does.Contain("<script src=\"/site.js\" defer></script>"));
        });
    }

    [Test]
    public async Task The_article_page_has_the_present_site_s_title_and_reading_time()
    {
        var html = await RenderAsync(ArticleAddress);

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("<title>Synthetic &amp; published article | The Strong Rope</title>"));
            Assert.That(html, Does.Contain("Reading Time: 3 minutes"));
            // The breadcrumb: the parent of the first category, then the category.
            Assert.That(html, Does.Contain("href=\"/articles/?category=foundations\""));
            Assert.That(html, Does.Contain("href=\"/articles/?category=core-terms\""));
            Assert.That(html, Does.Contain("href=\"/articles/?tag=Sample%20Tag\""));
            Assert.That(html, Does.Contain("href=\"/articles/another-synthetic-article/\""));
            // An entity in a title is decoded once and escaped once, never twice.
            Assert.That(html, Does.Not.Contain("&amp;amp;"));
        });
    }

    [Test]
    public async Task The_article_list_shows_every_article_with_its_category_titles()
    {
        var html = await RenderAsync("/articles/");

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("<title>The Strong Rope</title>"));
            Assert.That(html, Does.Contain("All Articles"));
            Assert.That(html, Does.Contain("href=\"/articles/synthetic-published-article/\""));
            Assert.That(html, Does.Contain("href=\"/articles/another-synthetic-article/\""));
            Assert.That(html, Does.Contain("Core Terms"));
            Assert.That(html, Does.Contain("A synthetic excerpt."));
        });
    }

    [Test]
    public async Task The_frame_has_the_menu_s_categories_and_no_claim_about_the_data()
    {
        var html = await RenderAsync("/status/");

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("The path of the Ahle Bait (a.s.)"));
            Assert.That(html, Does.Contain("aria-label=\"Toggle theme\""));
            Assert.That(html, Does.Contain("aria-label=\"Menu\""));
            // A parent is always listed; a child only when it holds an article.
            Assert.That(html, Does.Contain("href=\"/articles/?category=foundations\""));
            Assert.That(html, Does.Contain("href=\"/articles/?category=core-terms\""));
            Assert.That(html, Does.Not.Contain("empty-child"));
            Assert.That(html, Does.Contain("&#xA9; " + DateTime.UtcNow.Year + " The Strong Rope"));
            Assert.That(html, Does.Not.Contain("Synthetic data").IgnoreCase);
        });
    }

    [Test]
    public async Task The_list_is_read_page_by_page_until_no_more()
    {
        const string first = """
            {"success":true,"data":[{"slug":"synthetic-published-article","title":"One","categories":[],"tags":[]}],
            "pagination":{"total":2,"limit":100,"offset":0,"hasMore":true}}
            """;
        const string second = """
            {"success":true,"data":[{"slug":"another-synthetic-article","title":"Two","categories":[],"tags":[]}],
            "pagination":{"total":2,"limit":100,"offset":100,"hasMore":false}}
            """;
        var answers = FakeApi.HealthyAnswers.Where(a => a.Path != FakeApi.ListPath)
            .Append((FakeApi.ListPath + "?limit=100&offset=0", HttpStatusCode.OK, first))
            .Append((FakeApi.ListPath + "?limit=100&offset=100", HttpStatusCode.OK, second))
            .ToArray();
        var api = FakeApi.With(out var fake, answers);

        var pages = await ContentSite.PagesAsync(api, CancellationToken.None);

        Assert.Multiple(() =>
        {
            Assert.That(pages.Select(p => p.Path), Is.EqualTo(new[] { "/articles/", ArticleAddress, "/articles/another-synthetic-article/", "/about/", "/donate/" }));
            Assert.That(fake.Asked.Count(a => a.StartsWith(FakeApi.ListPath + "?", StringComparison.Ordinal)), Is.EqualTo(2));
        });
    }

    [Test]
    public async Task A_list_that_never_ends_stops_the_build()
    {
        const string endless = """
            {"success":true,"data":[{"slug":"synthetic-published-article","title":"One","categories":[],"tags":[]}],
            "pagination":{"total":1,"limit":100,"offset":0,"hasMore":true}}
            """;
        var api = FakeApi.HealthyBut(FakeApi.ListPath, HttpStatusCode.OK, endless);

        await Assert.ThrowsAsync<SiteBuildException>(() => ContentSite.PagesAsync(api, CancellationToken.None));
    }

    [TestCase("/health")]
    [TestCase(FakeApi.ListPath)]
    [TestCase(FakeApi.CategoriesPath)]
    [TestCase(FakeApi.ArticlePath)]
    public async Task An_api_error_stops_the_build(string failingPath)
    {
        var api = FakeApi.HealthyBut(failingPath, HttpStatusCode.InternalServerError, """{"success":false,"error":{"code":"INTERNAL_ERROR","message":"down"}}""");

        await Assert.ThrowsAsync<SiteBuildException>(() => SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None));
    }

    [TestCase(FakeApi.ListPath, """{"success":false,"data":[]}""")]
    [TestCase(FakeApi.ListPath, """{"success":true}""")]
    [TestCase(FakeApi.ArticlePath, """{"success":true,"data":{"slug":"synthetic-published-article","title":"No body"}}""")]
    public async Task An_answer_without_what_a_page_needs_stops_the_build(string path, string json)
    {
        var api = FakeApi.HealthyBut(path, HttpStatusCode.OK, json);

        await Assert.ThrowsAsync<SiteBuildException>(() => SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None));
    }

    [Test]
    public async Task A_percent_encoded_slug_is_written_under_the_characters_it_stands_for_and_linked_as_written()
    {
        // The server decodes the address a browser sends, so the folder carries the decoded name (synthetic Arabic letters).
        const string encoded = "%d9%86%d8%b5-%d8%a2%d8%ae%d8%b1";
        var api = FakeApi.With(FakeApi.HealthyAnswers
            .Select(a => (a.Path.Replace("another-synthetic-article", encoded, StringComparison.Ordinal), a.Status,
                a.Json.Replace("another-synthetic-article", encoded, StringComparison.Ordinal)))
            .ToArray());

        var pages = await ContentSite.PagesAsync(api, CancellationToken.None);
        var list = await SiteBuilder.RenderAsync(pages[0], []);

        Assert.Multiple(() =>
        {
            Assert.That(pages.Select(p => p.Path), Does.Contain("/articles/نص-آخر/"));
            Assert.That(list, Does.Contain("href=\"/articles/" + encoded + "/\""));
        });
    }

    [Test]
    public void Replacing_the_output_puts_the_finished_site_in_place_and_removes_what_was_there()
    {
        // The site is built in a folder of its own and only then put in place, so a build that fails or runs out of time
        // half way never leaves a partial site where the server reads.
        var finished = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;
        var served = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;
        Directory.CreateDirectory(Path.Combine(finished, "articles", "new"));
        File.WriteAllText(Path.Combine(finished, "articles", "new", "index.html"), "new");
        File.WriteAllText(Path.Combine(finished, "robots.txt"), "keep out");
        Directory.CreateDirectory(Path.Combine(served, "articles", "old"));
        File.WriteAllText(Path.Combine(served, "articles", "old", "index.html"), "old");

        SiteBuilder.Replace(finished, served);

        Assert.Multiple(() =>
        {
            Assert.That(File.ReadAllText(Path.Combine(served, "articles", "new", "index.html")), Is.EqualTo("new"));
            Assert.That(File.ReadAllText(Path.Combine(served, "robots.txt")), Is.EqualTo("keep out"));
            Assert.That(Directory.Exists(Path.Combine(served, "articles", "old")), Is.False);
        });
        Directory.Delete(finished, recursive: true);
        Directory.Delete(served, recursive: true);
    }

    [Test]
    public async Task A_slug_whose_characters_include_punctuation_of_another_script_is_still_a_page()
    {
        // Found on the website's own content: a title with an Arabic comma (synthetic letters here).
        const string encoded = "%d9%86%d8%8c-%d8%b5";
        var api = FakeApi.With(FakeApi.HealthyAnswers
            .Select(a => (a.Path.Replace("another-synthetic-article", encoded, StringComparison.Ordinal), a.Status,
                a.Json.Replace("another-synthetic-article", encoded, StringComparison.Ordinal)))
            .ToArray());

        var pages = await ContentSite.PagesAsync(api, CancellationToken.None);

        Assert.That(pages.Select(p => p.Path), Does.Contain("/articles/ن،-ص/"));
    }

    [TestCase("../escape")]
    [TestCase("a/b")]
    [TestCase("Upper")]
    [TestCase("%2e%2e")]
    [TestCase("a%2fb")]
    [TestCase("a%5cb")]
    [TestCase("a%00b")]
    [TestCase("a%20b")]
    [TestCase("%zz")]
    [TestCase("%ff%fe")]
    public async Task An_unsafe_slug_stops_the_build(string slug)
    {
        var json = FakeApi.ListJson.Replace("synthetic-published-article", slug, StringComparison.Ordinal);
        var api = FakeApi.HealthyBut(FakeApi.ListPath, HttpStatusCode.OK, json);

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
    public async Task The_not_found_page_is_written_as_404_html_in_the_site_s_frame()
    {
        var root = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;

        await SiteBuilder.WriteNotFoundAsync(root, [], CancellationToken.None);

        var html = await File.ReadAllTextAsync(Path.Combine(root, "404.html"));
        Assert.Multiple(() =>
        {
            Assert.That(html, Does.StartWith("<!doctype html>"));
            Assert.That(html, Does.Contain("This page could not be found."));
            Assert.That(html, Does.Contain("aria-label=\"Menu\""));
            Assert.That(html, Does.Contain("href=\"/site.css\""));
        });
        Directory.Delete(root, recursive: true);
    }

    [Test]
    public void Static_files_are_copied_with_their_folders()
    {
        var source = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;
        var root = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;
        Directory.CreateDirectory(Path.Combine(source, "fonts"));
        File.WriteAllText(Path.Combine(source, "site.css"), "css");
        File.WriteAllText(Path.Combine(source, "fonts", "a.woff2"), "font");

        SiteBuilder.CopyStaticFiles(source, root);

        Assert.Multiple(() =>
        {
            Assert.That(File.ReadAllText(Path.Combine(root, "site.css")), Is.EqualTo("css"));
            Assert.That(File.ReadAllText(Path.Combine(root, "fonts", "a.woff2")), Is.EqualTo("font"));
        });
        Directory.Delete(source, recursive: true);
        Directory.Delete(root, recursive: true);
    }

    [Test]
    public void A_missing_static_folder_stops_the_build()
    {
        var root = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;

        Assert.Throws<SiteBuildException>(() => SiteBuilder.CopyStaticFiles(Path.Combine(root, "absent"), root));
        Directory.Delete(root, recursive: true);
    }

    [Test]
    public void The_generator_ships_the_stylesheet_the_script_and_the_fonts()
    {
        var shipped = SiteBuilder.StaticFilesFolder;

        Assert.Multiple(() =>
        {
            Assert.That(File.Exists(Path.Combine(shipped, "site.css")), Is.True);
            Assert.That(File.Exists(Path.Combine(shipped, "site.js")), Is.True);
            Assert.That(File.Exists(Path.Combine(shipped, "tsr-logo.png")), Is.True);
            Assert.That(Directory.EnumerateFiles(Path.Combine(shipped, "fonts"), "*.woff2").Count(), Is.EqualTo(8));
            Assert.That(Directory.EnumerateFiles(Path.Combine(shipped, "fonts"), "OFL-*.txt").Count(), Is.EqualTo(5));
        });
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
