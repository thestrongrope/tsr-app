using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;
using NUnit.Framework;
using Tsr.Content.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>
/// <c>GET /api/v1/search</c> with no Elasticsearch (the test API has none configured), so every answer is the database fallback (SRCH-R6): the validation, the numbers, the paging fields, the cache headers and the
/// fallback's own rules, over the synthetic articles of db/synthetic/content. The Elasticsearch path is proven by unit tests (the body) and by <c>v1-search.hurl</c> on a stack that has the engine.
/// </summary>
public sealed class V1SearchTests
{
    private const string Search = "/api/v1/search";

    private WebApplicationFactory<Program> factory = null!;
    private HttpClient client = null!;

    [OneTimeSetUp]
    public async Task StartAsync()
    {
        factory = TestApi.Create();
        client = factory.CreateClient();
        await TestDatabase.ExecuteAsync("truncate content.published_articles, content.categories, content.publications, content.refresh_state");
        await using var scope = factory.Services.CreateAsyncScope();
        var directory = Path.Combine(TestDatabase.RepoRoot(), "db", "synthetic", "content");
        var outcome = await ContentRefresh.TickAsync(scope.ServiceProvider.GetRequiredService<NpgsqlDataSource>(), directory, TimeProvider.System, NullLogger.Instance, CancellationToken.None);
        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Refreshed));
    }

    [OneTimeTearDown]
    public void Stop()
    {
        client.Dispose();
        factory.Dispose();
    }

    [TearDown]
    public Task RemoveTestArticlesAsync() => TestDatabase.ExecuteAsync("delete from content.published_articles where slug like 'search-test-%'");

    private async Task<(HttpResponseMessage Response, JsonElement Body)> GetAsync(string url)
    {
        var response = await client.GetAsync(url);
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return (response, document.RootElement.Clone());
    }

    private static string[] Slugs(JsonElement body) => [.. body.GetProperty("data").GetProperty("results").EnumerateArray().Select(r => r.GetProperty("slug").GetString()!)];

    private static Task InsertAsync(string slug, string title, string body) => TestDatabase.ExecuteAsync(
        $"""
        insert into content.published_articles
            (slug, slug_decoded, title, excerpt, body_markdown, body_html, published_at, published_date_text, author, language, reading_minutes, categories, tags)
        values ('{slug}', '{slug}', '{title}', null, '{body}', '<p>x</p>', timestamptz '2030-01-01 00:00:00+00', '2030-01-01', 'Author', 'en', 2, array[]::text[], array[]::text[])
        """);

    [TestCase("")]
    [TestCase("?q=")]
    [TestCase("?q=%20%20%20")]
    public async Task A_missing_or_blank_q_is_a_400_validation_error_with_no_cache_headers(string query)
    {
        var (response, body) = await GetAsync(Search + query);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.BadRequest));
        Assert.That(body.GetProperty("success").GetBoolean(), Is.False);
        Assert.That(body.GetProperty("error").GetRawText(), Is.EqualTo("""{"code":"VALIDATION_ERROR","message":"Missing required parameter: q"}"""));
        Assert.That(body.GetProperty("meta").GetProperty("cache").GetProperty("maxAge").GetInt32(), Is.Zero);
        Assert.That(response.Headers.Contains("Cache-Control"), Is.False);
    }

    [TestCase("&limit=0", 1, 0)]
    [TestCase("&limit=500", 100, 0)]
    [TestCase("&limit=abc", 20, 0)]
    [TestCase("&limit=7x", 7, 0)]
    [TestCase("&offset=-3", 20, 0)]
    [TestCase("&limit=3&offset=2", 3, 2)]
    public async Task Limit_and_offset_are_read_as_the_website_reads_them(string query, int limit, int offset)
    {
        var (response, body) = await GetAsync(Search + "?q=study" + query);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        var pagination = body.GetProperty("pagination");
        Assert.That(pagination.GetProperty("limit").GetInt32(), Is.EqualTo(limit));
        Assert.That(pagination.GetProperty("offset").GetInt32(), Is.EqualTo(offset));
    }

    [TestCase("?q=patience&offset=9990")]
    [TestCase("?q=patience&limit=100&offset=9901")]
    [TestCase("?q=patience&offset=99999999999")]
    public async Task A_page_past_the_result_window_is_a_400_validation_error(string query)
    {
        var (response, body) = await GetAsync(Search + query);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.BadRequest));
        Assert.That(body.GetProperty("error").GetRawText(), Is.EqualTo("""{"code":"VALIDATION_ERROR","message":"Result window too large: offset plus limit must not exceed 10000"}"""));
        Assert.That(response.Headers.Contains("Cache-Control"), Is.False);
    }

    [Test]
    public async Task A_category_longer_than_100_characters_is_a_400_validation_error()
    {
        var (response, body) = await GetAsync(Search + "?q=study&category=" + new string('a', 101));

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.BadRequest));
        Assert.That(body.GetProperty("error").GetRawText(), Is.EqualTo("""{"code":"VALIDATION_ERROR","message":"Category too long: at most 100 characters"}"""));
    }

    [Test]
    public async Task A_text_longer_than_200_characters_is_a_400_validation_error()
    {
        var (response, body) = await GetAsync(Search + "?q=" + new string('a', 201));

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.BadRequest));
        Assert.That(body.GetProperty("error").GetRawText(), Is.EqualTo("""{"code":"VALIDATION_ERROR","message":"Query too long: at most 200 characters"}"""));
    }

    [Test]
    public async Task Without_the_engine_the_answer_comes_from_the_published_articles_with_the_fuse_engine_name_and_a_highlight()
    {
        var (response, body) = await GetAsync(Search + "?q=zorvath");

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.GetProperty("success").GetBoolean(), Is.True);
        var data = body.GetProperty("data");
        Assert.That(data.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["results", "query", "searchEngine", "took"]));
        Assert.That(data.GetProperty("searchEngine").GetString(), Is.EqualTo("fuse"));
        Assert.That(data.GetProperty("query").GetString(), Is.EqualTo("zorvath"));
        Assert.That(Slugs(body), Is.EqualTo((string[])["the-zorvath-timetable", "drafting-questions-before-a-lesson", "finding-the-main-idea"]), "title, then excerpt, then tag");
        var first = data.GetProperty("results")[0];
        Assert.That(first.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["id", "slug", "title", "excerpt", "publishedDate", "author", "categories", "tags", "language", "readingTime", "score", "highlights"]).Or.EqualTo((string[])["id", "slug", "title", "excerpt", "publishedDate", "modifiedDate", "author", "categories", "tags", "language", "readingTime", "score", "highlights"]));
        Assert.That(first.GetProperty("score").GetDouble(), Is.EqualTo(1.0));
        Assert.That(first.GetProperty("highlights").GetProperty("title")[0].GetString(), Is.EqualTo("The <em>Zorvath</em> Timetable"));
    }

    [Test]
    public async Task A_category_keeps_only_that_categorys_articles_and_the_page_fields_follow_the_website_rule()
    {
        var (_, all) = await GetAsync(Search + "?q=study&limit=2");
        var (_, noteTaking) = await GetAsync(Search + "?q=study&category=note-taking");
        var (_, everything) = await GetAsync(Search + "?q=study&limit=100");

        Assert.That(all.GetProperty("pagination").GetProperty("total").GetInt32(), Is.EqualTo(2));
        Assert.That(all.GetProperty("pagination").GetProperty("hasMore").GetBoolean(), Is.True);
        Assert.That(Slugs(noteTaking), Is.EquivalentTo((string[])["a-first-look-at-margin-notes", "building-a-weekly-summary-page"]));
        Assert.That(everything.GetProperty("pagination").GetProperty("hasMore").GetBoolean(), Is.False);
        Assert.That(everything.GetProperty("pagination").GetProperty("total").GetInt32(), Is.EqualTo(Slugs(everything).Length));
    }

    [Test]
    public async Task Every_word_must_occur_so_a_word_nobody_wrote_finds_nothing()
    {
        var (_, body) = await GetAsync(Search + "?q=zorvath%20quelmbry");

        Assert.That(Slugs(body), Is.Empty);
        Assert.That(body.GetProperty("pagination").GetProperty("hasMore").GetBoolean(), Is.False);
    }

    [Test]
    public async Task A_percent_sign_and_an_underscore_in_the_text_match_themselves_only()
    {
        await InsertAsync("search-test-percent", "Rate 50% off", "plain");
        await InsertAsync("search-test-plain", "Rate 50 off", "plain");
        await InsertAsync("search-test-underscore", "snake_case words", "plain");
        await InsertAsync("search-test-letter", "snakeXcase words", "plain");

        var (_, percent) = await GetAsync(Search + "?q=" + Uri.EscapeDataString("50% off"));
        var (_, underscore) = await GetAsync(Search + "?q=" + Uri.EscapeDataString("snake_case"));
        var (_, backslash) = await GetAsync(Search + "?q=" + Uri.EscapeDataString("a\\b"));

        Assert.That(Slugs(percent), Is.EqualTo((string[])["search-test-percent"]));
        Assert.That(Slugs(underscore), Is.EqualTo((string[])["search-test-underscore"]));
        Assert.That(Slugs(backslash), Is.Empty);
    }

    [Test]
    public async Task Markup_in_an_article_reaches_the_highlight_only_as_encoded_text()
    {
        await InsertAsync("search-test-markup", "Tom & <b>Jerry</b> show", "plain");

        var (_, body) = await GetAsync(Search + "?q=jerry");

        Assert.That(body.GetProperty("data").GetProperty("results")[0].GetProperty("highlights").GetProperty("title")[0].GetString(),
            Is.EqualTo("Tom &amp; &lt;b&gt;<em>Jerry</em>&lt;/b&gt; show"));
    }

    [Test]
    public async Task A_hit_in_the_body_is_found_and_highlighted_from_the_body()
    {
        var (_, body) = await GetAsync(Search + "?q=quelmbry");

        Assert.That(Slugs(body), Is.EqualTo((string[])["glossary-habits-for-new-terms"]));
        var content = body.GetProperty("data").GetProperty("results")[0].GetProperty("highlights").GetProperty("content")[0].GetString();
        Assert.That(content, Does.Contain("<em>").And.Contain("</em>"));
    }

    [Test]
    public async Task A_200_has_the_cache_headers_and_is_never_a_304()
    {
        var first = await client.GetAsync(Search + "?q=zorvath");
        var etag = first.Headers.ETag!.ToString();
        using var request = new HttpRequestMessage(HttpMethod.Get, Search + "?q=zorvath");
        request.Headers.TryAddWithoutValidation("If-None-Match", etag);
        var second = await client.SendAsync(request);

        Assert.That(first.Headers.GetValues("Cache-Control"), Is.EqualTo((string[])["public, max-age=60"]));
        Assert.That(etag, Does.Match("^\"[0-9a-f]{32}\"$"));
        Assert.That(first.Headers.GetValues("Vary"), Is.EqualTo((string[])["Accept-Encoding"]));
        Assert.That(first.Headers.GetValues("Access-Control-Allow-Origin"), Is.EqualTo((string[])["*"]));
        Assert.That(second.StatusCode, Is.EqualTo(HttpStatusCode.OK));
    }
}
