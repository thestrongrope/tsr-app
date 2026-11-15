using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Npgsql;
using NUnit.Framework;

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
}
