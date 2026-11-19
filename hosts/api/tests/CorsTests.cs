using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// A browser lets a page on one origin call the API only when the API names that origin (issue 63). The setting TSR_CORS_ORIGINS lists
/// the origins; without it the API names none, which is how it ran before a web build of the app existed. The route used here, GET /me,
/// refuses a request without a sign-in before any lookup, so no database is needed: the permission is on the 401 as on any answer.
/// </summary>
public sealed class CorsTests
{
    private const string App = "https://app.example.test";
    private const string Other = "https://other.example.test";

    private static ApiHost HostAllowing(string origins) => new(new Dictionary<string, string> { [CorsSetting.Name] = origins });

    private static Dictionary<string, string> From(string origin) => new() { ["Origin"] = origin };

    private static Dictionary<string, string> PreflightFrom(string origin) => new()
    {
        ["Origin"] = origin,
        ["Access-Control-Request-Method"] = "PUT",
        ["Access-Control-Request-Headers"] = "authorization,content-type,x-app-version",
    };

    private static string? Header(HttpResponseMessage response, string name) =>
        response.Headers.TryGetValues(name, out var values) ? string.Join(",", values) : null;

    [Test]
    public async Task Without_the_setting_no_origin_is_allowed()
    {
        using var host = new ApiHost();

        using var response = await host.SendAsync("GET", "/me", From(App));

        Assert.That(Header(response, "Access-Control-Allow-Origin"), Is.Null);
    }

    [TestCase("")]
    [TestCase(" , ")]
    public async Task An_empty_setting_allows_no_origin(string origins)
    {
        using var host = HostAllowing(origins);

        using var response = await host.SendAsync("GET", "/me", From(App));

        Assert.That(Header(response, "Access-Control-Allow-Origin"), Is.Null);
    }

    [Test]
    public async Task A_listed_origin_is_allowed_and_may_read_the_permissions_revision()
    {
        using var host = HostAllowing(Other + ", " + App);

        using var response = await host.SendAsync("GET", "/me", From(App));

        Assert.Multiple(() =>
        {
            Assert.That((int)response.StatusCode, Is.EqualTo(401), "the route still answers as it did");
            Assert.That(Header(response, "Access-Control-Allow-Origin"), Is.EqualTo(App));
            Assert.That(Header(response, "Access-Control-Expose-Headers"), Does.Contain("X-Permissions-Revision"));
            Assert.That(Header(response, "Access-Control-Allow-Credentials"), Is.Null, "sign-in is a bearer token, never a cookie");
        });
    }

    [Test]
    public async Task A_listed_origin_passes_the_preflight_with_its_method_and_headers()
    {
        using var host = HostAllowing(App);

        using var response = await host.SendAsync("OPTIONS", "/me", PreflightFrom(App));

        Assert.Multiple(() =>
        {
            Assert.That((int)response.StatusCode, Is.EqualTo(204));
            Assert.That(Header(response, "Access-Control-Allow-Origin"), Is.EqualTo(App));
            Assert.That(Header(response, "Access-Control-Allow-Methods"), Does.Contain("PUT"));
            Assert.That(Header(response, "Access-Control-Allow-Headers"), Does.Contain("authorization").And.Contain("x-app-version"));
        });
    }

    [Test]
    public async Task An_origin_that_is_not_listed_is_not_allowed()
    {
        using var host = HostAllowing(App);

        using var answer = await host.SendAsync("GET", "/me", From(Other));
        using var preflight = await host.SendAsync("OPTIONS", "/me", PreflightFrom(Other));

        Assert.Multiple(() =>
        {
            Assert.That(Header(answer, "Access-Control-Allow-Origin"), Is.Null);
            Assert.That(Header(preflight, "Access-Control-Allow-Origin"), Is.Null);
        });
    }

    [TestCase("*")]
    [TestCase("https://app.example.test, *")]
    [TestCase("app.example.test")]
    [TestCase("ftp://app.example.test")]
    [TestCase("https://app.example.test/")]
    [TestCase("https://app.example.test/path")]
    [TestCase("https://*.example.test")]
    public void An_entry_that_is_not_one_web_origin_is_refused_and_named(string origins)
    {
        var refusal = Assert.Throws<InvalidOperationException>(() => CorsSetting.Origins(origins));

        Assert.That(refusal!.Message, Does.Contain(CorsSetting.Name).And.Contain(origins.Split(',')[^1].Trim()));
    }

    [Test]
    public void Listed_origins_are_read_trimmed_and_in_order()
    {
        var origins = CorsSetting.Origins(" https://a.example.test ,http://localhost:8377,, ");

        Assert.That(string.Join("|", origins), Is.EqualTo("https://a.example.test|http://localhost:8377"));
    }

    [TestCase("docker-compose.yml")]
    [TestCase("docker-compose.dev.yml")]
    public void Every_stack_passes_the_setting_to_the_api_empty_by_default(string file)
    {
        var stack = File.ReadAllText(Path.Combine(RouteCatalog.RepoRoot(), file));

        Assert.That(stack, Does.Contain("TSR_CORS_ORIGINS: ${TSR_CORS_ORIGINS:-}"));
    }
}
