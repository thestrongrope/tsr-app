using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using Tsr.Content.Site;
using Tsr.Shared.Site;
using NUnit.Framework;

namespace Tsr.Host.Site.Tests;

/// <summary>
/// Issue 67, SITE-R40 to R44: the article list's category and tag filters. What each card holds (its categories and tags,
/// written for the script to compare), the panel's tree and counts, and the heading data are decided at build time and tested
/// here. Reading the address, hiding cards and opening the panel are the script's (hosts/site/wwwroot/site.js): these tests
/// check the markup it acts on, and hosts/site/tests/js checks its pure functions without a browser.
/// </summary>
public sealed partial class ArticleFilterTests
{
    private const string Address = "/articles/";

    /// <summary>The articleCount values are the route's: published articles filed under the slug itself (spec/api.yaml), as ListJson holds them.</summary>
    private const string CategoriesJson = """
        {"success":true,"data":[
        {"slug":"foundations","title":"Foundations &amp; Basics","order":1,"articleCount":1},
        {"slug":"core-terms","title":"Core Terms","description":"About core terms.","order":4,"parent":"foundations","articleCount":1},
        {"slug":"empty-child","title":"Empty Child","order":5,"parent":"foundations","articleCount":0},
        {"slug":"solo","title":"Solo","order":6,"articleCount":1},
        {"slug":"other-child","title":"Other Child","order":7,"parent":"solo","articleCount":1},
        {"slug":"unused-parent","title":"Unused Parent","order":8,"articleCount":0},
        {"slug":"ghost-parent","title":"Ghost Parent","order":9,"articleCount":0},
        {"slug":"ghost-child","title":"Ghost Child","order":10,"parent":"ghost-parent","articleCount":1}],
        "meta":{"version":"1.0"}}
        """;

    private const string ListJson = """
        {"success":true,"data":[
        {"slug":"synthetic-published-article","title":"Synthetic &amp; published article","excerpt":"A synthetic excerpt.",
         "categories":["core-terms","foundations"],"tags":["Sample Tag"]},
        {"slug":"another-synthetic-article","title":"Another synthetic article",
         "categories":["solo","other-child","ghost-child"],"tags":["sample  TAG","Other","قرآن"]}],
        "meta":{"version":"1.0"},"pagination":{"total":2,"limit":100,"offset":0,"hasMore":false}}
        """;

    private static readonly JsonSerializerOptions Web = new(JsonSerializerDefaults.Web);

    private static readonly (string, string, int)[] CoreChild = [("core-terms", "Core Terms", 1)];

    private static readonly string[] OtherChild = ["other-child"];

    private static readonly (string, int)[] ParentCounts = [("foundations", 1), ("solo", 1)];

    private static readonly (string, string)[] PanelLinks = [("foundations", "1"), ("core-terms", "1"), ("solo", "1"), ("other-child", "1")];

    [GeneratedRegex(@"<a href=""/articles/(?<slug>[^/""]+)/""(?<attributes>[^>]*)>")]
    private static partial Regex CardTag();

    [GeneratedRegex(@"\sdata-article-filters=""(?<json>[^""]*)""")]
    private static partial Regex FiltersAttribute();

    [GeneratedRegex(@"<a href=""/articles/\?category=(?<slug>[^""]+)""[^>]*data-filter-link[^>]*>.*?<span class=""text-xs opacity-70 ml-2"">\((?<count>\d+)\)</span>", RegexOptions.Singleline)]
    private static partial Regex PanelLink();

    private static SiteApi Api(string listJson = ListJson, string categoriesJson = CategoriesJson) =>
        FakeApi.With(FakeApi.HealthyAnswers
            .Select(a => a.Path switch
            {
                FakeApi.ListPath => (a.Path, a.Status, listJson),
                FakeApi.CategoriesPath => (a.Path, a.Status, categoriesJson),
                _ => a,
            })
            .ToArray());

    private static async Task<string> RenderAsync(SiteApi? api = null)
    {
        api ??= Api();
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None);
        var menu = await ContentSite.MenuAsync(api, CancellationToken.None);
        return await SiteBuilder.RenderAsync(pages.Single(p => p.Path == Address), menu);
    }

    private static string Attribute(string attributes, string name)
    {
        var match = Regex.Match(attributes, @"\s" + name + @"=""(?<value>[^""]*)""");
        Assert.That(match.Success, Is.True, $"no {name} on the card");
        return WebUtility.HtmlDecode(match.Groups["value"].Value);
    }

    private static string CardAttribute(string html, string slug, string name) =>
        Attribute(CardTag().Matches(html).Single(c => c.Groups["slug"].Value == slug).Groups["attributes"].Value, name);

    private static JsonElement Filters(string html) =>
        JsonElement.Parse(WebUtility.HtmlDecode(FiltersAttribute().Match(html).Groups["json"].Value));

    private static ArticleSummary Summary(string slug, string[] categories, string[] tags) =>
        new(slug, slug, null, categories, tags);

    private static List<Category> Categories(string json) =>
        JsonSerializer.Deserialize<V1Answer<List<Category>>>(json, Web)!.Data!;

    private static List<ArticleSummary> Articles(string json) =>
        JsonSerializer.Deserialize<V1Answer<List<ArticleSummary>>>(json, Web)!.Data!;

    [Test]
    public async Task TC_SITE_R40_01_Each_card_names_its_category_slugs_for_the_script_to_compare_whole()
    {
        var html = await RenderAsync();

        Assert.Multiple(() =>
        {
            Assert.That(CardAttribute(html, "synthetic-published-article", "data-categories"), Is.EqualTo("|core-terms|foundations|"));
            Assert.That(CardAttribute(html, "another-synthetic-article", "data-categories"), Is.EqualTo("|solo|other-child|ghost-child|"));
        });
    }

    [Test]
    public void TC_SITE_R40_02_An_article_without_a_category_has_no_token()
    {
        Assert.Multiple(() =>
        {
            Assert.That(ArticleFilters.Tokens([]), Is.EqualTo(string.Empty));
            Assert.That(ArticleFilters.Tokens(["a"]), Is.EqualTo("|a|"));
            Assert.That(ArticleFilters.Tokens(["a", "b"]), Is.EqualTo("|a|b|"));
        });
    }

    [Test]
    public async Task TC_SITE_R40_03_The_heading_data_has_each_category_s_title_parent_title_and_description_decoded()
    {
        var categories = Filters(await RenderAsync()).GetProperty("categories");

        Assert.Multiple(() =>
        {
            var core = categories.GetProperty("core-terms");
            Assert.That(core.GetProperty("title").GetString(), Is.EqualTo("Core Terms"));
            Assert.That(core.GetProperty("parent").GetString(), Is.EqualTo("Foundations & Basics"));
            Assert.That(core.GetProperty("description").GetString(), Is.EqualTo("About core terms."));
            Assert.That(categories.GetProperty("foundations").TryGetProperty("parent", out _), Is.False);
            Assert.That(categories.GetProperty("foundations").TryGetProperty("description", out _), Is.False);
            Assert.That(categories.TryGetProperty("no-such-category", out _), Is.False);
        });
    }

    [Test]
    public async Task TC_SITE_R40_04_The_category_chip_names_only_categories_the_panel_lists_as_the_present_site_does()
    {
        var categories = Filters(await RenderAsync()).GetProperty("categories");

        Assert.Multiple(() =>
        {
            Assert.That(categories.GetProperty("core-terms").GetProperty("chip").GetString(), Is.EqualTo("Core Terms"));
            Assert.That(categories.GetProperty("foundations").GetProperty("chip").GetString(), Is.EqualTo("Foundations & Basics"));
            // Not in the panel (no article of its own): the present site's chip falls back to the slug, so no chip title is sent.
            Assert.That(categories.GetProperty("ghost-child").TryGetProperty("chip", out _), Is.False);
            Assert.That(categories.GetProperty("unused-parent").TryGetProperty("chip", out _), Is.False);
        });
    }

    [Test]
    public async Task TC_SITE_R41_01_Each_card_names_its_tags_slugified_the_one_form_all_three_of_the_present_site_s_matches_reduce_to()
    {
        var html = await RenderAsync();

        Assert.Multiple(() =>
        {
            Assert.That(CardAttribute(html, "synthetic-published-article", "data-tags"), Is.EqualTo("|sample-tag|"));
            // A tag with no Latin letter or digit slugifies to nothing, as on the present site: the token is empty.
            Assert.That(CardAttribute(html, "another-synthetic-article", "data-tags"), Is.EqualTo("|sample-tag|other||"));
        });
    }

    [TestCase("Sample Tag", "sample-tag")]
    [TestCase("  Ahl-e  Bait!! ", "ahl-e-bait")]
    [TestCase("--a--b--", "a-b")]
    [TestCase("UPPER_case 42", "upper-case-42")]
    [TestCase("قرآن", "")]
    [TestCase("", "")]
    [TestCase("Café", "caf")]
    // JavaScript lower-cases U+0130 to an i and a combining dot, so the slug has a dash after the i.
    [TestCase("İstanbul", "i-stanbul")]
    // The Kelvin sign lower-cases to a plain k in both.
    [TestCase("Key", "key")]
    public void TC_SITE_R41_02_Slugify_gives_the_present_site_s_answer(string text, string expected) =>
        Assert.That(ArticleFilters.Slugify(text), Is.EqualTo(expected));

    [Test]
    public async Task TC_SITE_R41_03_The_heading_names_the_first_tag_the_present_site_finds_for_a_slug_walking_articles_in_list_order()
    {
        var tags = Filters(await RenderAsync()).GetProperty("tags");

        Assert.Multiple(() =>
        {
            Assert.That(tags.GetProperty("sample-tag").GetString(), Is.EqualTo("Sample Tag"));
            Assert.That(tags.GetProperty("other").GetString(), Is.EqualTo("Other"));
            Assert.That(tags.GetProperty("").GetString(), Is.EqualTo("قرآن"));
        });
    }

    [Test]
    public void TC_SITE_R42_01_The_panel_shows_the_route_s_article_counts_and_leaves_out_empty_entries()
    {
        var panel = ArticleFilters.Panel(Categories(CategoriesJson));

        Assert.Multiple(() =>
        {
            // Parents in the API's order; a parent without an article of its own is left out with its children (ghost-parent);
            // a child without one is left out (empty-child).
            Assert.That(panel.Select(p => (p.Slug, p.Count)), Is.EqualTo(ParentCounts));
            Assert.That(panel[0].Children.Select(c => (c.Slug, c.Title, c.Count)), Is.EqualTo(CoreChild));
            Assert.That(panel[0].Title, Is.EqualTo("Foundations & Basics"));
            Assert.That(panel[1].Children.Select(c => c.Slug), Is.EqualTo(OtherChild));
        });
    }

    [Test]
    public void TC_SITE_R42_02_A_count_is_the_route_s_articleCount_and_the_site_does_not_recount()
    {
        var categories = new List<Category>
        {
            new("parent", "Parent", null, 7),
            new("child", "Child", "parent", 3),
        };

        var panel = ArticleFilters.Panel(categories);

        Assert.That(panel.Single().Count, Is.EqualTo(7));
        Assert.That(panel.Single().Children.Single().Count, Is.EqualTo(3));
    }

    [Test]
    public async Task TC_SITE_R42_03_The_page_writes_the_panel_open_with_a_link_and_count_for_each_entry_and_a_button_for_each_parent_with_children()
    {
        var html = await RenderAsync();
        var links = PanelLink().Matches(html).Select(m => (m.Groups["slug"].Value, m.Groups["count"].Value)).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("Filter by Category"));
            Assert.That(html, Does.Contain("href=\"/articles/\" class=\"block px-5 py-2.5 rounded-xl font-medium transition-all"));
            Assert.That(links, Is.EqualTo(PanelLinks));
            Assert.That(html, Does.Contain("&#x21B3; Core Terms").Or.Contain("↳ Core Terms"));
            Assert.That(Regex.Count(html, "aria-label=\"Collapse subcategories\""), Is.EqualTo(2));
            // Written open: with scripts off nothing hides a link.
            Assert.That(html, Does.Not.Contain("data-filter-panel-body hidden"));
        });
    }

    [Test]
    public async Task TC_SITE_R42_04_The_panel_is_left_out_when_no_category_holds_an_article()
    {
        var html = await RenderAsync(Api(categoriesJson: """{"success":true,"data":[],"meta":{"version":"1.0"}}"""));

        Assert.That(html, Does.Not.Contain("Filter by Category"));
    }

    [Test]
    public async Task TC_SITE_R43_01_Written_for_a_reader_without_scripts_the_page_is_the_whole_list_under_All_Articles()
    {
        var html = await RenderAsync();
        var cards = CardTag().Matches(html);

        Assert.Multiple(() =>
        {
            Assert.That(cards.Count, Is.EqualTo(2));
            Assert.That(cards.All(c => !Regex.IsMatch(c.Groups["attributes"].Value, @"class=""[^""]*\bhidden\b")), Is.True);
            Assert.That(html, Does.Contain("data-filter-heading"));
            Assert.That(html, Does.Contain(">All Articles</h1>"));
            Assert.That(html, Does.Contain("Explore our collection of articles on the path of the Ahle Bait (a.s.)"));
            // The things only a filter shows are written hidden.
            Assert.That(Regex.IsMatch(html, @"<div[^>]*data-filter-reset[^>]*\shidden"), Is.True);
            Assert.That(Regex.IsMatch(html, @"<div[^>]*data-filter-none[^>]*\shidden"), Is.True);
        });
    }

    [Test]
    public async Task TC_SITE_R43_02_The_page_holds_the_words_of_the_present_site_s_nothing_found_box_apart_from_what_the_script_adds()
    {
        var html = await RenderAsync();

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("data-filter-none"));
            Assert.That(html, Does.Contain("data-filter-none-title"));
            Assert.That(html, Does.Contain("data-filter-none-hint"));
            Assert.That(html, Does.Not.Contain("/admin"));
        });
    }

    [Test]
    public async Task TC_SITE_R44_01_Nothing_in_the_page_or_the_script_asks_for_anything_after_the_page_has_loaded()
    {
        var html = await RenderAsync();
        var script = await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "wwwroot", "site.js"));

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Not.Contain("search-index"));
            Assert.That(script, Does.Not.Contain("fetch("));
            Assert.That(script, Does.Not.Contain("XMLHttpRequest"));
        });
    }

    [Test]
    public async Task TC_SITE_R40_05_A_list_answer_without_tags_stops_the_build()
    {
        var json = ListJson.Replace("\"tags\":[\"Sample Tag\"]", "\"x\":1", StringComparison.Ordinal);

        var thrown = await Assert.ThrowsAsync<SiteBuildException>(async () => await RenderAsync(Api(json)));

        Assert.That(thrown.Message, Does.Contain("tags"));
    }

    [Test]
    public void TC_SITE_R40_06_Slugs_with_a_pipe_cannot_be_written_as_a_token()
    {
        var thrown = Assert.Throws<SiteBuildException>(() => ArticleFilters.Tokens(["a|b"]));

        Assert.That(thrown!.Message, Does.Contain("|"));
    }

    [Test]
    public async Task TC_SITE_R43_05_The_page_holds_every_word_the_script_shows_and_writes_the_unfiltered_ones_from_the_same_text()
    {
        var html = await RenderAsync();
        var texts = Filters(html).GetProperty("texts");

        Assert.Multiple(() =>
        {
            Assert.That(texts.GetProperty("allArticles").GetString(), Is.EqualTo("All Articles"));
            Assert.That(texts.GetProperty("defaultDescription").GetString(), Is.EqualTo("Explore our collection of articles on the path of the Ahle Bait (a.s.)"));
            Assert.That(texts.GetProperty("tagTitle").GetString(), Is.EqualTo("Articles tagged \u201C{name}\u201D"));
            Assert.That(texts.GetProperty("tagDescription").GetString(), Is.EqualTo("Showing all articles with the tag \"{name}\""));
            Assert.That(texts.GetProperty("tagChip").GetString(), Is.EqualTo("Tag: {name}"));
            Assert.That(texts.GetProperty("noneTitle").GetString(), Is.EqualTo("No articles found"));
            Assert.That(texts.GetProperty("noneInCategory").GetString(), Is.EqualTo(" in this category"));
            Assert.That(texts.GetProperty("noneWithTag").GetString(), Is.EqualTo(" with tag \"{name}\""));
            Assert.That(texts.GetProperty("hintTag").GetString(), Is.EqualTo("Try selecting a different tag"));
            Assert.That(texts.GetProperty("hintCategory").GetString(), Is.EqualTo("Try selecting a different category"));
            Assert.That(html, Does.Contain(">" + texts.GetProperty("allArticles").GetString() + "</h1>"));
            Assert.That(html, Does.Contain(">" + texts.GetProperty("defaultDescription").GetString() + "</p>"));
        });
    }

    [TestCase("Explore our collection")]
    [TestCase("Articles tagged")]
    [TestCase("Showing all articles")]
    [TestCase("No articles found")]
    [TestCase("Try selecting")]
    [TestCase("All Articles")]
    [TestCase("publications available")]
    [TestCase("No matches")]
    [TestCase("show less")]
    public async Task TC_SITE_R44_02_The_script_holds_no_sentence_a_reader_sees(string sentence)
    {
        var script = await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "wwwroot", "site.js"));

        Assert.That(script, Does.Not.Contain(sentence));
    }

    [Test]
    public async Task TC_SITE_R44_03_The_script_builds_no_selector_from_a_value_without_escaping_it()
    {
        var lines = await File.ReadAllLinesAsync(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "wwwroot", "site.js"));

        var unescaped = lines.Where(line => line.Contains("querySelector", StringComparison.Ordinal) && line.Contains("' +", StringComparison.Ordinal)
            && !line.Contains("CSS.escape(", StringComparison.Ordinal)).ToList();

        Assert.That(unescaped, Is.Empty);
    }

    [TestCase("good-slug")]
    [TestCase("imam-ali")]
    [TestCase("a1-b2-3")]
    public async Task TC_SITE_R45_01_A_category_slug_of_lower_case_letters_digits_and_dashes_builds(string slug)
    {
        var json = $$$"""{"success":true,"data":[{"slug":"{{{slug}}}","title":"T","order":1,"articleCount":0}],"meta":{"version":"1.0"}}""";

        var html = await RenderAsync(Api(categoriesJson: json));

        Assert.That(html, Does.Contain("data-article-list"));
    }

    [TestCase("a\\\"b")]
    [TestCase("a]b")]
    [TestCase("a&b")]
    [TestCase("a#b")]
    [TestCase("a b")]
    [TestCase("a/b")]
    [TestCase("A-b")]
    [TestCase("a_b")]
    [TestCase("-a")]
    [TestCase("a-")]
    [TestCase("a--b")]
    [TestCase("")]
    [TestCase("ا")]
    public async Task TC_SITE_R45_02_A_category_slug_outside_that_form_stops_the_build_and_names_the_category(string slug)
    {
        var json = $$$"""{"success":true,"data":[{"slug":{{{JsonSerializer.Serialize(slug)}}},"title":"The odd one","order":1,"articleCount":0}],"meta":{"version":"1.0"}}""";

        var failure = await Assert.ThrowsAsync<SiteBuildException>(() => RenderAsync(Api(categoriesJson: json)));

        Assert.That(failure!.Message, Does.Contain("Category slug").And.Contain(slug));
    }

    [Test]
    public async Task TC_SITE_R45_03_A_parent_naming_a_slug_outside_that_form_stops_the_build()
    {
        var json = """{"success":true,"data":[{"slug":"fine","title":"T","order":1,"parent":"a\"b","articleCount":0}],"meta":{"version":"1.0"}}""";

        var failure = await Assert.ThrowsAsync<SiteBuildException>(() => RenderAsync(Api(categoriesJson: json)));

        Assert.That(failure!.Message, Does.Contain("Category slug"));
    }
}
