using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.IdentityModel.Tokens;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// POST /auth/debug-token: never served in Production (404 before the token is looked at), and elsewhere it echoes the claims of the caller's own verified token and nothing else.
/// The Production host is built with the environment set to Production explicitly; the "environment not set" case cannot be built here because WebApplicationFactory defaults to
/// Development, so that case rests on the host's default (Production when ASPNETCORE_ENVIRONMENT is unset, ASP.NET Core's documented behaviour) and the code path is the same IsProduction() check.
/// </summary>
public sealed class TestDebugTokenTests
{
    private const string Project = "demo-tsr-test";

    private static readonly string[] Keys = ["status", "email", "uid", "name", "provider"];

    private static string Unsigned(Dictionary<string, object> claims, string project = Project)
    {
        claims["iss"] = "https://securetoken.google.com/" + project;
        claims["aud"] = project;
        claims.TryAdd("sub", "uid-debug");
        claims["exp"] = DateTimeOffset.UtcNow.AddMinutes(30).ToUnixTimeSeconds();
        claims["iat"] = DateTimeOffset.UtcNow.AddMinutes(-1).ToUnixTimeSeconds();
        return Encode("""{"alg":"none","typ":"JWT"}""") + "." + Encode(JsonSerializer.Serialize(claims)) + ".";
    }

    private static string Encode(string text) => Base64UrlEncoder.Encode(Encoding.UTF8.GetBytes(text));

    private static async Task<(HttpStatusCode Status, JsonElement Body)> PostAsync(WebApplicationFactory<Program> factory, string? authorization)
    {
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Post, "/auth/debug-token");
        if (authorization is not null)
        {
            request.Headers.TryAddWithoutValidation("Authorization", authorization);
        }

        using var response = await client.SendAsync(request);
        var text = await response.Content.ReadAsStringAsync();
        return (response.StatusCode, JsonSerializer.Deserialize<JsonElement>(text));
    }

    private static Dictionary<string, object> Claims(string? name = "Synthetic Person") =>
        new()
        {
            ["sub"] = "uid-debug",
            ["email"] = "debug@example.invalid",
            ["name"] = name!,
            ["firebase"] = new Dictionary<string, object> { ["sign_in_provider"] = "google.com", ["identities"] = new Dictionary<string, object> { ["email"] = new[] { "debug@example.invalid" } } },
        };

    [Test]
    public async Task In_Production_it_is_404_not_found_even_with_a_valid_token_and_before_the_token_is_looked_at()
    {
        await using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Production");
            builder.UseSetting("TSR_DB", TestDatabase.AppConnection);
            builder.UseSetting("TSR_FIREBASE_PROJECT_ID", "tsr-test-production");
            builder.UseSetting("TSR_GOTENBERG_URL", "http://gotenberg.invalid:3000");
        });

        var withToken = await PostAsync(factory, "Bearer " + Unsigned(Claims()));
        var withoutToken = await PostAsync(factory, null);
        var garbage = await PostAsync(factory, "Bearer garbage");

        foreach (var (status, body) in new[] { withToken, withoutToken, garbage })
        {
            Assert.That(status, Is.EqualTo(HttpStatusCode.NotFound));
            Assert.That(body.GetProperty("detail").GetString(), Is.EqualTo("Not found"));
            Assert.That(body.GetRawText(), Does.Not.Contain("debug@example.invalid"));
        }
    }

    [Test]
    public async Task Outside_Production_it_echoes_the_callers_own_email_uid_and_name_and_a_null_provider_as_PHP_does()
    {
        await using var factory = TestApi.Create();

        var (status, body) = await PostAsync(factory, "Bearer " + Unsigned(Claims()));

        Assert.That(status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.EnumerateObject().Select(p => p.Name), Is.EquivalentTo(Keys));
        Assert.That(body.GetProperty("status").GetString(), Is.EqualTo("success"));
        Assert.That(body.GetProperty("email").GetString(), Is.EqualTo("debug@example.invalid"));
        Assert.That(body.GetProperty("uid").GetString(), Is.EqualTo("uid-debug"));
        Assert.That(body.GetProperty("name").GetString(), Is.EqualTo("Synthetic Person"));
        Assert.That(body.GetProperty("provider").ValueKind, Is.EqualTo(JsonValueKind.Null), "PHP always answers null here: its verifier hands on no firebase claim, so sign_in_provider is never read (a PHP bug copied; the decision is in the lane notes)");
    }

    [Test]
    public async Task A_token_without_the_optional_claims_gives_nulls_for_them_not_missing_keys()
    {
        await using var factory = TestApi.Create();
        var claims = new Dictionary<string, object> { ["sub"] = "uid-bare" };

        var (status, body) = await PostAsync(factory, "Bearer " + Unsigned(claims));

        Assert.That(status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.GetProperty("uid").GetString(), Is.EqualTo("uid-bare"));
        Assert.That(body.GetProperty("email").ValueKind, Is.EqualTo(JsonValueKind.Null));
        Assert.That(body.GetProperty("name").ValueKind, Is.EqualTo(JsonValueKind.Null));
        Assert.That(body.GetProperty("provider").ValueKind, Is.EqualTo(JsonValueKind.Null));
    }

    [Test]
    public async Task It_reads_nothing_from_the_database_and_writes_nothing_so_a_token_with_no_member_still_answers()
    {
        await using var factory = TestApi.Create();
        var before = await TestDeletionKit.WholeDatabaseAsync();

        var (status, _) = await PostAsync(factory, "Bearer " + Unsigned(Claims()));

        Assert.That(status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(await TestDeletionKit.WholeDatabaseAsync(), Is.EqualTo(before));
    }

    [TestCase(null, "Not authenticated")]
    [TestCase("", "Not authenticated")]
    [TestCase("Basic abc", "Not authenticated")]
    [TestCase("Bearer", "Not authenticated")]
    [TestCase("Bearer not-a-jwt", "Invalid auth token")]
    public async Task A_missing_or_odd_header_is_401_not_authenticated_and_a_bad_token_is_401_invalid(string? header, string detail)
    {
        await using var factory = TestApi.Create();

        var (status, body) = await PostAsync(factory, header);

        Assert.That(status, Is.EqualTo(HttpStatusCode.Unauthorized));
        Assert.That(body.GetProperty("detail").GetString(), Is.EqualTo(detail));
    }

    [Test]
    public async Task A_token_for_another_project_is_401_invalid_auth_token()
    {
        await using var factory = TestApi.Create();
        var token = Unsigned(Claims(), "some-other-project");

        var (status, body) = await PostAsync(factory, "Bearer " + token);

        Assert.That(status, Is.EqualTo(HttpStatusCode.Unauthorized));
        Assert.That(body.GetProperty("detail").GetString(), Is.EqualTo("Invalid auth token"));
    }
}
