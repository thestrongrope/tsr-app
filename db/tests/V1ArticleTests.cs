using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// <c>GET /api/v1/articles/{slug}</c>, the API in process over the synthetic set of db/synthetic/content (LIB-R10, LIB-R11, LIB-R25).
/// The rule is tsr-web's <c>web/src/app/api/v1/articles/[slug]/route.ts</c>, <c>getArticleBySlug</c> and <c>getRelatedPosts</c>. Over HTTP: <c>v1-article.hurl</c>.
/// </summary>
public sealed class V1ArticleTests
{
    private const string Articles = "/api/v1/articles/";
    private const string MarginNotes = Articles + "a-first-look-at-margin-notes";
    private const string EncodedSlug = "%d9%85%d8%b7%d8%a7%d9%84%d8%b9%db%81-%d9%86%d9%88%d9%b9%d8%b3";

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

    private async Task<HttpResponseMessage> GetWithAsync(string url, string header, string value)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        request.Headers.TryAddWithoutValidation(header, value);
        return await client.SendAsync(request);
    }

    private static string Header(HttpResponseMessage response, string name) =>
        response.Headers.TryGetValues(name, out var values) || response.Content.Headers.TryGetValues(name, out values) ? string.Join(", ", values) : string.Empty;

    private static string[] Slugs(JsonElement items) => [.. items.EnumerateArray().Select(item => item.GetProperty("slug").GetString()!)];

    [Test]
    public async Task An_article_needs_no_sign_in_and_has_its_fields_in_the_website_s_order()
    {
        var (response, body) = await GetAsync(MarginNotes);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["success", "data", "meta"]));
        var data = body.GetProperty("data");
        Assert.That(data.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])
            ["id", "slug", "title", "excerpt", "publishedDate", "modifiedDate", "author", "categories", "tags", "language", "readingTime", "content", "relatedArticles"]));
        Assert.That(data.GetProperty("id").GetInt32(), Is.EqualTo(1));
        Assert.That(data.GetProperty("slug").GetString(), Is.EqualTo("a-first-look-at-margin-notes"));
        Assert.That(data.GetProperty("title").GetString(), Is.EqualTo("A First Look at Margin Notes"));
        Assert.That(data.GetProperty("publishedDate").GetString(), Is.EqualTo("2024-05-10T08:15:00.000Z"));
        Assert.That(data.GetProperty("modifiedDate").GetString(), Is.EqualTo("2024-05-12T09:00:00.000Z"));
        Assert.That(data.GetProperty("categories").GetRawText(), Is.EqualTo("""["note-taking"]"""));
        Assert.That(data.GetProperty("tags").GetRawText(), Is.EqualTo("""["Study Skills"]"""));
        Assert.That(data.GetProperty("content").GetString(), Does.Contain("<h2>Why margins matter</h2>"));
        Assert.That(body.GetProperty("meta").GetProperty("cache").GetProperty("maxAge").GetInt32(), Is.EqualTo(3600));
    }

    [Test]
    public async Task An_article_sends_the_cache_headers_with_its_own_last_change()
    {
        var (response, _) = await GetAsync(MarginNotes);

        Assert.That(Header(response, "Cache-Control"), Is.EqualTo("public, max-age=3600, stale-while-revalidate=86400"));
        Assert.That(Header(response, "ETag"), Does.Match("^\"[0-9a-f]{32}\"$"));
        Assert.That(Header(response, "Last-Modified"), Is.EqualTo("Sun, 12 May 2024 09:00:00 GMT"));
        Assert.That(Header(response, "Vary"), Is.EqualTo("Accept-Encoding"));
        Assert.That(Header(response, "Access-Control-Allow-Origin"), Is.EqualTo("*"));
    }

    [Test]
    public async Task Related_are_the_five_highest_scores_a_shared_category_counting_two_and_ties_newest_first()
    {
        var (_, body) = await GetAsync(MarginNotes);

        var related = body.GetProperty("data").GetProperty("relatedArticles");
        Assert.That(Slugs(related), Is.EqualTo((string[])
            ["building-a-weekly-summary-page", "choosing-a-quiet-hour", "drafting-questions-before-a-lesson", "every-table-tells-a-story", "finding-the-main-idea"]));
        // A related article is a list item: no body, and the list's reading time of 1.
        Assert.That(related[0].GetRawText(), Is.EqualTo(
            """{"id":2,"slug":"building-a-weekly-summary-page","title":"Building a Weekly Summary Page","excerpt":"How one page written at the end of the week can gather the main points of every lesson.","publishedDate":"2022-02-14T06:30:00.000Z","modifiedDate":"2022-02-14T06:30:00.000Z","author":"admin","categories":["note-taking","practice"],"tags":["Study Skills","Summaries"],"language":"en","readingTime":1}"""));
    }

    [Test]
    public async Task Related_are_filled_up_to_five_with_articles_that_share_nothing_newest_first()
    {
        // The timetable article shares its one category with two others and its tag with none: the other three score 0 (a kept quirk of today's website).
        var (_, body) = await GetAsync(Articles + "the-zorvath-timetable");

        Assert.That(Slugs(body.GetProperty("data").GetProperty("relatedArticles")), Is.EqualTo((string[])
            ["drafting-questions-before-a-lesson", "building-a-weekly-summary-page", "term-planner-for-next-year", "choosing-a-quiet-hour", "every-table-tells-a-story"]));
    }

    [Test]
    public async Task The_reading_time_is_computed_from_the_body_and_an_absent_field_is_left_out()
    {
        var body = string.Join(' ', Enumerable.Repeat("word", 401));
        await TestDatabase.ExecuteAsync($"""
            insert into content.published_articles (slug, slug_decoded, title, body_markdown, body_html, published_at, published_date_text, author, language, reading_minutes, categories, tags)
            values ('bare-one', 'bare-one', 'Bare', '{body}', '<p>x</p>', '1999-01-01T00:00:00Z', '1999-01-01T00:00:00.000Z', 'admin', 'en', 3, array[]::text[], array[]::text[])
            """);
        try
        {
            var (response, answer) = await GetAsync(Articles + "bare-one");

            var data = answer.GetProperty("data");
            Assert.That(data.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])
                ["id", "slug", "title", "publishedDate", "author", "categories", "tags", "language", "readingTime", "content", "relatedArticles"]));
            Assert.That(data.GetProperty("id").GetInt32(), Is.Zero);
            Assert.That(data.GetProperty("readingTime").GetInt32(), Is.EqualTo(3));
            Assert.That(data.GetProperty("relatedArticles").GetArrayLength(), Is.EqualTo(5));
            // No modified date: the published one.
            Assert.That(Header(response, "Last-Modified"), Is.EqualTo("Fri, 01 Jan 1999 00:00:00 GMT"));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("delete from content.published_articles where slug = 'bare-one'");
        }
    }

    [Test]
    public async Task A_percent_encoded_slug_opens_as_written_and_as_the_characters_it_stands_for()
    {
        var (asWritten, first) = await GetAsync(Articles + EncodedSlug);
        var (upperCase, second) = await GetAsync(Articles + EncodedSlug.ToUpperInvariant());
        var (characters, third) = await GetAsync(Articles + Uri.UnescapeDataString(EncodedSlug));

        Assert.That(asWritten.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(upperCase.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(characters.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        // The slug in the answer is the file's own text, whichever way it was asked.
        Assert.That(first.GetProperty("data").GetProperty("slug").GetString(), Is.EqualTo(EncodedSlug));
        Assert.That(second.GetProperty("data").GetProperty("slug").GetString(), Is.EqualTo(EncodedSlug));
        Assert.That(third.GetProperty("data").GetProperty("slug").GetString(), Is.EqualTo(EncodedSlug));
    }

    [Test]
    public async Task The_raw_html_article_opens_without_anything_that_could_run()
    {
        var (response, body) = await GetAsync(Articles + "every-table-tells-a-story");

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        var content = body.GetProperty("data").GetProperty("content").GetString()!;
        Assert.That(content, Does.Contain("<h2>Rows and columns</h2>").And.Contain("href=\"/articles/a-first-look-at-margin-notes\""));
        Assert.That(content, Does.Not.Contain("<script").IgnoreCase.And.Not.Contain("onerror=").IgnoreCase.And.Not.Contain("javascript:").IgnoreCase);
        // The file's own Markdown, raw HTML and all, is not sent.
        Assert.That(body.GetProperty("data").TryGetProperty("rawContent", out _), Is.False);
    }

    [TestCase("no-such-article", "no-such-article")]
    [TestCase("unfinished-outline-on-margin-notes", "unfinished-outline-on-margin-notes")]
    [TestCase("working-draft-on-revision-cycles", "working-draft-on-revision-cycles")]
    [TestCase("A-First-Look-At-Margin-Notes", "A-First-Look-At-Margin-Notes")]
    [TestCase("a-first-look-at-margin-notes%20", "a-first-look-at-margin-notes ")]
    [TestCase("%20", " ")]
    [TestCase("a'%20or%20'1'='1", "a' or '1'='1")]
    [TestCase("%25", "%")]
    [TestCase("%3Cb%3E%22%5C", "<b>\"\\")]
    public async Task An_unknown_or_unpublished_slug_is_a_404_that_echoes_only_the_slug_asked(string asked, string echoed)
    {
        var (response, body) = await GetAsync(Articles + asked);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(body.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["success", "error", "meta"]));
        Assert.That(body.GetProperty("success").GetBoolean(), Is.False);
        Assert.That(body.GetProperty("error").EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["code", "message"]));
        Assert.That(body.GetProperty("error").GetProperty("code").GetString(), Is.EqualTo("NOT_FOUND"));
        Assert.That(body.GetProperty("error").GetProperty("message").GetString(), Is.EqualTo("Article not found: " + echoed));
        Assert.That(body.GetProperty("meta").GetProperty("cache").GetProperty("maxAge").GetInt32(), Is.Zero);
        Assert.That(Header(response, "ETag") + Header(response, "Cache-Control") + Header(response, "Last-Modified"), Is.Empty);
        Assert.That(Header(response, "Access-Control-Allow-Origin"), Is.EqualTo("*"));
    }

    // Bytes that are no text, and characters that hide: each is only an unknown article. (A NUL never reaches a route: the server answers 400 to such a path; v1-article.hurl.)
    [TestCase("%ff%fe")]
    [TestCase("%ED%A0%80")]
    [TestCase("%E2%80%AE%EF%BB%BF")]
    public async Task A_slug_no_article_can_have_is_a_404_never_a_500(string asked)
    {
        var (response, body) = await GetAsync(Articles + asked);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(body.GetProperty("error").GetProperty("code").GetString(), Is.EqualTo("NOT_FOUND"));
    }

    [Test]
    public async Task A_slug_of_7000_characters_is_a_404()
    {
        var (response, body) = await GetAsync(Articles + new string('a', 7000));

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(body.GetProperty("error").GetProperty("message").GetString(), Has.Length.EqualTo("Article not found: ".Length + 7000));
    }

    [Test]
    public async Task The_199_character_slug_opens()
    {
        var slug = "keeping-long-titles-readable-when-a-heading-runs-past-the-edge-of-the-page-and-the-reader-still-needs-to-find-the-one-idea-that-matters-most-in-a-crowded-set-of-lesson-notes-written-across-a-full-ter";

        var (response, body) = await GetAsync(Articles + slug);

        Assert.That(slug, Has.Length.EqualTo(199));
        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.GetProperty("data").GetProperty("slug").GetString(), Is.EqualTo(slug));
    }

    [Test]
    public async Task A_matching_if_none_match_is_a_304_without_a_body_and_another_value_or_article_is_a_200()
    {
        var (first, _) = await GetAsync(MarginNotes);
        var etag = Header(first, "ETag");

        var same = await GetWithAsync(MarginNotes, "If-None-Match", etag);
        var other = await GetWithAsync(MarginNotes, "If-None-Match", "\"0123456789abcdef0123456789abcdef\"");
        var otherArticle = await GetWithAsync(Articles + "choosing-a-quiet-hour", "If-None-Match", etag);
        var unknown = await GetWithAsync(Articles + "no-such-article", "If-None-Match", etag);

        Assert.That(same.StatusCode, Is.EqualTo(HttpStatusCode.NotModified));
        Assert.That(await same.Content.ReadAsByteArrayAsync(), Is.Empty);
        Assert.That(other.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(otherArticle.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(unknown.StatusCode, Is.EqualTo(HttpStatusCode.NotFound));
    }

    // The article's Last-Modified is 12 May 2024 09:00:00 GMT. tsr-web: 304 when it is not newer than the date sent.
    [TestCase("Sun, 12 May 2024 09:00:00 GMT", HttpStatusCode.NotModified)]
    [TestCase("Sun, 12 May 2024 08:59:59 GMT", HttpStatusCode.OK)]
    public async Task If_modified_since_is_a_304_when_the_article_is_not_newer(string since, HttpStatusCode status)
    {
        var response = await GetWithAsync(MarginNotes, "If-Modified-Since", since);

        Assert.That(response.StatusCode, Is.EqualTo(status));
    }

    // RFC 9110 section 13.1.3: a request that carries If-None-Match is judged by it alone, so a cache holding an old copy
    // of a corrected article (old ETag, a date that still passes) gets the new text. The date sent is the article's own Last-Modified.
    [TestCase("\"0123456789abcdef0123456789abcdef\"", HttpStatusCode.OK)]
    [TestCase(null, HttpStatusCode.NotModified)]
    public async Task If_none_match_is_judged_alone_when_if_modified_since_comes_with_it(string? sentTag, HttpStatusCode status)
    {
        var (first, _) = await GetAsync(MarginNotes);
        using var request = new HttpRequestMessage(HttpMethod.Get, MarginNotes);
        request.Headers.TryAddWithoutValidation("If-None-Match", sentTag ?? Header(first, "ETag"));
        request.Headers.TryAddWithoutValidation("If-Modified-Since", "Sun, 12 May 2024 09:00:00 GMT");

        var response = await client.SendAsync(request);

        Assert.That(response.StatusCode, Is.EqualTo(status));
        Assert.That(await response.Content.ReadAsByteArrayAsync(), status == HttpStatusCode.OK ? Is.Not.Empty : Is.Empty);
    }
}
