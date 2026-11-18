using System.Net;
using System.Text.RegularExpressions;
using Tsr.Content.Site;
using Tsr.Shared.Site;
using NUnit.Framework;

namespace Tsr.Host.Site.Tests;

/// <summary>
/// Issue 68, SITE-R50 to R54: the home page. What it shows and in which order is decided when the site is built and tested
/// here with canned answers. Opening and closing a category card is the script's (hosts/site/wwwroot/site.js): these tests
/// check the markup it acts on.
/// </summary>
public sealed partial class HomePageTests
{
    private const string Address = "/";

    private static readonly string[] Photos =
        ["/uploads/naba-accreditation.png", "/uploads/maulana-zeeshan-haider-zaidi.jpg", "/uploads/kazim-sahab.png"];

    private static readonly string[] AccreditationLinks =
        ["/accreditation#naba-cultural", "/accreditation#maulana-zeeshan", "/accreditation#shaikh-kazim"];

    private static readonly string[] FiveNewest = ["Newest & first", "Second", "Third", "Fourth", "Fifth"];

    private static readonly string[] FiveSlugs = ["newest-first", "second", "third", "fourth", "fifth"];

    private static readonly string[] ParentSlugs = ["foundations", "history"];

    private static readonly string[] ParentCounts = ["3", "0"];

    /// <summary>Six articles, newest first as the route sends them; the sixth is not shown. The last two have no date or no category.</summary>
    private const string ListJson = """
        {"success":true,"data":[
        {"slug":"newest-first","title":"Newest &amp; first","categories":["core-terms"],"tags":[],"publishedDate":"2026-11-10T08:00:00Z"},
        {"slug":"second","title":"Second","categories":["foundations"],"tags":[],"publishedDate":"2026-11-09"},
        {"slug":"third","title":"Third","categories":[],"tags":[],"publishedDate":"2026-11-08T00:00:00+00:00"},
        {"slug":"fourth","title":"Fourth","categories":["unknown-slug"],"tags":[]},
        {"slug":"fifth","title":"Fifth","categories":["early-history","foundations"],"tags":[],"publishedDate":"2026-11-06T23:59:59"},
        {"slug":"sixth","title":"Sixth","categories":["foundations"],"tags":[],"publishedDate":"2026-11-05"}],
        "meta":{"version":"1.0"},"pagination":{"total":6,"limit":100,"offset":0,"hasMore":false}}
        """;

    /// <summary>The API's own counts are wrong on purpose: the page counts the articles, as the present site does.</summary>
    private const string CategoriesJson = """
        {"success":true,"data":[
        {"slug":"foundations","title":"Foundations &amp; Basics","description":"The basics of the faith.","order":1,"articleCount":99},
        {"slug":"core-terms","title":"Core Terms","order":2,"parent":"foundations","articleCount":0},
        {"slug":"empty-child","title":"Empty Child","order":3,"parent":"foundations","articleCount":9},
        {"slug":"history","title":"History","order":4,"articleCount":0},
        {"slug":"early-history","title":"Early History","order":5,"parent":"history","articleCount":0}],
        "meta":{"version":"1.0"}}
        """;

    private const string VideosJson = """
        {"success":true,"data":{"videos":[
        {"id":"AAAAAAAAAAA","videoId":"AAAAAAAAAAA","title":"First <video> & more","youtubeLink":"https://www.youtube.com/watch?v=AAAAAAAAAAA",
         "publishedDate":"2026-10-05T14:00:07+00:00","publishedDateFormatted":"Oct 5, 2026","views":1234567,"intro":"x","description":"About the first video.",
         "thumbnail":{"url":"https://i.ytimg.com/vi/AAAAAAAAAAA/hqdefault.jpg","width":480,"height":360}},
        {"id":"BBBBBBBBBBB","videoId":"BBBBBBBBBBB","title":"Second video","youtubeLink":"https://www.youtube.com/watch?v=BBBBBBBBBBB",
         "publishedDate":"x","publishedDateFormatted":"Invalid Date","views":null,"intro":"","description":"",
         "thumbnail":{"url":"","width":480,"height":360}}],
        "meta":{"total":2,"channelId":"UC","channelName":"c","channelUrl":"https://www.youtube.com/@x","lastUpdated":"2026-11-18T00:00:00.000Z","cacheHit":false}},
        "meta":{"version":"1.0"},"pagination":{"total":2,"limit":6,"offset":0,"hasMore":false}}
        """;

    /// <summary>One article answer for a slug of the canned list: the page reads each article before it writes it.</summary>
    private static (string, HttpStatusCode, string) ArticleAnswer(string slug) =>
        (FakeApi.ListPath + "/" + slug, HttpStatusCode.OK,
            "{\"success\":true,\"data\":{\"slug\":\"" + slug + "\",\"title\":\"T\",\"categories\":[],\"tags\":[],\"readingTime\":1,\"content\":\"<p>x</p>\",\"relatedArticles\":[]},\"meta\":{}}");

    private static readonly string[] AllSlugs = [.. FiveSlugs, "sixth"];

    private static SiteApi Api(string videos, out FakeApi fake, string list = ListJson) => FakeApi.With(
        out fake,
        FakeApi.HealthyAnswers
            .Select(a => a.Path switch
            {
                FakeApi.ListPath => (a.Path, HttpStatusCode.OK, list),
                FakeApi.CategoriesPath => (a.Path, HttpStatusCode.OK, CategoriesJson),
                FakeApi.VideosPath => (a.Path, HttpStatusCode.OK, videos),
                _ => a,
            })
            .Concat(AllSlugs.Select(ArticleAnswer))
            .ToArray());

    private static async Task<string> RenderAsync(string videos)
    {
        var api = Api(videos, out _);
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None);
        var menu = await ContentSite.MenuAsync(api, CancellationToken.None);
        return await SiteBuilder.RenderAsync(pages.Single(p => p.Path == Address), menu);
    }

    private static string Section(string html, string from, string? to)
    {
        var start = html.IndexOf(from, StringComparison.Ordinal);
        Assert.That(start, Is.GreaterThanOrEqualTo(0), from);
        var end = to is null ? html.Length : html.IndexOf(to, start, StringComparison.Ordinal);
        return html[start..end];
    }

    [GeneratedRegex(@"<a href=""/articles/(?<slug>[^/""]+)/""[^>]*>(?<card>.*?)</a>", RegexOptions.Singleline)]
    private static partial Regex ArticleCard();

    [GeneratedRegex(@"<h3[^>]*>\s*(?<title>[^<]*?)\s*</h3>")]
    private static partial Regex Heading3();

    [GeneratedRegex(@"<a href=""/articles/\?category=(?<slug>[^""]+)""[^>]*>\s*<div[^>]*>\s*<h3[^>]*>\s*(?<title>[^<]*?)\s*</h3>\s*<span[^>]*>\s*(?<count>\d+)\s*</span>")]
    private static partial Regex ParentLink();

    [Test]
    public async Task TC_SITE_R50_01_The_page_has_the_present_site_s_sections_in_its_order()
    {
        var html = await RenderAsync(VideosJson);
        var markers = new[]
        {
            "hold firmly to the rope of Allah", "Accredited by", "Latest Articles", "Search Articles", "data-category-card=\"foundations\"",
            "Browse all lectures", "Latest Videos",
        };

        var places = markers.Select(marker => html.IndexOf(marker, StringComparison.Ordinal)).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(places, Has.All.GreaterThan(0));
            Assert.That(places, Is.Ordered);
            Assert.That(html, Does.Contain("<title>The Strong Rope</title>"));
            Assert.That(html, Does.Contain("content=\"The Path of the Ahle Bait (a.s.)\""));
            Assert.That(Regex.Count(html, "<main"), Is.EqualTo(1));
        });
    }

    [Test]
    public async Task TC_SITE_R50_02_The_verse_banner_has_the_arabic_text_right_to_left_then_the_translation_and_the_reference()
    {
        var html = await RenderAsync(FakeApi.NoVideosJson);

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Match(@"<p class=""[^""]*"" dir=""rtl"">\s*وَاعْتَصِمُوا بِحَبْلِ اللهِ جَمِيعًا وَلَا تَفَرَّقُوا\s*</p>"));
            Assert.That(html, Does.Contain("&ldquo;And hold firmly to the rope of Allah all together and do not be divided&rdquo;"));
            Assert.That(html, Does.Contain("Surah Aal-e-Imran 3:103"));
            // lang="ar" on the banner would turn every block around it (the stylesheet's div:has([lang="ar"]) rule).
            Assert.That(html, Does.Not.Contain("lang=\"ar\""));
        });
    }

    [Test]
    public async Task TC_SITE_R50_03_The_three_endorsement_cards_link_to_the_accreditation_page_and_show_their_photos()
    {
        var html = await RenderAsync(FakeApi.NoVideosJson);
        var cards = Section(html, "<main", "Latest Articles");

        Assert.Multiple(() =>
        {
            foreach (var link in AccreditationLinks)
            {
                Assert.That(html, Does.Contain("<a href=\"" + link + "\""));
            }

            foreach (var photo in Photos)
            {
                Assert.That(cards, Does.Contain("src=\"" + photo + "\""));
            }

            Assert.That(cards, Does.Contain("alt=\"Naba Cultural Organization\""));
            Assert.That(cards, Does.Contain("alt=\"Maulana Zeeshan Haider Zaidi\""));
            Assert.That(cards, Does.Contain("alt=\"Shaikh Mohammad Kazim\""));
            Assert.That(cards, Does.Contain("Naba Cultural Organization, I.R. Iran"));
            Assert.That(cards, Does.Contain("Vakil of Grand Ayatullah Shaikh Basheer Najafi (d.z.a.)"));
            Assert.That(cards, Does.Contain("Principal, Hawzah Ilmiyyah Isna Ashariyyah, Kargil"));
            Assert.That(Regex.Count(cards, "Endorsed by"), Is.EqualTo(2));
        });
    }

    [Test]
    public async Task TC_SITE_R50_04_The_page_names_the_photos_as_files_it_needs_and_the_generator_ships_them()
    {
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, Api(FakeApi.NoVideosJson, out _), CancellationToken.None);

        Assert.Multiple(() =>
        {
            Assert.That(pages.Single(p => p.Path == Address).Files, Is.EqualTo(Photos));
            Assert.DoesNotThrow(() => SiteBuilder.RequireFiles(pages, SiteBuilder.StaticFilesFolder));
            foreach (var photo in Photos)
            {
                Assert.That(new FileInfo(Path.Combine(SiteBuilder.StaticFilesFolder, photo.TrimStart('/'))).Length, Is.GreaterThan(1000), photo);
            }
        });
    }

    [Test]
    public async Task TC_SITE_R50_05_Latest_articles_are_the_five_newest_each_with_its_first_category_and_its_date()
    {
        var html = await RenderAsync(FakeApi.NoVideosJson);
        var section = Section(html, "Latest Articles", "Search Articles");
        var cards = ArticleCard().Matches(section).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(cards.Select(c => c.Groups["slug"].Value), Is.EqualTo(FiveSlugs));
            Assert.That(cards.Select(c => Heading3().Match(c.Groups["card"].Value).Groups["title"].Value), Is.EqualTo(FiveNewest.Select(t => t.Replace("&", "&amp;", StringComparison.Ordinal))));
            Assert.That(section, Does.Not.Contain("sixth"));
            // The first category's title, only when the category is known.
            Assert.That(cards[0].Groups["card"].Value, Does.Contain(">Core Terms<").And.Contain("Nov 10, 2026"));
            Assert.That(cards[1].Groups["card"].Value, Does.Contain(">Foundations &amp; Basics<").And.Contain("Nov 9, 2026"));
            Assert.That(cards[2].Groups["card"].Value, Does.Not.Contain("rounded-full").And.Contain("Nov 8, 2026"));
            Assert.That(cards[3].Groups["card"].Value, Does.Not.Contain("rounded-full").And.Not.Contain("2026"));
            Assert.That(cards[4].Groups["card"].Value, Does.Contain(">Early History<").And.Contain("Nov 6, 2026"));
            Assert.That(section, Does.Contain("<a href=\"/articles/\""));
            Assert.That(section, Does.Contain("View all"));
            Assert.That(section, Does.Not.Contain("&amp;amp;"));
        });
    }

    [Test]
    public async Task TC_SITE_R50_06_The_parent_category_cards_show_the_articles_counted_by_the_page_and_link_to_the_filtered_list()
    {
        var html = await RenderAsync(FakeApi.NoVideosJson);
        var section = Section(html, "data-category-card=\"foundations\"", "Browse all lectures");
        var parents = ParentLink().Matches(Section(html, "<div class=\"grid grid-cols-1 md:grid-cols-2 gap-4\">", "Browse all lectures")).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(parents.Select(p => p.Groups["slug"].Value), Is.EqualTo(ParentSlugs));
            Assert.That(parents.Select(p => p.Groups["count"].Value), Is.EqualTo(ParentCounts));
            Assert.That(parents[0].Groups["title"].Value, Is.EqualTo("Foundations &amp; Basics"));
            Assert.That(section, Does.Contain("The basics of the faith."));
            Assert.That(section, Does.Not.Contain("Empty Child"));
        });
    }

    [Test]
    public async Task TC_SITE_R50_07_The_lecture_search_form_goes_to_lectures_and_a_link_to_the_lectures_follows()
    {
        var html = await RenderAsync(FakeApi.NoVideosJson);

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Match(@"<form action=""/lectures"" method=""get"">"));
            Assert.That(html, Does.Match(@"<input id=""lecture-search"" type=""text"" name=""q"" "));
            Assert.That(html, Does.Contain("Browse all lectures"));
            Assert.That(html, Does.Contain("<a href=\"/lectures\""));
        });
    }

    [Test]
    public async Task TC_SITE_R51_01_Each_card_with_subcategories_lists_them_with_their_counts_open_for_a_reader_without_script()
    {
        var html = await RenderAsync(FakeApi.NoVideosJson);
        var foundations = Section(html, "data-category-card=\"foundations\"", "data-category-card=\"history\"");
        var history = Section(html, "data-category-card=\"history\"", "Browse all lectures");

        Assert.Multiple(() =>
        {
            // Only a child with an article, with its count, behind a link to the filtered list.
            Assert.That(foundations, Does.Match(@"<a href=""/articles/\?category=core-terms""[^>]*>\s*<span[^>]*>\s*&#x21B3; Core Terms\s*</span>\s*<span[^>]*>\s*1\s*</span>"));
            Assert.That(foundations, Does.Not.Contain("empty-child"));
            Assert.That(history, Does.Contain("href=\"/articles/?category=early-history\""));
            // Written open, with the toggle button hidden: with scripts off every link is shown and nothing is dead.
            Assert.That(foundations, Does.Match(@"<button type=""button"" data-category-card-toggle[^>]* hidden[ >]"));
            Assert.That(foundations, Does.Match(@"<div data-category-card-list class=""[^""]*"">"));
            Assert.That(foundations, Does.Not.Match(@"data-category-card-list[^>]* hidden"));
        });
    }

    [Test]
    public async Task TC_SITE_R51_02_A_card_without_a_child_that_has_an_article_has_no_toggle_and_no_list()
    {
        var json = ListJson.Replace("\"early-history\",", string.Empty, StringComparison.Ordinal);
        var api = Api(FakeApi.NoVideosJson, out _, json);
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None);
        var html = await SiteBuilder.RenderAsync(pages.Single(p => p.Path == Address), []);

        var history = Section(html, "data-category-card=\"history\"", "Browse all lectures");

        Assert.Multiple(() =>
        {
            Assert.That(history, Does.Not.Contain("data-category-card-toggle"));
            Assert.That(history, Does.Not.Contain("data-category-card-list"));
        });
    }

    [Test]
    public async Task TC_SITE_R52_01_The_search_box_is_a_plain_get_form_to_the_article_list_with_a_q_field_and_no_script()
    {
        var html = await RenderAsync(FakeApi.NoVideosJson);
        var form = Section(html, "<form action=\"/articles/\"", "</form>");

        Assert.Multiple(() =>
        {
            Assert.That(form, Does.Contain("method=\"get\""));
            Assert.That(form, Does.Match(@"<input [^>]*name=""q"""));
            Assert.That(form, Does.Contain("placeholder=\"Search articles...\""));
            Assert.That(form, Does.Not.Match(@"\son\w+="));
            Assert.That(form, Does.Not.Contain("<script"));
            Assert.That(Regex.Count(html, "<script"), Is.EqualTo(2));
        });
    }

    [Test]
    public async Task TC_SITE_R53_01_With_no_video_the_page_is_built_without_the_latest_videos_section()
    {
        var html = await RenderAsync(FakeApi.NoVideosJson);

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Not.Contain("Latest Videos"));
            Assert.That(html, Does.Not.Contain("View Channel"));
            Assert.That(html, Does.Not.Contain("youtube.com"));
            Assert.That(html, Does.Contain("Browse all lectures"));
        });
    }

    [Test]
    public async Task TC_SITE_R53_02_Six_videos_are_asked_for_and_each_is_a_link_with_its_thumbnail_title_date_and_views()
    {
        var api = Api(VideosJson, out var fake);
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None);
        var html = await SiteBuilder.RenderAsync(pages.Single(p => p.Path == Address), []);
        var section = Section(html, "Latest Videos", null);

        Assert.Multiple(() =>
        {
            Assert.That(fake.Asked, Does.Contain(FakeApi.VideosPath + "?limit=6"));
            Assert.That(section, Does.Contain("href=\"https://www.youtube.com/@TheStrongRope\""));
            Assert.That(section, Does.Contain("href=\"https://www.youtube.com/watch?v=AAAAAAAAAAA\""));
            Assert.That(section, Does.Contain("src=\"https://i.ytimg.com/vi/AAAAAAAAAAA/hqdefault.jpg\""));
            Assert.That(section, Does.Contain("First &lt;video&gt; &amp; more"));
            Assert.That(section, Does.Contain("About the first video."));
            Assert.That(section, Does.Contain("Oct 5, 2026"));
            Assert.That(section, Does.Contain("1,234,567 views"));
            // The second video has no thumbnail, date or view count: none is written, and the placeholder icon is.
            Assert.That(section, Does.Contain("href=\"https://www.youtube.com/watch?v=BBBBBBBBBBB\""));
            Assert.That(section, Does.Not.Contain("Invalid Date"));
            Assert.That(Regex.Count(section, " views"), Is.EqualTo(1));
            Assert.That(Regex.Count(section, "<img "), Is.EqualTo(1));
            Assert.That(Regex.Count(section, "text-red-500"), Is.EqualTo(1));
        });
    }

    [TestCase("\"videoId\":\"AAAAAAAAAAA\"", "\"videoId\":\"A\\\"><script>\"")]
    [TestCase("\"videoId\":\"AAAAAAAAAAA\"", "\"videoId\":\"\"")]
    [TestCase("\"url\":\"https://i.ytimg.com/vi/AAAAAAAAAAA/hqdefault.jpg\"", "\"url\":\"javascript:alert(1)\"")]
    [TestCase("\"title\":\"Second video\"", "\"title\":null")]
    public async Task TC_SITE_R53_03_A_video_that_cannot_be_linked_safely_stops_the_build(string from, string to)
    {
        var api = Api(VideosJson.Replace(from, to, StringComparison.Ordinal), out _);

        await Assert.ThrowsAsync<SiteBuildException>(() => SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None));
    }

    [Test]
    public async Task TC_SITE_R53_04_A_failed_video_answer_stops_the_build()
    {
        var api = FakeApi.HealthyBut(FakeApi.VideosPath, HttpStatusCode.InternalServerError, """{"success":false}""");

        await Assert.ThrowsAsync<SiteBuildException>(() => SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None));
    }

    [Test]
    public async Task TC_SITE_R54_01_The_home_page_is_content_s_one_page_at_the_root_and_the_sample_is_gone()
    {
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, FakeApi.Healthy(), CancellationToken.None);

        var home = pages.Where(p => p.Path == Address).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(home, Has.Count.EqualTo(1));
            Assert.That(home[0].Component.Assembly, Is.SameAs(typeof(ContentSite).Assembly));
            Assert.That(typeof(SiteBuilder).Assembly.GetType("Tsr.Host.Site.HomePage"), Is.Null);
        });
    }

    [Test]
    public async Task TC_SITE_R54_02_The_home_page_s_data_comes_only_from_the_public_routes()
    {
        var api = Api(VideosJson, out var fake);
        var content = SiteModules.All.Single(m => m.Name == "content");

        await SiteBuilder.CollectAsync([content], api, CancellationToken.None);

        var asked = fake.Asked.Select(a => a.Split('?')[0]).Distinct().ToList();
        Assert.Multiple(() =>
        {
            Assert.That(asked, Has.All.StartWith("/api/v1/"));
            Assert.That(asked, Does.Contain(FakeApi.VideosPath));
            Assert.That(asked, Does.Contain(FakeApi.CategoriesPath));
        });
    }
}
