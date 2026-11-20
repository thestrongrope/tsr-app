using System.Text.RegularExpressions;
using NUnit.Framework;
using Tsr.Content.Site;
using Tsr.Shared.Site;

namespace Tsr.Host.Site.Tests;

/// <summary>
/// The fixed pages: content/pages/*.md of the repository, read at build time (domains/content/site/PageFiles.cs) and shown at /slug/.
/// Most tests use the real files, so a page the site cannot show faithfully stops them.
/// </summary>
public sealed partial class FixedPageTests
{
    private static async Task<IReadOnlyList<SitePage>> PagesAsync() =>
        await SiteBuilder.CollectAsync(SiteModules.All, FakeApi.Healthy(), CancellationToken.None);

    private static async Task<string> RenderAsync(string path)
    {
        var pages = await PagesAsync();
        return await SiteBuilder.RenderAsync(pages.Single(p => p.Path == path), []);
    }

    private static string RepositoryPages()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !Directory.Exists(Path.Combine(directory.FullName, "content", "pages")))
        {
            directory = directory.Parent;
        }

        return Path.Combine((directory ?? throw new InvalidOperationException("no content/pages above the test folder")).FullName, "content", "pages");
    }

    [GeneratedRegex(@"readOnlineUrl:\s*""(?<address>[^""]+)""")]
    private static partial Regex ReadOnlineUrl();

    [Test]
    public async Task A_fixed_page_shows_its_title_and_body_at_its_slug()
    {
        var html = await RenderAsync("/privacy-policy/");

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("<title>Privacy Policy</title>"));
            Assert.That(html, Does.Contain("content=\"How The Strong Rope website, member site and mobile app collect, use and share your information.\""));
            Assert.That(html, Does.Match(@"<h1 class=""[^""]*"">\s*Privacy Policy\s*</h1>"));
            Assert.That(html, Does.Contain("<strong>Last updated: "));
            Assert.That(html, Does.Contain("max-w-4xl"));
        });
    }

    [Test]
    public async Task The_accreditation_page_keeps_its_raw_html_its_style_and_the_three_anchors_the_home_page_links()
    {
        var html = await RenderAsync("/accreditation/");

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("<style>"));
            Assert.That(html, Does.Contain("id=\"maulana-zeeshan\""));
            Assert.That(html, Does.Contain("id=\"naba-cultural\""));
            Assert.That(html, Does.Contain("id=\"shaikh-kazim\""));
            Assert.That(html, Does.Not.Contain("&lt;div"));
            Assert.That(html, Does.Not.Contain("<pre>"));
            Assert.That(html, Does.Contain("max-w-7xl"));
        });
    }

    [Test]
    public async Task A_book_chapter_links_to_the_previous_and_next_chapters_and_the_table_of_contents()
    {
        var html = await RenderAsync("/excellence-of-holy-quran-chapter-two/");

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("href=\"/excellence-of-holy-quran-chapter-one/\""));
            Assert.That(html, Does.Contain("href=\"/excellence-of-holy-quran-chapter-three/\""));
            Assert.That(html, Does.Contain("href=\"/excellence-of-holy-quran-toc/\""));
            Assert.That(html, Does.Not.Contain("Reading Time"));
        });
    }

    [Test]
    public async Task Every_page_file_but_the_publications_page_is_a_page_and_every_image_it_shows_is_a_file_of_the_site()
    {
        var pages = await PagesAsync();
        var expected = Directory.EnumerateFiles(RepositoryPages(), "*.md").Select(Path.GetFileNameWithoutExtension).Where(name => name != "tsr-publications").ToList();
        foreach (var name in expected)
        {
            Assert.That(pages.Select(p => p.Path), Does.Contain($"/{name}/"));
        }

        var accreditation = pages.Single(p => p.Path == "/accreditation/");
        Assert.That(accreditation.Files, Does.Contain("/uploads/TSR-Naba-English.jpeg"));
        Assert.DoesNotThrow(() => SiteBuilder.RequireFiles(pages, SiteBuilder.StaticFilesFolder));
    }

    [Test]
    public async Task Every_read_online_address_of_the_publications_page_has_a_page()
    {
        var text = File.ReadAllText(Path.Combine(RepositoryPages(), "tsr-publications.md"));
        var addresses = ReadOnlineUrl().Matches(text).Select(m => m.Groups["address"].Value)
            .Where(a => a.StartsWith('/') && !a.StartsWith("/duas/", StringComparison.Ordinal) && !a.StartsWith("/downloads/", StringComparison.Ordinal))
            .ToList();
        var paths = (await PagesAsync()).Select(p => p.Path).ToList();

        Assert.That(addresses, Is.Not.Empty);
        foreach (var address in addresses)
        {
            Assert.That(paths, Does.Contain(address.TrimEnd('/') + "/"), address);
        }
    }

    [Test]
    public void A_page_and_an_article_with_one_slug_stop_the_build()
    {
        var folder = Directory.CreateTempSubdirectory("tsr-pages-");
        try
        {
            File.WriteAllText(Path.Combine(folder.FullName, "same-slug.md"), "---\ntitle: \"Same\"\n---\nInvented.\n");

            var error = Assert.Throws<SiteBuildException>(() => PageFiles.Pages(folder.FullName, ["same-slug"]));

            Assert.That(error!.Message, Does.Contain("same-slug"));
        }
        finally
        {
            folder.Delete(recursive: true);
        }
    }

    [Test]
    public void A_missing_pages_folder_stops_the_build()
    {
        var error = Assert.Throws<SiteBuildException>(() => PageFiles.Pages(Path.Combine(AppContext.BaseDirectory, "no-such-folder"), []));

        Assert.That(error!.Message, Does.Contain("no-such-folder"));
    }
}
