using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using Tsr.Content.Site;
using Tsr.Shared.Site;
using NUnit.Framework;

namespace Tsr.Host.Site.Tests;

/// <summary>
/// Issue 66, SITE-R30 to R36: the publications page. The tab order, the grouping and the sort are decided at build time and
/// tested here. Choosing a tab, searching and opening a summary are the script's (hosts/site/wwwroot/site.js): these tests
/// check the markup the script acts on, and hosts/site/tests/js checks the script's two functions without a browser.
/// </summary>
public sealed partial class PublicationsTests
{
    private const string Address = "/tsr-publications/";

    private static readonly string[] Languages = ["English", "Bengali", "Hindi", "Other", "Urdu"];

    private static readonly string[] EnglishSorted = ["Apple", "mango", "zebra"];

    private static readonly string[] OtherSorted = ["Blank language", "No language"];

    private static readonly string[] UrduSorted = ["alpha", "Zeta"];

    private static readonly string[] EnglishCards = ["Alpha <guide>", "beta notes", "Zeta guide"];

    private static readonly string[] FirstTabOnly = ["true", "false", "false", "false", "false"];

    private static readonly string[] TabCounts = ["3 publications", "1 publication", "1 publication", "1 publication", "1 publication"];

    private const string UrduTitle = "قرآن کی مصنوعی کتاب";

    /// <summary>Every card of the canned answer by its title, in page order.</summary>
    private static readonly string[] AllCards =
    [
        "Alpha <guide>", "beta notes", "Zeta guide", "A synthetic Bengali book", "A synthetic web book", "A book of no language", UrduTitle,
    ];

    /// <summary>One language's panel, up to the next panel or the end of the list of panels.</summary>
    [GeneratedRegex(@"<div class=""space-y-4"" role=""tabpanel"" data-publications-panel=""(?<language>[^""]*)""[^>]*>(?<body>.*?)(?=<div class=""space-y-4"" role=""tabpanel""|</main>|\z)", RegexOptions.Singleline)]
    private static partial Regex Panel();

    /// <summary>One publication's card, with the text the search box reads.</summary>
    [GeneratedRegex(@"<article data-search-text=""(?<text>[^""]*)"" class=""[^""]*"">(?<body>.*?)</article>", RegexOptions.Singleline)]
    private static partial Regex Card();

    [GeneratedRegex(@"<button type=""button"" role=""tab"" aria-selected=""(?<selected>true|false)"" data-publications-tab=""(?<language>[^""]*)"" class=""(?<class>[^""]*)"">\s*<span>(?<name>[^<]*)</span>\s*<span class=""(?<countClass>[^""]*)"">(?<count>[^<]*)</span>")]
    private static partial Regex Tab();

    [GeneratedRegex(@"<h4(?<attributes>[^>]*)>(?<title>[^<]*)</h4>")]
    private static partial Regex Title();

    /// <summary>An element the page hides until the script shows it.</summary>
    [GeneratedRegex(@"<[a-z0-9]+(?:\s+[\w-]+(?:=""[^""]*"")?)*?\s+hidden(?:="""")?(?:\s+[\w-]+(?:=""[^""]*"")?)*\s*>")]
    private static partial Regex Hidden();

    private static async Task<string> RenderAsync(SiteApi? api = null)
    {
        api ??= FakeApi.Healthy();
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None);
        var menu = await ContentSite.MenuAsync(api, CancellationToken.None);
        return await SiteBuilder.RenderAsync(pages.Single(p => p.Path == Address), menu);
    }

    private static SiteApi WithPublications(string data) => FakeApi.HealthyBut(FakeApi.PublicationsPath, HttpStatusCode.OK,
        """{"success":true,"data":[""" + data + """],"meta":{"version":"1.0"},"pagination":{"total":0,"limit":0,"offset":0,"hasMore":false}}""");

    private static Publication Of(string title, string? language) =>
        new(title, null, "PDF", null, null, language, "/downloads/synthetic/x.pdf", null, DownloadOnly: false);

    /// <summary>The renderer writes every character outside ASCII as a numbered entity; a browser reads either alike.</summary>
    private static string Text(string html) => WebUtility.HtmlDecode(html);

    private static string CardOf(string html, string title) =>
        Card().Matches(html).Single(card => Text(card.Groups["text"].Value) == title).Groups["body"].Value;

    [Test]
    public void TC_SITE_R30_01_Publications_are_grouped_by_language_English_first_then_by_name_each_group_sorted_by_title()
    {
        Publication[] publications =
        [
            Of("Zeta", "Urdu"), Of("zebra", "English"), Of("Apple", "English"), Of("mango", " English "), Of("Kiwi", "Hindi"),
            Of("No language", null), Of("Blank language", "  "), Of("Bengali book", "Bengali"), Of("alpha", "Urdu"),
        ];

        var groups = Publications.Groups(publications);

        Assert.Multiple(() =>
        {
            Assert.That(groups.Select(g => g.Language), Is.EqualTo(Languages));
            // By title as a reader sorts, not by code point: a lower-case letter does not come after every capital.
            Assert.That(groups[0].Items.Select(p => p.Title), Is.EqualTo(EnglishSorted));
            Assert.That(groups[3].Items.Select(p => p.Title), Is.EqualTo(OtherSorted));
            Assert.That(groups[4].Items.Select(p => p.Title), Is.EqualTo(UrduSorted));
        });
    }

    [Test]
    public async Task TC_SITE_R30_02_The_page_lists_every_publication_the_route_sends_under_its_language_in_tab_order()
    {
        var html = await RenderAsync();
        var panels = Panel().Matches(html);

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("<title>TSR Publications - The Strong Rope</title>"));
            Assert.That(html, Does.Contain("content=\"Download the latest publications from The Strong Rope, including Quran resources and study materials in multiple languages.\""));
            Assert.That(html, Does.Contain(">7 publications across 5 languages</p>"));
            Assert.That(panels.Select(p => p.Groups["language"].Value), Is.EqualTo(Languages));
            Assert.That(Card().Matches(panels[0].Groups["body"].Value).Select(c => Text(c.Groups["text"].Value)),
                Is.EqualTo(EnglishCards));
            Assert.That(Card().Count(html), Is.EqualTo(7));
            Assert.That(panels[0].Groups["body"].Value, Does.Contain(">3 publications available</p>"));
            Assert.That(panels[1].Groups["body"].Value, Does.Contain(">1 publication available</p>"));
            // The frame links to the page with the closing slash, as to every page the site has.
            Assert.That(html, Does.Contain("href=\"/tsr-publications/\""));
            Assert.That(html, Does.Not.Contain("href=\"/tsr-publications\""));
        });
    }

    [Test]
    public async Task TC_SITE_R30_03_No_publication_gives_the_present_site_s_empty_text_and_one_gives_the_singular()
    {
        var none = await RenderAsync(WithPublications(string.Empty));
        var one = await RenderAsync(WithPublications("""{"title":"Only","file":"/downloads/synthetic/only.pdf","downloadOnly":false}"""));

        Assert.Multiple(() =>
        {
            Assert.That(none, Does.Contain(">0 publications across 0 languages</p>"));
            Assert.That(none, Does.Contain(">No publications available at the moment.</div>"));
            Assert.That(none, Does.Not.Contain("role=\"tablist\""));
            Assert.That(one, Does.Contain(">1 publication across 1 language</p>"));
        });
    }

    [TestCase("""{"summary":"no title","file":"/downloads/synthetic/x.pdf","downloadOnly":false}""", "without a title")]
    [TestCase("""{"title":"No address","downloadOnly":false}""", "neither a file nor a read-online address")]
    [TestCase("""{"title":"Script","file":"javascript:alert(1)","downloadOnly":false}""", "not a site or web address")]
    [TestCase("""{"title":"Other host","readOnlineUrl":"//other.invalid/x","downloadOnly":false}""", "not a site or web address")]
    public async Task TC_SITE_R30_04_An_answer_the_page_cannot_show_stops_the_build(string publication, string problem)
    {
        var failure = await Assert.ThrowsAsync<SiteBuildException>(() => RenderAsync(WithPublications(publication)));

        Assert.That(failure!.Message, Does.Contain(FakeApi.PublicationsPath).And.Contain(problem));
    }

    [TestCase("/\\host/x.pdf")]
    [TestCase("/\t/host/x.pdf")]
    [TestCase("/\n/host/x.pdf")]
    [TestCase("/ x.pdf")]
    [TestCase("/")]
    [TestCase("//host/x.pdf")]
    [TestCase("javascript:alert(1)")]
    [TestCase("http://files.example.invalid/x.pdf")]
    [TestCase("https:///x.pdf")]
    [TestCase("https://host/\\x.pdf")]
    [TestCase(" https://files.example.invalid/x.pdf")]
    [TestCase("x.pdf")]
    public async Task TC_SITE_R30_06_An_address_that_is_not_an_https_address_or_a_site_path_stops_the_build_and_names_the_publication_and_field(string address)
    {
        foreach (var field in new[] { "file", "readOnlineUrl" })
        {
            var publication = "{\"title\":\"Named book\",\"" + field + "\":" + JsonSerializer.Serialize(address) + ",\"downloadOnly\":false}";

            var failure = await Assert.ThrowsAsync<SiteBuildException>(() => RenderAsync(WithPublications(publication)));

            Assert.That(failure!.Message, Does.Contain("Named book").And.Contain("'" + field + "'").And.Contain(FakeApi.PublicationsPath));
        }
    }

    [TestCase("/downloads/synthetic/x.pdf")]
    [TestCase("/a-synthetic-web-book")]
    [TestCase("/x/y?z=1#top")]
    [TestCase("https://files.example.invalid/x.pdf")]
    public async Task TC_SITE_R30_07_An_https_address_or_a_site_path_is_linked_as_sent(string address)
    {
        var publication = "{\"title\":\"Named book\",\"file\":" + JsonSerializer.Serialize(address) + ",\"downloadOnly\":true}";

        var html = await RenderAsync(WithPublications(publication));

        Assert.That(html, Does.Contain("href=\"" + WebUtility.HtmlEncode(address) + "\""));
    }

    [Test]
    public async Task TC_SITE_R30_05_A_failed_answer_stops_the_build()
    {
        var failed = FakeApi.HealthyBut(FakeApi.PublicationsPath, HttpStatusCode.InternalServerError, """{"detail":"no"}""");

        await Assert.ThrowsAsync<SiteBuildException>(() => RenderAsync(failed));
    }

    [Test]
    public async Task TC_SITE_R31_01_A_publication_shows_its_title_summary_type_size_and_updated_date()
    {
        var html = await RenderAsync();
        var zeta = CardOf(html, "Zeta guide");
        var bengali = CardOf(html, "A synthetic Bengali book");
        var web = CardOf(html, "A synthetic web book");

        Assert.Multiple(() =>
        {
            Assert.That(zeta, Does.Match(@"<h4 class=""text-lg font-semibold text-gray-900 dark:text-gray-100 ?"">Zeta guide</h4>"));
            Assert.That(zeta, Does.Contain(">A synthetic summary of the zeta guide.</p>"));
            Assert.That(zeta, Does.Match(@"<span class=""[^""]*whitespace-nowrap"">PDF</span>"));
            Assert.That(zeta, Does.Match(@"File size\s*</dt>\s*<dd class=""text-right"">1 MB</dd>"));
            Assert.That(zeta, Does.Match(@"Updated\s*</dt>\s*<dd class=""text-right"">Jun 26, 2025</dd>"));
            // A value the route leaves out is a dash, as on the present site; a text is escaped.
            Assert.That(bengali, Does.Match(@"Updated\s*</dt>\s*<dd class=""text-right"">&#x2014;</dd>"));
            Assert.That(bengali, Does.Not.Contain("data-summary"));
            Assert.That(web, Does.Not.Contain("File size"));
            Assert.That(html, Does.Contain(">Alpha &lt;guide&gt;</h4>"));
            Assert.That(html, Does.Contain(">Both a file &amp; a page.</p>"));
        });
    }

    [Test]
    public async Task TC_SITE_R31_02_The_buttons_are_the_present_site_s_and_keep_the_addresses_the_route_sends()
    {
        var html = await RenderAsync();
        var zeta = CardOf(html, "Zeta guide");
        var urdu = CardOf(html, UrduTitle);
        var web = CardOf(html, "A synthetic web book");
        var alpha = CardOf(html, "Alpha <guide>");
        static string Read(string address) => @"<a href=""" + address + @""" target=""_blank"" rel=""noopener noreferrer"" class=""[^""]*"">\s*<svg.*?</svg>\s*Read\s*</a>";
        static string Download(string address) => @"<a href=""" + address + @""" download(="""")? class=""[^""]*"" title=""Download PDF"">\s*<svg.*?</svg>\s*</a>";
        static string DownloadOnly(string address) => @"<a href=""" + address + @""" download(="""")? class=""[^""]*"">\s*<svg.*?</svg>\s*Download PDF\s*</a>";
        static string ReadOnline(string address) => @"<a href=""" + address + @""" class=""[^""]*bg-amber-600[^""]*"">\s*<svg.*?</svg>\s*Read Online\s*</a>";

        Assert.Multiple(() =>
        {
            Assert.That(zeta, Does.Match(Read("/downloads/synthetic/zeta-guide.pdf")));
            Assert.That(zeta, Does.Match(Download("/downloads/synthetic/zeta-guide.pdf")));
            Assert.That(zeta, Does.Not.Contain("Read Online"));
            // A download-only entry: no Read.
            Assert.That(urdu, Does.Match(DownloadOnly("/downloads/synthetic/urdu-book.pdf")));
            Assert.That(urdu, Does.Not.Contain("target=\"_blank\""));
            Assert.That(Regex.Count(urdu, "<a "), Is.EqualTo(1));
            // Read Online only where the entry has a page, at the address as sent: no closing slash is added.
            Assert.That(web, Does.Match(ReadOnline("/a-synthetic-web-book")));
            Assert.That(Regex.Count(web, "<a "), Is.EqualTo(1));
            Assert.That(alpha, Does.Match(ReadOnline("/alpha-guide-toc")));
            Assert.That(Regex.Count(alpha, "<a "), Is.EqualTo(3));
            Assert.That(CardOf(html, "A synthetic Bengali book"), Does.Contain("href=\"https://files.example.invalid/bengali-book.pdf\""));
        });
    }

    [Test]
    public async Task TC_SITE_R32_01_Each_language_has_a_tab_and_a_panel_the_script_can_pair_and_the_first_tab_is_chosen()
    {
        var html = await RenderAsync();
        var tabs = Tab().Matches(html);
        var list = Regex.Match(html, @"<div class=""flex flex-wrap gap-2"" role=""tablist"" aria-label=""Filter publications by language""(?<attributes>[^>]*)>").Groups["attributes"].Value;

        Assert.Multiple(() =>
        {
            Assert.That(tabs.Select(t => t.Groups["language"].Value), Is.EqualTo(Languages));
            Assert.That(tabs.Select(t => t.Groups["name"].Value), Is.EqualTo(Languages));
            Assert.That(tabs.Select(t => t.Groups["language"].Value), Is.EqualTo(Panel().Matches(html).Select(p => p.Groups["language"].Value)));
            Assert.That(tabs.Select(t => t.Groups["selected"].Value), Is.EqualTo(FirstTabOnly));
            Assert.That(tabs.Select(t => t.Groups["count"].Value), Is.EqualTo(TabCounts));
            // The script swaps a tab between the two looks; it reads them from the list, so it holds no class of its own.
            Assert.That(list, Does.Contain("data-active-class=\"" + tabs[0].Groups["class"].Value + "\""));
            Assert.That(list, Does.Contain("data-inactive-class=\"" + tabs[1].Groups["class"].Value + "\""));
            Assert.That(list, Does.Contain("data-count-active-class=\"" + tabs[0].Groups["countClass"].Value + "\""));
            Assert.That(list, Does.Contain("data-count-inactive-class=\"" + tabs[1].Groups["countClass"].Value + "\""));
            Assert.That(tabs[0].Groups["class"].Value, Does.Contain("bg-blue-600 text-white"));
            Assert.That(tabs[1].Groups["class"].Value, Does.Contain("bg-gray-100 text-gray-700"));
        });
    }

    [Test]
    public async Task TC_SITE_R33_08_The_page_holds_the_words_the_script_shows_for_the_count_and_the_summary_toggle()
    {
        var html = await RenderAsync();

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("data-count-none=\"No matches\""));
            Assert.That(html, Does.Contain("data-count-one=\"1 publication available\""));
            Assert.That(html, Does.Contain("data-count-many=\"{count} publications available\""));
            Assert.That(html, Does.Contain("data-less-label=\"show less\""));
            Assert.That(html, Does.Contain(">3 publications available</p>"));
        });
    }

    [Test]
    public async Task TC_SITE_R32_02_A_tab_looks_the_same_before_and_after_the_first_click()
    {
        var html = await RenderAsync();
        string Value(string name) => WebUtility.HtmlDecode(Regex.Match(html, name + "=\"(?<v>[^\"]*)\"").Groups["v"].Value);
        var tabs = Regex.Matches(html, "<button type=\"button\" role=\"tab\" aria-selected=\"(?<selected>true|false)\"[^>]*class=\"(?<class>[^\"]*)\">\\s*<span>[^<]*</span>\\s*<span class=\"(?<count>[^\"]*)\">");

        Assert.Multiple(() =>
        {
            Assert.That(tabs, Is.Not.Empty);
            foreach (Match tab in tabs)
            {
                var chosen = tab.Groups["selected"].Value == "true";
                Assert.That(tab.Groups["class"].Value, Is.EqualTo(Value(chosen ? "data-active-class" : "data-inactive-class")));
                Assert.That(tab.Groups["count"].Value, Is.EqualTo(Value(chosen ? "data-count-active-class" : "data-count-inactive-class")));
            }
        });
    }

    [Test]
    public async Task TC_SITE_R33_01_The_search_box_is_on_the_page_and_every_publication_carries_the_text_it_is_searched_by()
    {
        var html = await RenderAsync();
        var panels = Panel().Matches(html);

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Match(@"<div class=""relative"" data-publications-search hidden(="""")?>\s*<svg.*?</svg>\s*<input type=""text"" placeholder=""Search publications..."" class=""[^""]*"""));
            // The text is the title, as the present site searches titles only.
            Assert.That(Card().Matches(html).Select(c => Text(c.Groups["text"].Value)), Is.EqualTo(AllCards));
            // The line the script rewrites with the number of matches, one in each panel.
            Assert.That(panels.Select(p => Regex.Count(p.Groups["body"].Value, "<p class=\"[^\"]*\" data-publications-count>")), Has.All.EqualTo(1));
        });
    }

    [Test]
    public async Task TC_SITE_R34_01_A_summary_is_written_whole_with_a_more_button_the_script_shows()
    {
        var html = await RenderAsync();
        var zeta = CardOf(html, "Zeta guide");

        Assert.Multiple(() =>
        {
            Assert.That(zeta, Does.Match(@"<p data-summary>A synthetic summary of the zeta guide.</p>\s*<button type=""button"" data-summary-toggle data-less-label=""show less"" hidden(="""")? class=""[^""]*"">more</button>"));
            // The two-line cut is the script's: without it the whole summary is read.
            Assert.That(html, Does.Not.Contain("class=\"line-clamp-2\""));
            Assert.That(Regex.Count(html, "data-summary-toggle"), Is.EqualTo(3));
        });
    }

    [Test]
    public async Task TC_SITE_R35_01_With_scripts_off_every_publication_of_every_language_is_shown()
    {
        var html = await RenderAsync();
        var main = html[html.IndexOf("<main", StringComparison.Ordinal)..html.IndexOf("</main>", StringComparison.Ordinal)];
        var hidden = Hidden().Matches(main).Select(m => m.Value).ToList();

        Assert.Multiple(() =>
        {
            // Only what does nothing without the script is hidden: the tabs, the search box and the three "more" buttons.
            Assert.That(hidden, Has.Count.EqualTo(5));
            Assert.That(hidden.Count(h => h.Contains("role=\"tablist\"", StringComparison.Ordinal)), Is.EqualTo(1));
            Assert.That(hidden.Count(h => h.Contains("data-publications-search", StringComparison.Ordinal)), Is.EqualTo(1));
            Assert.That(hidden.Count(h => h.Contains("data-summary-toggle", StringComparison.Ordinal)), Is.EqualTo(3));
            Assert.That(main, Does.Not.Match(@"class=""[^""]*(?<![\w:-])hidden(?![\w-])"));
            Assert.That(Panel().Count(main), Is.EqualTo(5));
            Assert.That(Card().Count(main), Is.EqualTo(7));
            foreach (var language in Languages)
            {
                Assert.That(main, Does.Contain("<h3 class=\"text-2xl font-semibold text-gray-900 dark:text-gray-100\">" + language + "</h3>"));
            }
        });
    }

    [Test]
    public async Task TC_SITE_R36_01_A_right_to_left_title_and_summary_are_right_to_left_in_the_language_s_font()
    {
        var html = await RenderAsync();
        var urdu = Text(CardOf(html, UrduTitle));
        var titles = Title().Matches(html);

        Assert.Multiple(() =>
        {
            // As an article's title (text-right, direction), and the stylesheet's [lang="ur"] gives Urdu its font.
            Assert.That(urdu, Does.Contain("<h4 class=\"text-lg font-semibold text-gray-900 dark:text-gray-100 text-right\" style=\"direction: rtl\" lang=\"ur\">" + UrduTitle + "</h4>"));
            Assert.That(urdu, Does.Contain("<p data-summary class=\"text-right\" style=\"direction: rtl\" lang=\"ur\">ایک مصنوعی خلاصہ</p>"));
            Assert.That(titles.Count(t => t.Groups["attributes"].Value.Contains("rtl", StringComparison.Ordinal)), Is.EqualTo(1));
            Assert.That(titles.Count(t => t.Groups["attributes"].Value.Contains("lang=", StringComparison.Ordinal)), Is.EqualTo(1));
        });
    }

    [TestCase("قرآن", "Urdu", true, "ur")]
    [TestCase("قرآن", "urdu", true, "ur")]
    [TestCase("قرآن", "Arabic", true, null)]
    [TestCase("قرآن", null, true, null)]
    [TestCase("Quran (Urdu, 2024)", "Urdu", false, null)]
    [TestCase("Plain", "English", false, null)]
    public void TC_SITE_R36_02_Direction_follows_the_script_of_the_text_and_the_font_its_language(string text, string? language, bool rightToLeft, string? lang)
    {
        Assert.Multiple(() =>
        {
            Assert.That(Publications.RightAligned(text), Is.EqualTo(rightToLeft ? "text-right" : null));
            Assert.That(Publications.Direction(text), Is.EqualTo(rightToLeft ? "direction: rtl" : null));
            Assert.That(Publications.Lang(text, language), Is.EqualTo(lang));
        });
    }
}
