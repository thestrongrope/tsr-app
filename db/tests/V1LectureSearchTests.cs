using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// <c>GET /api/v1/lectures/search</c> with no Elasticsearch (the test API has none configured): there is no fallback, so a search or a browse is the website's 500 (SRCH-R12), while the bounds are a 400 before the engine is asked, article search still answers from the database, and the API
/// started without the engine or the embedding service (SRCH-Q6). The engine paths are proven by the unit tests (the bodies, the fusion, the failures) and by <c>v1-lecture-search.hurl</c> on a stack that has the engine.
/// </summary>
public sealed class V1LectureSearchTests
{
    private const string Route = "/api/v1/lectures/search";

    private WebApplicationFactory<Program> factory = null!;
    private HttpClient client = null!;

    [OneTimeSetUp]
    public void Start()
    {
        factory = TestApi.Create();
        client = factory.CreateClient();
    }

    [OneTimeTearDown]
    public void Stop()
    {
        client.Dispose();
        factory.Dispose();
    }

    [TestCase("")]
    [TestCase("?q=patience")]
    [TestCase("?q=%20&language=hi")]
    public async Task Without_the_engine_a_search_and_a_browse_are_the_websites_500_with_nothing_of_the_failure(string query)
    {
        var response = await client.GetAsync(Route + query);
        var text = await response.Content.ReadAsStringAsync();

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.InternalServerError));
        using var document = JsonDocument.Parse(text);
        Assert.That(document.RootElement.GetProperty("error").GetRawText(), Is.EqualTo("""{"code":"INTERNAL_ERROR","message":"An unexpected error occurred"}"""));
        Assert.That(text, Does.Not.Contain("Elasticsearch").And.Not.Contain("configured"));
        Assert.That(response.Headers.Contains("Cache-Control"), Is.False);
    }

    [TestCase("?offset=9990", "Result window too large: offset plus limit must not exceed 10000")]
    [TestCase("?limit=100&offset=9901&q=x", "Result window too large: offset plus limit must not exceed 10000")]
    public async Task A_page_past_the_result_window_is_a_400_before_the_engine_is_asked(string query, string message)
    {
        var response = await client.GetAsync(Route + query);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.BadRequest));
        Assert.That(await response.Content.ReadAsStringAsync(), Does.Contain(message));
    }

    [TestCase("?language=abcdefghijk")]
    [TestCase("?q=x&language=h%20i")]
    [TestCase("?language=%E0%A4%B9%E0%A4%BF")]
    public async Task A_language_that_is_not_a_short_code_is_a_400_before_the_engine_is_asked(string query)
    {
        var response = await client.GetAsync(Route + query);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.BadRequest));
        Assert.That(await response.Content.ReadAsStringAsync(), Does.Contain("Invalid language: at most 10 letters and hyphens"));
    }

    [Test]
    public async Task A_text_of_201_characters_is_a_400_and_one_of_200_is_not()
    {
        var long201 = await client.GetAsync(Route + "?q=" + new string('a', 201));
        var long200 = await client.GetAsync(Route + "?q=" + new string('a', 200));

        Assert.That(long201.StatusCode, Is.EqualTo(HttpStatusCode.BadRequest));
        Assert.That(await long201.Content.ReadAsStringAsync(), Does.Contain("Query too long: at most 200 characters"));
        Assert.That(long200.StatusCode, Is.EqualTo(HttpStatusCode.InternalServerError), "past the bounds, so it reached the engine, which is not there");
    }

    [Test]
    public async Task The_api_answers_without_the_engine_or_the_embedding_service_and_article_search_still_works_from_the_database()
    {
        var health = await client.GetAsync("/health");
        var articles = await client.GetAsync("/api/v1/search?q=zorvath");
        using var body = JsonDocument.Parse(await articles.Content.ReadAsStringAsync());

        Assert.That(health.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(articles.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.RootElement.GetProperty("data").GetProperty("searchEngine").GetString(), Is.EqualTo("fuse"));
    }
}
