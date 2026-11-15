using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using NUnit.Framework;
using Tsr.Content.Api.Features.V1Tags;

namespace Tsr.Db.Tests;

/// <summary>
/// <c>GET /api/v1/taxonomies/categories</c> and <c>GET /api/v1/taxonomies/tags</c>, the API in process over the synthetic set of db/synthetic/content (LIB-R13, LIB-R14).
/// The rule is tsr-web's two route files under <c>web/src/app/api/v1/taxonomies/</c>, <c>getCategoriesWithCounts</c> and <c>getAllTags</c>. Over HTTP: <c>v1-categories.hurl</c>, <c>v1-tags.hurl</c>.
/// </summary>
public sealed class V1TaxonomiesTests
{
    private const string Categories = "/api/v1/taxonomies/categories";
    private const string Tags = "/api/v1/taxonomies/tags";

    private WebApplicationFactory<Program> factory = null!;
    private HttpClient client = null!;

    [OneTimeSetUp]
    public async Task StartAsync()
    {
        factory = TestApi.Create();
        client = factory.CreateClient();
        await SyntheticContent.LoadAsync(factory);
    }

    [OneTimeTearDown]
    public void Stop()
    {
        client.Dispose();
        factory.Dispose();
    }

    private async Task<(HttpResponseMessage Response, JsonElement Body)> GetAsync(string url)
    {
        var response = await client.GetAsync(url);
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return (response, document.RootElement.Clone());
    }

    private static string Header(HttpResponseMessage response, string name) =>
        response.Headers.TryGetValues(name, out var values) || response.Content.Headers.TryGetValues(name, out values) ? string.Join(", ", values) : string.Empty;

    [Test]
    public async Task The_categories_are_the_parents_in_order_each_with_its_children_and_its_own_count()
    {
        var (response, body) = await GetAsync(Categories);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["success", "data", "meta"]));
        // A parent's count is of the articles filed under its own slug: "practice" has 3 and its two children 2 each, never 7.
        Assert.That(body.GetProperty("data").GetRawText(), Is.EqualTo(
            """
            [{"slug":"foundations","title":"Foundations","description":"Basic ideas every student starts with","order":1,"articleCount":2,"subcategories":[{"slug":"core-terms","title":"Core Terms","order":4,"parent":"foundations","articleCount":2}]},
            {"slug":"practice","title":"Practice","description":"Everyday study routines","order":2,"articleCount":3,"subcategories":[{"slug":"note-taking","title":"Note Taking","order":5,"parent":"practice","articleCount":2},{"slug":"revision-plans","title":"Revision Plans","order":6,"parent":"practice","articleCount":2}]},
            {"slug":"history","title":"History","description":"How study methods changed over time","order":3,"articleCount":2,"subcategories":[{"slug":"early-schools","title":"Early Schools","order":7,"parent":"history","articleCount":2}]}]
            """.ReplaceLineEndings(string.Empty)));
    }

    [Test]
    public async Task The_categories_send_the_cache_headers_without_a_last_modified()
    {
        var (response, body) = await GetAsync(Categories);

        Assert.That(Header(response, "Cache-Control"), Is.EqualTo("public, max-age=3600, stale-while-revalidate=86400"));
        Assert.That(Header(response, "ETag"), Does.Match("^\"[0-9a-f]{32}\"$"));
        Assert.That(Header(response, "Last-Modified"), Is.Empty);
        Assert.That(Header(response, "Access-Control-Allow-Origin"), Is.EqualTo("*"));
        Assert.That(body.GetProperty("meta").GetProperty("cache").GetProperty("maxAge").GetInt32(), Is.EqualTo(3600));
    }

    [Test]
    public async Task Flat_categories_are_all_seven_in_order_with_their_parent_and_no_children()
    {
        var (_, body) = await GetAsync(Categories + "?hierarchical=false");

        var data = body.GetProperty("data");
        Assert.That(data.EnumerateArray().Select(c => c.GetProperty("slug").GetString()), Is.EqualTo((string[])
            ["foundations", "practice", "history", "core-terms", "note-taking", "revision-plans", "early-schools"]));
        Assert.That(data[3].GetRawText(), Is.EqualTo("""{"slug":"core-terms","title":"Core Terms","order":4,"parent":"foundations","articleCount":2}"""));
        Assert.That(data[1].GetRawText(), Is.EqualTo("""{"slug":"practice","title":"Practice","description":"Everyday study routines","order":2,"articleCount":3}"""));
    }

    // tsr-web: only the exact text "false" switches an option off; anything else, an empty value too, leaves it on. The first value of a repeated option counts.
    [TestCase("", 3, 2)]
    [TestCase("?hierarchical=true", 3, 2)]
    [TestCase("?hierarchical=FALSE", 3, 2)]
    [TestCase("?hierarchical=0", 3, 2)]
    [TestCase("?hierarchical=", 3, 2)]
    [TestCase("?hierarchical=false", 7, 2)]
    [TestCase("?hierarchical=false&hierarchical=true", 7, 2)]
    [TestCase("?hierarchical=true&hierarchical=false", 3, 2)]
    [TestCase("?includeArticleCounts=false", 3, 0)]
    [TestCase("?includeArticleCounts=False", 3, 2)]
    [TestCase("?includeArticleCounts=no", 3, 2)]
    [TestCase("?includeArticleCounts=", 3, 2)]
    [TestCase("?hierarchical=false&includeArticleCounts=false", 7, 0)]
    [TestCase("?nonsense=1", 3, 2)]
    public async Task Only_the_text_false_switches_an_option_off(string query, int categories, int firstCount)
    {
        var (response, body) = await GetAsync(Categories + query);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.GetProperty("data").GetArrayLength(), Is.EqualTo(categories));
        Assert.That(body.GetProperty("data")[0].GetProperty("articleCount").GetInt32(), Is.EqualTo(firstCount));
    }

    [Test]
    public async Task Without_counts_every_count_is_zero_and_still_sent_the_children_s_too()
    {
        var (_, body) = await GetAsync(Categories + "?includeArticleCounts=false");

        Assert.That(body.GetProperty("data")[1].GetRawText(), Is.EqualTo(
            """{"slug":"practice","title":"Practice","description":"Everyday study routines","order":2,"articleCount":0,"subcategories":[{"slug":"note-taking","title":"Note Taking","order":5,"parent":"practice","articleCount":0},{"slug":"revision-plans","title":"Revision Plans","order":6,"parent":"practice","articleCount":0}]}"""));
    }

    [Test]
    public async Task Equal_orders_go_by_slug_and_a_child_of_a_child_or_of_no_one_is_only_in_the_flat_list()
    {
        // Order 999 is what the refresh stores for a category file with no order.
        await TestDatabase.ExecuteAsync("""
            insert into content.categories (slug, title, sort_order, parent_slug) values
              ('zz-last', 'Last', 999, null), ('aa-first', 'First', 999, null),
              ('grandchild', 'Grandchild', 1, 'note-taking'), ('orphan', 'Orphan', 1, 'no-such-parent')
            """);
        try
        {
            var (_, tree) = await GetAsync(Categories);
            var (_, flat) = await GetAsync(Categories + "?hierarchical=false");

            Assert.That(tree.GetProperty("data").EnumerateArray().Select(c => c.GetProperty("slug").GetString()), Is.EqualTo((string[])
                ["foundations", "practice", "history", "aa-first", "zz-last"]));
            Assert.That(tree.GetProperty("data")[3].GetRawText(), Is.EqualTo("""{"slug":"aa-first","title":"First","order":999,"articleCount":0}"""));
            Assert.That(tree.GetRawText(), Does.Not.Contain("grandchild").And.Not.Contain("orphan"));
            Assert.That(flat.GetProperty("data").EnumerateArray().Select(c => c.GetProperty("slug").GetString()), Is.EqualTo((string[])
                ["foundations", "grandchild", "orphan", "practice", "history", "core-terms", "note-taking", "revision-plans", "early-schools", "aa-first", "zz-last"]));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("delete from content.categories where slug in ('zz-last', 'aa-first', 'grandchild', 'orphan')");
        }
    }

    [Test]
    public async Task The_tags_are_most_used_first_and_equal_counts_in_the_order_first_met_newest_article_first()
    {
        var (response, body) = await GetAsync(Tags);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["success", "data", "meta"]));
        // Counts of 2: "Night Reading" is met in the third newest article, "Imam Ali (a.s.)" in the fifth, "Summaries" in the ninth. It is not the alphabet's order.
        Assert.That(body.GetProperty("data").GetRawText(), Is.EqualTo(
            """
            [{"name":"Study Skills","slug":"study-skills","articleCount":7},
            {"name":"Night Reading","slug":"night-reading","articleCount":2},
            {"name":"Imam Ali (a.s.)","slug":"imam-ali-as","articleCount":2},
            {"name":"Summaries","slug":"summaries","articleCount":2},
            {"name":"Planning","slug":"planning","articleCount":1},
            {"name":"Timetables","slug":"timetables","articleCount":1},
            {"name":"Zorvath Method","slug":"zorvath-method","articleCount":1},
            {"name":"History","slug":"history","articleCount":1},
            {"name":"Glossary","slug":"glossary","articleCount":1}]
            """.ReplaceLineEndings(string.Empty)));
        Assert.That(Header(response, "Cache-Control"), Is.EqualTo("public, max-age=3600, stale-while-revalidate=86400"));
        Assert.That(Header(response, "Last-Modified"), Is.Empty);
    }

    [Test]
    public async Task Tags_of_one_article_keep_the_file_s_order_and_a_tag_written_twice_counts_twice()
    {
        await TestDatabase.ExecuteAsync("""
            insert into content.published_articles (slug, slug_decoded, title, body_markdown, body_html, published_at, published_date_text, author, language, reading_minutes, categories, tags)
            values ('newest-of-all', 'newest-of-all', 'Newest', 'x', '<p>x</p>', '2040-01-01T00:00:00Z', '2040-01-01T00:00:00.000Z', 'admin', 'en', 1, array[]::text[], array['Zeta', 'Alpha', 'Twice', 'Twice', 'twice'])
            """);
        try
        {
            var (_, body) = await GetAsync(Tags);

            var names = body.GetProperty("data").EnumerateArray().Select(t => t.GetProperty("name").GetString() + ":" + t.GetProperty("articleCount").GetInt32()).ToList();
            Assert.That(names.Take(5), Is.EqualTo((string[])["Study Skills:7", "Twice:2", "Night Reading:2", "Imam Ali (a.s.):2", "Summaries:2"]));
            Assert.That(names.Skip(5).Take(4), Is.EqualTo((string[])["Zeta:1", "Alpha:1", "twice:1", "Planning:1"]));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("delete from content.published_articles where slug = 'newest-of-all'");
        }
    }

    // tsr-web: name.toLowerCase().replace(/\s+/g, '-').replace(/[^\w-]/g, ''). JavaScript's \w is the Latin letters, the digits and "_" only.
    [TestCase("Imam Ali (a.s.)", "imam-ali-as")]
    [TestCase("Study Skills", "study-skills")]
    [TestCase("  Two   spaces\tand a tab ", "-two-spaces-and-a-tab-")]
    [TestCase("snake_case-and-dash", "snake_case-and-dash")]
    [TestCase("Q&A: 100%", "qa-100")]
    [TestCase("مطالعہ", "")]
    [TestCase("مطالعہ نوٹس", "-")]
    [TestCase("Café", "caf")]
    [TestCase("no break", "no-break")]
    [TestCase("", "")]
    public void A_tag_s_slug_is_made_as_the_website_makes_it(string name, string slug) =>
        Assert.That(V1TagsSlice.Slug(name), Is.EqualTo(slug));
}
