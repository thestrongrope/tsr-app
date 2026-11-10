using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The three geo operations through the API against a real database built by the migrations: the collation
/// (case and accent insensitive equality, prefix search and ordering), the rate limit's place in the order of
/// checks, and a missing table. The rows are db/synthetic/geo-fixtures.sql, the same file the Hurl contract
/// runs on, loaded the way seed.sql loads it.
/// </summary>
public sealed class GeoTests
{
    private const string TooMany = "Too many lookups; try again in a minute";

    private WebApplicationFactory<Program> factory = null!;

    [OneTimeSetUp]
    public async Task StartAsync()
    {
        factory = TestApi.Create();
        var fixtures = await File.ReadAllTextAsync(Path.Combine(TestDatabase.RepoRoot(), "db", "synthetic", "geo-fixtures.sql"));
        await TestDatabase.ExecuteAsync("set search_path = platform, public;\n" + fixtures);
        for (var member = 1; member <= 8; member++)
        {
            await TestDatabase.ExecuteAsync(
                "insert into identity.users (token, email, firebase_uid) "
                + "select " + (900030 + member) + ", 'geo" + member + "@example.invalid', 'uid-geo-" + member + "' "
                + "where not exists (select 1 from identity.users where token = " + (900030 + member) + ")");
        }
    }

    [OneTimeTearDown]
    public void Stop() => factory.Dispose();

    [TestCase("GET", "/geo/countries")]
    [TestCase("POST", "/geo/postal")]
    [TestCase("POST", "/geo/cities")]
    public async Task Without_sign_in_every_route_is_401(string method, string path)
    {
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(new HttpMethod(method), path);
        request.Headers.Add(TestApi.Outcome, "missing");

        using var response = await client.SendAsync(request);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.Unauthorized));
    }

    [Test]
    public async Task Countries_sort_ignoring_case_and_accents_and_carry_a_real_boolean()
    {
        var (status, json) = await SendAsync(1, HttpMethod.Get, "/geo/countries", null);

        Assert.That(status, Is.EqualTo(HttpStatusCode.OK));
        var names = json.GetProperty("countries").EnumerateArray().Select(c => c.GetProperty("name").GetString()).ToList();
        Assert.That(
            string.Join("|", names),
            Is.EqualTo("Afghanistan|Åland Islands|Albania|Colombia|Côte d'Ivoire|Cuba|Switzerland|United Kingdom"));
        var first = json.GetProperty("countries")[0];
        Assert.That(first.GetProperty("code").GetString(), Is.EqualTo("AF"));
        Assert.That(first.GetProperty("hasPostalCodes").ValueKind, Is.EqualTo(JsonValueKind.False));
        Assert.That(json.GetProperty("countries")[1].GetProperty("hasPostalCodes").ValueKind, Is.EqualTo(JsonValueKind.True));
        Assert.That(first.EnumerateObject().Count(), Is.EqualTo(3));
    }

    [TestCase("CH", "8001", true, "Zürich", "Zürich")]
    [TestCase("ch", "8001", true, "Zürich", "Zürich")]
    [TestCase("GB", "sw1a 2aa", true, "Westminster", "England")]
    [TestCase("GB", "EC1A 1BB", true, "City of London", "England")]
    [TestCase("GB", "EC1A 9ZZ", true, "Clerkenwell", "England")]
    [TestCase("IE", "d02 xy45", true, "Dublin", "Leinster")]
    [TestCase("AL", "1001", true, "Tirana", null)]
    [TestCase("AL", "1002", true, null, "Tirana County")]
    [TestCase("AL", "1003", true, "", "")]
    [TestCase("CH", "0", false, null, null)]
    [TestCase("ZZ", "8001", false, null, null)]
    public async Task Postal_codes_are_found_like_the_php_lookup(string country, string code, bool found, string? city, string? state)
    {
        var (status, json) = await SendAsync(2, HttpMethod.Post, "/geo/postal", new { country, code });

        Assert.That(status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(json.GetProperty("found").GetBoolean(), Is.EqualTo(found));
        Assert.That(StringOrNull(json.GetProperty("city")), Is.EqualTo(city));
        Assert.That(StringOrNull(json.GetProperty("state")), Is.EqualTo(state));
    }

    [TestCase("CH", "zur", "Zürich|Zurich West|Zürs")]
    [TestCase("CH", "ZÜR", "Zürich|Zurich West|Zürs")]
    [TestCase("CH", "zu", "Zürich|Zug|Zurich West|Zürs")]
    [TestCase("CH", "ze", "Zell|Zeller")]
    [TestCase("DE", "kol", "Köln|Kolbermoor")]
    [TestCase("DE", "koln", "Köln")]
    [TestCase("ZZ", "100%", "100% Pure")]
    [TestCase("ZZ", "a_b", "a_b")]
    [TestCase("ZZ", "pipe|", "Pipe|Town")]
    [TestCase("ZZ", "Ben &", "Ben & Jerry's")]
    [TestCase("ZZ", "rock", "Rock 'n Roll")]
    [TestCase("XX", "zur", "")]
    public async Task Cities_match_a_prefix_ignoring_case_and_accents_and_take_wildcards_literally(string country, string query, string expected)
    {
        var (status, json) = await SendAsync(3, HttpMethod.Post, "/geo/cities", new { country, query });

        Assert.That(status, Is.EqualTo(HttpStatusCode.OK));
        var names = json.GetProperty("cities").EnumerateArray().Select(c => c.GetProperty("name").GetString());
        Assert.That(string.Join("|", names), Is.EqualTo(expected));
    }

    [Test]
    public async Task Cities_decode_entities_and_turn_an_empty_or_null_state_into_null()
    {
        var (_, rock) = await SendAsync(3, HttpMethod.Post, "/geo/cities", new { country = "ZZ", query = "rock" });
        var (_, ottawa) = await SendAsync(3, HttpMethod.Post, "/geo/cities", new { country = "ZZ", query = "ottawa" });
        var (_, ben) = await SendAsync(3, HttpMethod.Post, "/geo/cities", new { country = "ZZ", query = "ben" });

        Assert.That(rock.GetProperty("cities")[0].GetProperty("state").ValueKind, Is.EqualTo(JsonValueKind.Null));
        Assert.That(ottawa.GetProperty("cities")[0].GetProperty("state").ValueKind, Is.EqualTo(JsonValueKind.Null));
        Assert.That(ben.GetProperty("cities")[0].GetProperty("state").GetString(), Is.EqualTo("Delta"));
    }

    [Test]
    public async Task Cities_are_ordered_by_population_and_the_same_name_is_returned_once_per_state()
    {
        var (_, json) = await SendAsync(3, HttpMethod.Post, "/geo/cities", new { country = "US", query = "spring" });

        var states = json.GetProperty("cities").EnumerateArray().Select(c => c.GetProperty("state").GetString());
        Assert.That(string.Join("|", states), Is.EqualTo("Missouri|Massachusetts|Illinois"));
    }

    [Test]
    public async Task Cities_return_at_most_ten()
    {
        var (_, json) = await SendAsync(3, HttpMethod.Post, "/geo/cities", new { country = "LM", query = "limit" });

        Assert.That(json.GetProperty("cities").GetArrayLength(), Is.EqualTo(10));
    }

    [TestCase("{\"country\":\"CHE\",\"code\":\"8001\"}", "country is required and must be at most 2 characters")]
    [TestCase("{\"country\":\"CH\"}", "code is required and must be at most 20 characters")]
    [TestCase("{\"country\":\"CH\",\"code\":8001}", "code is required and must be at most 20 characters")]
    [TestCase("{\"country\":\" CH \",\"code\":\"8001\"}", "country is required and must be at most 2 characters")]
    [TestCase("[]", "country is required and must be at most 2 characters")]
    [TestCase("", "country is required and must be at most 2 characters")]
    [TestCase("\"text\"", "Invalid JSON body")]
    [TestCase("null", "Invalid JSON body")]
    [TestCase("{\"country\":", "Invalid JSON body")]
    public async Task A_bad_postal_body_is_a_422_with_the_php_detail(string body, string detail)
    {
        var (status, json) = await SendRawAsync(4, HttpMethod.Post, "/geo/postal", body);

        Assert.That(status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(json.GetProperty("detail").GetString(), Is.EqualTo(detail));
    }

    [Test]
    public async Task A_query_over_100_characters_is_a_422_and_exactly_100_is_accepted()
    {
        var (over, json) = await SendAsync(4, HttpMethod.Post, "/geo/cities", new { country = "CH", query = new string('a', 101) });
        var (exact, _) = await SendAsync(4, HttpMethod.Post, "/geo/cities", new { country = "CH", query = new string('a', 100) });

        Assert.That(over, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(json.GetProperty("detail").GetString(), Is.EqualTo("query is required and must be at most 100 characters"));
        Assert.That(exact, Is.EqualTo(HttpStatusCode.OK));
    }

    [Test]
    public async Task A_body_over_the_size_limit_is_a_413()
    {
        var (status, json) = await SendRawAsync(4, HttpMethod.Post, "/geo/postal", "{\"country\":\"" + new string('a', 20000) + "\"}");

        Assert.That(status, Is.EqualTo(HttpStatusCode.RequestEntityTooLarge));
        Assert.That(json.GetProperty("detail").GetString(), Is.EqualTo("Request body too large"));
    }

    [Test]
    public async Task The_61st_call_in_a_minute_is_a_429_with_the_php_detail()
    {
        for (var call = 1; call <= 60; call++)
        {
            var (status, _) = await SendAsync(5, HttpMethod.Get, "/geo/countries", null);
            Assert.That(status, Is.EqualTo(HttpStatusCode.OK), "call " + call);
        }

        var (refused, json) = await SendAsync(5, HttpMethod.Get, "/geo/countries", null);

        Assert.That(refused, Is.EqualTo(HttpStatusCode.TooManyRequests));
        Assert.That(json.GetProperty("detail").GetString(), Is.EqualTo(TooMany));
    }

    [Test]
    public async Task Calls_that_fail_validation_count_and_the_429_comes_before_body_validation()
    {
        for (var call = 1; call <= 60; call++)
        {
            var (status, _) = await SendRawAsync(6, HttpMethod.Post, "/geo/cities", "not json");
            Assert.That(status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), "call " + call);
        }

        var (refused, json) = await SendRawAsync(6, HttpMethod.Post, "/geo/cities", "not json");

        Assert.That(refused, Is.EqualTo(HttpStatusCode.TooManyRequests));
        Assert.That(json.GetProperty("detail").GetString(), Is.EqualTo(TooMany));
    }

    [Test]
    public async Task One_members_limit_does_not_affect_another()
    {
        for (var call = 1; call <= 61; call++)
        {
            await SendAsync(7, HttpMethod.Get, "/geo/countries", null);
        }

        var (other, _) = await SendAsync(8, HttpMethod.Get, "/geo/countries", null);

        Assert.That(other, Is.EqualTo(HttpStatusCode.OK));
    }

    [Test]
    public async Task A_missing_geo_table_gives_an_empty_answer_not_an_error()
    {
        await TestDatabase.ExecuteAsync("alter table platform.geo_countries rename to geo_countries_away");
        try
        {
            var (status, json) = await SendAsync(1, HttpMethod.Get, "/geo/countries", null);

            Assert.That(status, Is.EqualTo(HttpStatusCode.OK));
            Assert.That(json.GetProperty("countries").GetArrayLength(), Is.EqualTo(0));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("alter table platform.geo_countries_away rename to geo_countries");
        }
    }

    private static string? StringOrNull(JsonElement element) =>
        element.ValueKind == JsonValueKind.Null ? null : element.GetString();

    private Task<(HttpStatusCode Status, JsonElement Json)> SendAsync(int member, HttpMethod method, string path, object? body) =>
        SendRawAsync(member, method, path, body is null ? null : JsonSerializer.Serialize(body));

    private async Task<(HttpStatusCode Status, JsonElement Json)> SendRawAsync(int member, HttpMethod method, string path, string? body)
    {
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(method, path);
        if (body is not null)
        {
            request.Content = new StringContent(body, Encoding.UTF8, "application/json");
        }

        foreach (var (name, value) in TestApi.SignedInAs("uid-geo-" + member, "geo" + member + "@example.invalid"))
        {
            request.Headers.Add(name, value);
        }

        using var response = await client.SendAsync(request);
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return (response.StatusCode, document.RootElement.Clone());
    }
}
