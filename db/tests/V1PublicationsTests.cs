using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// <c>GET /api/v1/publications</c>, the API in process over the synthetic set of db/synthetic/content (LIB-R1, LIB-R15, LIB-R19).
/// The rule is tsr-web's <c>web/src/app/api/v1/publications/route.ts</c>. Over HTTP: <c>v1-publications.hurl</c>.
/// </summary>
public sealed class V1PublicationsTests
{
    private const string Publications = "/api/v1/publications";

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
    public async Task The_publications_come_in_file_order_with_site_relative_links_and_no_field_that_the_file_lacks()
    {
        var (response, body) = await GetAsync(Publications);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["success", "data", "meta", "pagination"]));
        // The entry with neither link (third in the file) is not here. A field the file lacks is left out, never null.
        Assert.That(body.GetProperty("data").GetRawText(), Is.EqualTo(
            """
            [{"title":"A Pocket Guide to Margin Notes","summary":"A short invented booklet on writing notes beside a text.","type":"PDF","size":"1 MB","updated":"Jun 26, 2025","language":"English","file":"/downloads/sample-publications/a-pocket-guide-to-margin-notes.pdf","downloadOnly":true},
            {"title":"ہفتہ وار منصوبہ کی کتاب","summary":"مطالعہ کے ہفتہ وار منصوبے پر ایک فرضی کتابچہ۔","type":"PDF","size":"617 KB","updated":"Apr 06, 2024","language":"Urdu","file":"/downloads/sample-publications/weekly-plan-booklet.pdf","readOnlineUrl":"/weekly-plan-booklet","downloadOnly":false},
            {"title":"Revision Cycles Handbook","summary":"An invented handbook on spacing revision, read online only.","type":"Web","size":"—","updated":"Mar 19, 2024","language":"English","readOnlineUrl":"/revision-cycles-handbook","downloadOnly":false}]
            """.ReplaceLineEndings(string.Empty)));
        // tsr-web: the page is the whole list, so the limit is the total.
        Assert.That(body.GetProperty("pagination").GetRawText(), Is.EqualTo("""{"total":3,"limit":3,"offset":0,"hasMore":false}"""));
    }

    [Test]
    public async Task The_publications_send_the_cache_headers_without_a_last_modified()
    {
        var (response, body) = await GetAsync(Publications);

        Assert.That(Header(response, "Cache-Control"), Is.EqualTo("public, max-age=3600, stale-while-revalidate=86400"));
        Assert.That(Header(response, "ETag"), Does.Match("^\"[0-9a-f]{32}\"$"));
        Assert.That(Header(response, "Last-Modified"), Is.Empty);
        Assert.That(Header(response, "Access-Control-Allow-Origin"), Is.EqualTo("*"));
        Assert.That(body.GetProperty("meta").GetProperty("cache").GetProperty("maxAge").GetInt32(), Is.EqualTo(3600));
    }

    // tsr-web: the whole language, any case; an empty value is no filter; the first value of a repeated option counts; other options are ignored.
    [TestCase("", 3)]
    [TestCase("?language=English", 2)]
    [TestCase("?language=english", 2)]
    [TestCase("?language=URDU", 1)]
    [TestCase("?language=Eng", 0)]
    [TestCase("?language=", 3)]
    [TestCase("?language=Urdu&language=English", 1)]
    [TestCase("?limit=1&offset=2&nonsense=1", 3)]
    public async Task The_language_filter_matches_the_whole_language_in_any_case(string query, int expected)
    {
        var (response, body) = await GetAsync(Publications + query);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.GetProperty("data").GetArrayLength(), Is.EqualTo(expected));
        var pagination = body.GetProperty("pagination");
        Assert.That((pagination.GetProperty("total").GetInt32(), pagination.GetProperty("limit").GetInt32()), Is.EqualTo((expected, expected)));
        Assert.That(pagination.GetProperty("hasMore").GetBoolean(), Is.False);
    }

    [Test]
    public async Task A_publication_without_a_language_is_only_in_the_unfiltered_list()
    {
        await TestDatabase.ExecuteAsync("insert into content.publications (position, title, file, download_only) values (99, 'No Language', '/downloads/sample-publications/no-language.pdf', false)");
        try
        {
            var (_, all) = await GetAsync(Publications);
            var (_, english) = await GetAsync(Publications + "?language=English");

            Assert.That(all.GetProperty("data")[3].GetRawText(), Is.EqualTo("""{"title":"No Language","file":"/downloads/sample-publications/no-language.pdf","downloadOnly":false}"""));
            Assert.That(english.GetProperty("data").GetArrayLength(), Is.EqualTo(2));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("delete from content.publications where position = 99");
        }
    }

    [Test]
    public async Task A_matching_etag_answers_304_with_no_body()
    {
        var (first, _) = await GetAsync(Publications);
        using var request = new HttpRequestMessage(HttpMethod.Get, Publications);
        request.Headers.TryAddWithoutValidation("If-None-Match", Header(first, "ETag"));

        var response = await client.SendAsync(request);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.NotModified));
        Assert.That(await response.Content.ReadAsByteArrayAsync(), Is.Empty);
    }
}
