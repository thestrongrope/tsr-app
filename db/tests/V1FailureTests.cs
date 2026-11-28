using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Content.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// An unexpected failure on a <c>/api/v1/</c> route answers in the v1 shape (tsr-web <c>errorResponse</c> for an unknown error: <c>INTERNAL_ERROR</c>), never the host's own 500.
/// The failure is real: this API is given a database name the server does not have (the setting <c>TSR_DB</c>), so every query of a route throws.
/// </summary>
public sealed class V1FailureTests
{
    private WebApplicationFactory<Program> factory = null!;
    private HttpClient client = null!;

    [OneTimeSetUp]
    public void Start()
    {
        var noSuchDatabase = new NpgsqlConnectionStringBuilder(TestDatabase.AppConnection) { Database = "no_such_database" }.ConnectionString;
        factory = TestApi.Create().WithWebHostBuilder(builder => builder.UseSetting("TSR_DB", noSuchDatabase));
        client = factory.CreateClient();
    }

    [OneTimeTearDown]
    public void Stop()
    {
        client.Dispose();
        factory.Dispose();
    }

    [TestCase("/api/v1/articles")]
    [TestCase("/api/v1/articles/a-first-look-at-margin-notes")]
    [TestCase("/api/v1/taxonomies/categories")]
    [TestCase("/api/v1/taxonomies/tags")]
    [TestCase("/api/v1/publications")]
    [TestCase("/api/v1/search?q=margin")]
    [TestCase("/api/v1/lectures/search?q=patience")]
    [TestCase("/api/v1/lectures/search")]
    public async Task An_unexpected_failure_is_a_500_in_the_v1_error_shape_without_cache_headers(string url)
    {
        var response = await client.GetAsync(url);
        var text = await response.Content.ReadAsStringAsync();

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.InternalServerError));
        Assert.That(response.Content.Headers.ContentType?.ToString(), Is.EqualTo("application/json"), text);
        using var document = JsonDocument.Parse(text);
        var body = document.RootElement;
        Assert.That(body.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["success", "error", "meta"]));
        Assert.That(body.GetProperty("success").GetBoolean(), Is.False);
        Assert.That(body.GetProperty("error").GetRawText(), Is.EqualTo("""{"code":"INTERNAL_ERROR","message":"An unexpected error occurred"}"""));
        Assert.That(body.GetProperty("meta").GetProperty("version").GetString(), Is.EqualTo("1.0"));
        Assert.That(body.GetProperty("meta").GetProperty("cache").GetProperty("maxAge").GetInt32(), Is.Zero);
        Assert.That(response.Headers.GetValues("Access-Control-Allow-Origin"), Is.EqualTo((string[])["*"]));
        Assert.That(response.Headers.GetValues("Access-Control-Allow-Methods"), Is.EqualTo((string[])["GET, POST, PUT, DELETE, OPTIONS"]));
        Assert.That(response.Headers.GetValues("X-Content-Type-Options"), Is.EqualTo((string[])["nosniff"]));
        Assert.That(response.Headers.Contains("ETag") || response.Headers.Contains("Cache-Control") || response.Content.Headers.Contains("Last-Modified"), Is.False);
        // Nothing of the failure reaches the caller.
        Assert.That(text, Does.Not.Contain("Npgsql").And.Not.Contain("no_such_database").And.Not.Contain("   at "));
    }

    [TestCase("/api/v1/search?q=patience&offset=10000", "Result window too large")]
    [TestCase("/api/v1/lectures/search?offset=10000", "Result window too large")]
    [TestCase("/api/v1/lectures/search?language=abcdefghijk", "Invalid language")]
    [TestCase("/api/v1/lectures/search?q=x&language=hi%22%7D", "Invalid language")]
    [TestCase("/api/v1/search?q=x&category=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "Category too long")]
    [TestCase("/api/v1/lectures/search?q=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "Query too long")]
    [TestCase("/api/v1/search?q=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "Query too long")]
    public async Task A_refused_search_is_a_400_before_the_database_is_asked(string url, string message)
    {
        // The database of this fixture does not exist: a 400 proves that no query was run.
        var response = await client.GetAsync(url);
        var text = await response.Content.ReadAsStringAsync();

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.BadRequest), text);
        Assert.That(text, Does.Contain(message));
    }

    [Test]
    public void Every_v1_endpoint_answers_failures_in_the_v1_shape()
    {
        var endpoints = factory.Services.GetServices<EndpointDataSource>()
            .SelectMany(source => source.Endpoints)
            .OfType<RouteEndpoint>()
            .Where(endpoint => endpoint.RoutePattern.RawText!.StartsWith("/api/v1/", StringComparison.Ordinal))
            .ToList();

        Assert.That(endpoints, Has.Count.EqualTo(8));
        Assert.That(
            endpoints.Where(endpoint => endpoint.Metadata.GetMetadata<WebsiteV1.FailureShape>() is null).Select(endpoint => endpoint.RoutePattern.RawText),
            Is.Empty,
            "map every /api/v1/ route with .WithV1Failures()");
    }
}
