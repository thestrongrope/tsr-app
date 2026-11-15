using System.Globalization;
using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using NUnit.Framework;
using Tsr.Content.Api;
using Tsr.Content.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>
/// The answer shape of the <c>/api/v1/</c> routes (<c>V1</c>) and <c>GET /api/v1/articles</c>, the API in process over the synthetic set of db/synthetic/content.
/// The rule is tsr-web's <c>web/src/app/api/v1/articles/route.ts</c> and the helpers it calls. Filters, orders and paging over the same set: <c>v1-articles.hurl</c>.
/// </summary>
public sealed class V1ArticlesTests
{
    private const string List = "/api/v1/articles";

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
        var outcome = await ContentRefresh.TickAsync(scope.ServiceProvider.GetRequiredService<ContentContext>(), directory, TimeProvider.System, NullLogger.Instance, CancellationToken.None);
        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Refreshed));
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

    [Test]
    public async Task The_list_needs_no_sign_in_and_answers_in_the_v1_shape()
    {
        var before = DateTimeOffset.UtcNow.AddSeconds(-1);

        var (response, body) = await GetAsync(List);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["success", "data", "meta", "pagination"]));
        Assert.That(body.GetProperty("success").GetBoolean(), Is.True);
        Assert.That(body.GetProperty("data").GetArrayLength(), Is.EqualTo(12));
        Assert.That(body.GetProperty("pagination").GetRawText(), Is.EqualTo("""{"total":12,"limit":20,"offset":0,"hasMore":false}"""));
        var meta = body.GetProperty("meta");
        Assert.That(meta.GetProperty("version").GetString(), Is.EqualTo("1.0"));
        Assert.That(meta.GetProperty("cache").GetProperty("maxAge").GetInt32(), Is.EqualTo(300));
        // JavaScript's toISOString: milliseconds and "Z".
        const string IsoShape = "yyyy-MM-dd'T'HH:mm:ss.fff'Z'";
        var styles = DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal;
        var timestamp = DateTimeOffset.ParseExact(meta.GetProperty("timestamp").GetString()!, IsoShape, CultureInfo.InvariantCulture, styles);
        var expires = DateTimeOffset.ParseExact(meta.GetProperty("cache").GetProperty("expires").GetString()!, IsoShape, CultureInfo.InvariantCulture, styles);
        Assert.That(timestamp, Is.InRange(before, DateTimeOffset.UtcNow.AddSeconds(1)));
        Assert.That(expires - timestamp, Is.EqualTo(TimeSpan.FromSeconds(300)));
    }

    [Test]
    public async Task The_list_sends_the_cache_and_cross_origin_headers()
    {
        var (response, _) = await GetAsync(List);

        Assert.That(Header(response, "Content-Type"), Is.EqualTo("application/json"));
        Assert.That(Header(response, "Cache-Control"), Is.EqualTo("public, max-age=300, stale-while-revalidate=600"));
        Assert.That(Header(response, "ETag"), Does.Match("^\"[0-9a-f]{32}\"$"));
        Assert.That(Header(response, "Vary"), Is.EqualTo("Accept-Encoding"));
        Assert.That(Header(response, "Access-Control-Allow-Origin"), Is.EqualTo("*"));
        // The newest modifiedDate of all published articles: the future-dated one.
        Assert.That(Header(response, "Last-Modified"), Is.EqualTo("Sat, 01 Mar 2031 00:00:00 GMT"));
    }

    [Test]
    public async Task An_item_has_the_list_fields_with_id_zero_when_the_file_has_none_and_reading_time_one()
    {
        var (_, body) = await GetAsync(List + "?sort=publishedDate:asc&limit=2");

        var oldest = body.GetProperty("data")[0];
        Assert.That(oldest.GetRawText(), Is.EqualTo(
            """{"id":0,"slug":"glossary-habits-for-new-terms","title":"Glossary Habits for New Terms","excerpt":"Keeping a running list of new terms, each with a one line meaning in your own words.","publishedDate":"2021-09-12T14:00:00","modifiedDate":"2021-09-13T08:30:00","author":"admin","categories":["core-terms","foundations"],"tags":["Study Skills","Glossary"],"language":"en","readingTime":1}"""));
        Assert.That(body.GetProperty("data")[1].GetProperty("id").GetInt32(), Is.EqualTo(2));
    }

    [Test]
    public async Task An_absent_excerpt_and_modified_date_are_left_out_and_text_in_any_script_is_sent_unescaped()
    {
        await TestDatabase.ExecuteAsync("""
            insert into content.published_articles (slug, slug_decoded, title, body_markdown, body_html, published_at, published_date_text, author, language, reading_minutes, categories, tags)
            values ('bare-one', 'bare-one', 'عنوان <b> & "q"', 'a long body', '<p>a long body</p>', '1999-01-01T00:00:00Z', '1999-01-01T00:00:00.000Z', 'admin', 'en', 9, '{}', '{}')
            """);
        try
        {
            var response = await client.GetAsync(List + "?sort=publishedDate:asc&limit=1");

            Assert.That(await response.Content.ReadAsStringAsync(), Does.Contain(
                """
                "data":[{"id":0,"slug":"bare-one","title":"عنوان <b> & \"q\"","publishedDate":"1999-01-01T00:00:00.000Z","author":"admin","categories":[],"tags":[],"language":"en","readingTime":1}]
                """.Trim()));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("delete from content.published_articles where slug = 'bare-one'");
        }
    }

    [Test]
    public async Task An_unknown_sort_is_a_400_in_the_v1_error_shape_without_cache_headers()
    {
        var (response, body) = await GetAsync(List + "?sort=views:desc");

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.BadRequest));
        Assert.That(body.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["success", "error", "meta"]));
        Assert.That(body.GetProperty("success").GetBoolean(), Is.False);
        Assert.That(body.GetProperty("error").GetRawText(), Is.EqualTo(
            """{"code":"VALIDATION_ERROR","message":"Invalid sort parameter. Valid options: publishedDate:asc, publishedDate:desc, title:asc, title:desc"}"""));
        Assert.That(body.GetProperty("meta").GetProperty("version").GetString(), Is.EqualTo("1.0"));
        Assert.That(body.GetProperty("meta").GetProperty("cache").GetProperty("maxAge").GetInt32(), Is.Zero);
        Assert.That(Header(response, "ETag") + Header(response, "Cache-Control") + Header(response, "Last-Modified"), Is.Empty);
        Assert.That(Header(response, "Access-Control-Allow-Origin"), Is.EqualTo("*"));
    }

    [Test]
    public async Task An_unknown_sort_is_refused_even_with_a_validator_that_would_match()
    {
        var response = await GetWithAsync(List + "?sort=views:desc", "If-Modified-Since", "Sun, 01 Jan 2040 00:00:00 GMT");

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.BadRequest));
    }

    [Test]
    public async Task The_etag_is_the_same_for_the_same_answer_and_differs_with_the_data_or_the_paging()
    {
        var (first, firstBody) = await GetAsync(List + "?limit=5");
        await Task.Delay(5);
        var (second, secondBody) = await GetAsync(List + "?limit=5");
        var (otherPage, _) = await GetAsync(List + "?limit=5&offset=5");
        var (otherLimit, _) = await GetAsync(List + "?limit=20");
        var (sameDataOtherPaging, _) = await GetAsync(List + "?limit=100");

        Assert.That(secondBody.GetProperty("meta").GetProperty("timestamp").GetString(), Is.Not.EqualTo(firstBody.GetProperty("meta").GetProperty("timestamp").GetString()));
        Assert.That(Header(second, "ETag"), Is.EqualTo(Header(first, "ETag")));
        Assert.That(Header(otherPage, "ETag"), Is.Not.EqualTo(Header(first, "ETag")));
        Assert.That(Header(sameDataOtherPaging, "ETag"), Is.Not.EqualTo(Header(otherLimit, "ETag")));
    }

    [Test]
    public async Task A_matching_if_none_match_is_a_304_without_a_body_and_another_value_is_a_200()
    {
        var (first, _) = await GetAsync(List);
        var etag = Header(first, "ETag");

        var same = await GetWithAsync(List, "If-None-Match", etag);
        var other = await GetWithAsync(List, "If-None-Match", "\"0123456789abcdef0123456789abcdef\"");
        var otherRequest = await GetWithAsync(List + "?limit=5", "If-None-Match", etag);

        Assert.That(same.StatusCode, Is.EqualTo(HttpStatusCode.NotModified));
        Assert.That(await same.Content.ReadAsByteArrayAsync(), Is.Empty);
        Assert.That(Header(same, "Access-Control-Allow-Origin"), Is.EqualTo("*"));
        Assert.That(other.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(otherRequest.StatusCode, Is.EqualTo(HttpStatusCode.OK));
    }

    // The set's Last-Modified is 1 Mar 2031 00:00:00 GMT. tsr-web: 304 when it is not newer than the date sent; a date that cannot be read is ignored.
    [TestCase("Sat, 01 Mar 2031 00:00:00 GMT", HttpStatusCode.NotModified)]
    [TestCase("Sun, 02 Mar 2031 00:00:00 GMT", HttpStatusCode.NotModified)]
    [TestCase("Fri, 28 Feb 2031 23:59:59 GMT", HttpStatusCode.OK)]
    [TestCase("not a date", HttpStatusCode.OK)]
    public async Task If_modified_since_is_a_304_when_nothing_is_newer(string since, HttpStatusCode status)
    {
        var response = await GetWithAsync(List, "If-Modified-Since", since);

        Assert.That(response.StatusCode, Is.EqualTo(status));
    }

    // PostgreSQL text cannot hold a NUL, so no article can match such a value: an empty page, as today's website answers, never a failure.
    [TestCase("q=%00")]
    [TestCase("q=zor%00vath")]
    [TestCase("category=%00")]
    [TestCase("category=note-taking%00")]
    [TestCase("tag=%00")]
    [TestCase("tag=Night%00Reading")]
    [TestCase("locale=%00")]
    [TestCase("locale=en%00")]
    [TestCase("q=zorvath&category=%00")]
    public async Task A_nul_in_a_filter_value_matches_nothing(string filter)
    {
        var (response, body) = await GetAsync(List + "?" + filter);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.GetProperty("data").GetArrayLength(), Is.Zero);
        Assert.That(body.GetProperty("pagination").GetRawText(), Is.EqualTo("""{"total":0,"limit":20,"offset":0,"hasMore":false}"""));
        // The set's own newest change, as for any other filter that matches nothing.
        Assert.That(Header(response, "Last-Modified"), Is.EqualTo("Sat, 01 Mar 2031 00:00:00 GMT"));
    }

    // A NUL in an option that never reaches the database is read as any other text.
    [TestCase("sort=title:asc%00", HttpStatusCode.BadRequest)]
    [TestCase("limit=5%00", HttpStatusCode.OK)]
    [TestCase("offset=%00", HttpStatusCode.OK)]
    public async Task A_nul_in_another_option_is_no_failure(string option, HttpStatusCode status)
    {
        var response = await client.GetAsync(List + "?" + option);

        Assert.That(response.StatusCode, Is.EqualTo(status));
    }

    /// <summary>Articles of this test only, found by a tag no content file has, so the order is asserted whatever else the table holds.</summary>
    private static async Task<IAsyncDisposable> ProbeArticlesAsync(params (string Slug, string Title, string PublishedAt)[] articles)
    {
        foreach (var (slug, title, publishedAt) in articles)
        {
            await TestDatabase.ExecuteAsync($"""
                insert into content.published_articles (slug, slug_decoded, title, body_markdown, body_html, published_at, published_date_text, author, language, reading_minutes, categories, tags)
                values ('{slug}', '{slug}', '{title}', 'a body', '<p>a body</p>', '{publishedAt}', '{publishedAt}', 'admin', 'en', 1, '{"{}"}', '{"{" + ProbeTag + "}"}')
                """);
        }

        return new ProbeCleanup();
    }

    private const string ProbeTag = "order-probe";

    private sealed class ProbeCleanup : IAsyncDisposable
    {
        public async ValueTask DisposeAsync() =>
            await TestDatabase.ExecuteAsync($"delete from content.published_articles where tags @> array['{ProbeTag}']");
    }

    private async Task<string[]> ProbeSlugsAsync(string sort)
    {
        var (_, body) = await GetAsync(List + "?tag=" + ProbeTag + "&sort=" + sort);
        return [.. body.GetProperty("data").EnumerateArray().Select(item => item.GetProperty("slug").GetString()!)];
    }

    // tsr-web sorts the newest-first list with a stable sort, so equal titles stay newest first in both directions. The slugs are in the other order, so the date decides.
    [TestCase("title:asc")]
    [TestCase("title:desc")]
    public async Task Equal_titles_come_newest_first_in_both_directions_of_the_title_order(string sort)
    {
        await using var probe = await ProbeArticlesAsync(
            ("probe-a-older", "Probe Same Title", "2020-01-01T00:00:00Z"),
            ("probe-z-newer", "Probe Same Title", "2020-01-03T00:00:00Z"),
            ("probe-m-middle", "Probe Same Title", "2020-01-02T00:00:00Z"));

        Assert.That(await ProbeSlugsAsync(sort), Is.EqualTo((string[])["probe-z-newer", "probe-m-middle", "probe-a-older"]));
    }

    // JavaScript's localeCompare, here the "en-x-icu" collation: letters first, case and accents only break ties. In byte order the capitals would lead
    // ("Banana", "Zebra", "apple", "cherry", "éclair") and the accented letter would come last.
    [Test]
    public async Task Titles_differing_in_case_or_accent_sort_as_a_dictionary_does_not_in_byte_order()
    {
        await using var probe = await ProbeArticlesAsync(
            ("probe-zebra", "Zebra", "2020-01-01T00:00:00Z"),
            ("probe-eclair", "éclair", "2020-01-02T00:00:00Z"),
            ("probe-cherry", "cherry", "2020-01-03T00:00:00Z"),
            ("probe-banana", "Banana", "2020-01-04T00:00:00Z"),
            ("probe-apple", "apple", "2020-01-05T00:00:00Z"));
        string[] dictionary = ["probe-apple", "probe-banana", "probe-cherry", "probe-eclair", "probe-zebra"];

        Assert.That(await ProbeSlugsAsync("title:asc"), Is.EqualTo(dictionary));
        Assert.That(await ProbeSlugsAsync("title:desc"), Is.EqualTo(dictionary.Reverse().ToArray()));
    }

    // tsr-web parseIntParam: JavaScript's parseInt (leading white space, a sign, then digits; the rest ignored), then clamped; nothing readable is the default.
    [TestCase(null, 20)]
    [TestCase("", 20)]
    [TestCase("abc", 20)]
    [TestCase("-", 20)]
    [TestCase(".5", 20)]
    [TestCase("5", 5)]
    [TestCase("+5", 5)]
    [TestCase("  7", 7)]
    [TestCase("12abc", 12)]
    [TestCase("1.9", 1)]
    [TestCase("1e3", 1)]
    [TestCase("0", 1)]
    [TestCase("-3", 1)]
    [TestCase("100", 100)]
    [TestCase("101", 100)]
    [TestCase("99999999999999999999999999", 100)]
    [TestCase("-99999999999999999999999999", 1)]
    public void A_number_is_read_as_javascript_reads_it_and_clamped(string? raw, int expected) =>
        Assert.That(V1.Int(raw, 20, 1, 100), Is.EqualTo(expected));

    [Test]
    public void A_number_without_an_upper_bound_stops_at_the_largest_integer() =>
        Assert.That(V1.Int("99999999999999999999999999", 0, 0), Is.EqualTo(int.MaxValue));
}
