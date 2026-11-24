using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization.Metadata;
using Microsoft.IdentityModel.Tokens;
using NUnit.Framework;
using Tsr.Identity.Api.Domain;

namespace Tsr.Identity.Api.Tests;

/// <summary>
/// The real Firebase client's requests, against a stub HTTP handler and a throwaway RSA key generated here (no real key, no network). What this proves: the shape of every request the
/// client builds. What it cannot prove: that Google accepts those shapes (see docs/specs/initial-build/test-deletion-notes.md).
/// </summary>
public sealed class GoogleFirebaseAccountsTests
{
    private const string Project = "demo-tsr-test";
    private static readonly DateTimeOffset Now = new(2030, 1, 1, 12, 0, 0, TimeSpan.Zero);

    private RSA key = null!;
    private StubHandler handler = null!;

    [SetUp]
    public void SetUp()
    {
        key = RSA.Create(2048);
        handler = new StubHandler();
    }

    [TearDown]
    public void TearDown()
    {
        key.Dispose();
        handler.Dispose();
    }

    private sealed record Sent(HttpMethod Method, Uri Uri, string? Authorization, string Body);

    private sealed class StubHandler : HttpMessageHandler
    {
        public List<Sent> Requests { get; } = [];

        public Func<Sent, HttpResponseMessage> Respond { get; set; } = _ => new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("{}") };

        public bool Fail { get; set; }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var sent = new Sent(request.Method, request.RequestUri!, request.Headers.Authorization?.ToString(), request.Content is null ? string.Empty : await request.Content.ReadAsStringAsync(cancellationToken));
            Requests.Add(sent);
            return Fail ? throw new HttpRequestException("connection refused") : Respond(sent);
        }
    }

    private sealed class StubFactory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new(handler, disposeHandler: false);
    }

    private sealed class FixedClock(DateTimeOffset now) : TimeProvider
    {
        public DateTimeOffset Value { get; set; } = now;

        public override DateTimeOffset GetUtcNow() => Value;
    }

    private static HttpResponseMessage Json(HttpStatusCode status, string json) => new(status) { Content = new StringContent(json) };

    private GoogleFirebaseAccounts Client(string accountProject = Project, FixedClock? clock = null)
    {
        var account = new GoogleServiceAccount("svc@" + Project + ".iam.invalid", key.ExportPkcs8PrivateKeyPem(), accountProject);
        handler.Respond = sent => sent.Uri.AbsoluteUri switch
        {
            "https://oauth2.googleapis.com/token" => Json(HttpStatusCode.OK, """{"access_token":"stub-access-token","expires_in":3599}"""),
            _ => Json(HttpStatusCode.OK, "{}"),
        };
        return new GoogleFirebaseAccounts(new StubFactory(handler), account, Project, clock ?? new FixedClock(Now));
    }

    [Test]
    public async Task A_stored_uid_is_deleted_directly_after_one_token_exchange_with_a_signed_assertion()
    {
        using var client = Client();

        await client.DeleteAsync("uid-1", "someone@example.invalid", CancellationToken.None);

        Assert.That(handler.Requests, Has.Count.EqualTo(2), "token exchange, then delete: no lookup by email when a uid is stored");
        var exchange = handler.Requests[0];
        Assert.That(exchange.Method, Is.EqualTo(HttpMethod.Post));
        Assert.That(exchange.Uri.AbsoluteUri, Is.EqualTo("https://oauth2.googleapis.com/token"));
        var form = exchange.Body.Split('&').Select(p => p.Split('=')).ToDictionary(p => p[0], p => Uri.UnescapeDataString(p[1]));
        Assert.That(form["grant_type"], Is.EqualTo("urn:ietf:params:oauth:grant-type:jwt-bearer"));
        var parts = form["assertion"].Split('.');
        Assert.That(JsonElement.Parse(Base64UrlEncoder.DecodeBytes(parts[0])).GetProperty("alg").GetString(), Is.EqualTo("RS256"));
        var claims = JsonElement.Parse(Base64UrlEncoder.DecodeBytes(parts[1]));
        Assert.That(claims.GetProperty("iss").GetString(), Is.EqualTo("svc@demo-tsr-test.iam.invalid"));
        Assert.That(claims.GetProperty("scope").GetString(), Is.EqualTo("https://www.googleapis.com/auth/identitytoolkit"));
        Assert.That(claims.GetProperty("aud").GetString(), Is.EqualTo("https://oauth2.googleapis.com/token"));
        Assert.That(claims.GetProperty("exp").GetInt64() - claims.GetProperty("iat").GetInt64(), Is.EqualTo(3600));
        Assert.That(claims.GetProperty("iat").GetInt64(), Is.EqualTo(Now.ToUnixTimeSeconds()));
        Assert.That(
            key.VerifyData(Encoding.ASCII.GetBytes(parts[0] + "." + parts[1]), Base64UrlEncoder.DecodeBytes(parts[2]), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1),
            Is.True,
            "the assertion is signed with the account's key");
        var delete = handler.Requests[1];
        Assert.That(delete.Method, Is.EqualTo(HttpMethod.Post));
        Assert.That(delete.Uri.AbsoluteUri, Is.EqualTo("https://identitytoolkit.googleapis.com/v1/projects/demo-tsr-test/accounts:delete"));
        Assert.That(delete.Authorization, Is.EqualTo("Bearer stub-access-token"));
        Assert.That(JsonElement.Parse(delete.Body).GetProperty("localId").GetString(), Is.EqualTo("uid-1"));
    }

    [Test]
    public async Task With_no_uid_the_account_is_looked_up_by_email_and_the_account_found_is_deleted_FINDING_2()
    {
        using var client = Client();
        handler.Respond = sent => sent.Uri.AbsoluteUri switch
        {
            "https://oauth2.googleapis.com/token" => Json(HttpStatusCode.OK, """{"access_token":"t","expires_in":3599}"""),
            var u when u.EndsWith("accounts:lookup", StringComparison.Ordinal) => Json(HttpStatusCode.OK, """{"users":[{"localId":"uid-of-whoever-owns-it"}]}"""),
            _ => Json(HttpStatusCode.OK, "{}"),
        };

        await client.DeleteAsync(null, "owner@example.invalid", CancellationToken.None);

        var lookup = handler.Requests.Single(r => r.Uri.AbsoluteUri.EndsWith("accounts:lookup", StringComparison.Ordinal));
        Assert.That(JsonElement.Parse(lookup.Body).GetProperty("email")[0].GetString(), Is.EqualTo("owner@example.invalid"));
        var delete = handler.Requests.Single(r => r.Uri.AbsoluteUri.EndsWith("accounts:delete", StringComparison.Ordinal));
        Assert.That(JsonElement.Parse(delete.Body).GetProperty("localId").GetString(), Is.EqualTo("uid-of-whoever-owns-it"), "whichever account owns the address is deleted (PHP does the same)");
    }

    [TestCase("""{}""")]
    [TestCase("""{"users":[]}""")]
    public async Task A_lookup_that_finds_no_account_deletes_nothing(string answer)
    {
        using var client = Client();
        handler.Respond = sent => sent.Uri.AbsoluteUri.EndsWith("accounts:lookup", StringComparison.Ordinal)
            ? Json(HttpStatusCode.OK, answer)
            : Json(HttpStatusCode.OK, """{"access_token":"t","expires_in":3599}""");

        await client.DeleteAsync(null, "nobody@example.invalid", CancellationToken.None);

        Assert.That(handler.Requests.Any(r => r.Uri.AbsoluteUri.EndsWith("accounts:delete", StringComparison.Ordinal)), Is.False);
    }

    [Test]
    public async Task A_lookup_answered_EMAIL_NOT_FOUND_and_a_delete_answered_USER_NOT_FOUND_both_count_as_done()
    {
        using var client = Client();
        handler.Respond = sent => sent.Uri.AbsoluteUri switch
        {
            "https://oauth2.googleapis.com/token" => Json(HttpStatusCode.OK, """{"access_token":"t","expires_in":3599}"""),
            var u when u.EndsWith("accounts:lookup", StringComparison.Ordinal) => Json(HttpStatusCode.BadRequest, """{"error":{"message":"EMAIL_NOT_FOUND"}}"""),
            _ => Json(HttpStatusCode.BadRequest, """{"error":{"message":"USER_NOT_FOUND"}}"""),
        };

        await client.DeleteAsync(null, "x@example.invalid", CancellationToken.None);
        await client.DeleteAsync("uid-gone", null, CancellationToken.None);
    }

    [Test]
    public async Task Any_other_failure_of_the_delete_throws_the_safe_exception_without_the_key_the_token_or_the_address()
    {
        using var client = Client();
        handler.Respond = sent => sent.Uri.AbsoluteUri == "https://oauth2.googleapis.com/token"
            ? Json(HttpStatusCode.OK, """{"access_token":"secret-access-token","expires_in":3599}""")
            : Json(HttpStatusCode.InternalServerError, """{"error":{"message":"backend error for owner@example.invalid"}}""");

        var thrown = await Assert.ThrowsAsync<FirebaseAccountException>(() => client.DeleteAsync("uid-1", "owner@example.invalid", CancellationToken.None));

        Assert.That(thrown!.Message, Is.EqualTo("Firebase refused the account deletion (HTTP 500)."));
        Assert.That(thrown.Message, Does.Not.Contain("secret-access-token").And.Not.Contain("owner@example.invalid").And.Not.Contain("PRIVATE"));
    }

    [Test]
    public async Task A_token_exchange_that_is_refused_throws_with_its_status_only()
    {
        using var client = Client();
        handler.Respond = _ => Json(HttpStatusCode.Unauthorized, """{"error":"invalid_grant","error_description":"Invalid JWT Signature."}""");

        var thrown = await Assert.ThrowsAsync<FirebaseAccountException>(() => client.DeleteAsync("uid-1", null, CancellationToken.None));

        Assert.That(thrown!.Message, Is.EqualTo("Google refused the service account sign-in (HTTP 401)."));
        Assert.That(handler.Requests, Has.Count.EqualTo(1), "no delete is attempted without a token");
    }

    [Test]
    public async Task An_unreachable_Google_is_a_FirebaseAccountException_naming_the_exception_type_only()
    {
        using var client = Client();
        handler.Fail = true;

        var thrown = await Assert.ThrowsAsync<FirebaseAccountException>(() => client.DeleteAsync("uid-1", null, CancellationToken.None));

        Assert.That(thrown!.Message, Is.EqualTo("Firebase could not be reached (HttpRequestException)."));
    }

    [Test]
    public async Task A_service_account_of_another_project_is_refused_before_any_request()
    {
        using var client = Client(accountProject: "some-other-project");

        var thrown = await Assert.ThrowsAsync<FirebaseAccountException>(() => client.DeleteAsync("uid-1", null, CancellationToken.None));

        Assert.That(thrown!.Message, Does.StartWith("Firebase project mismatch"));
        Assert.That(handler.Requests, Is.Empty);
    }

    [Test]
    public async Task The_access_token_is_reused_until_a_minute_before_it_expires_then_exchanged_again()
    {
        var clock = new FixedClock(Now);
        using var client = Client(clock: clock);

        await client.DeleteAsync("uid-1", null, CancellationToken.None);
        clock.Value = Now.AddSeconds(3000);
        await client.DeleteAsync("uid-2", null, CancellationToken.None);
        clock.Value = Now.AddSeconds(3600);
        await client.DeleteAsync("uid-3", null, CancellationToken.None);

        Assert.That(handler.Requests.Count(r => r.Uri.AbsoluteUri == "https://oauth2.googleapis.com/token"), Is.EqualTo(2));
    }

    [Test]
    public void A_service_account_that_is_not_base64_JSON_with_the_three_fields_is_refused_without_echoing_it()
    {
        var bad = Convert.ToBase64String(Encoding.UTF8.GetBytes("""{"client_email":"a@b.invalid","private_key":"SECRET-KEY-TEXT"}"""));

        var thrown = Assert.Throws<InvalidOperationException>(() => GoogleServiceAccount.Parse(bad));

        Assert.That(thrown!.Message, Does.Not.Contain("SECRET-KEY-TEXT").And.Not.Contain(bad));
        Assert.Throws<InvalidOperationException>(() => GoogleServiceAccount.Parse("not base64 !!"));
    }

    // TC-IDN-R10-01: what the code wrote before issue 102 (anonymous types, default options, by reflection) against what the generated context writes now.
    [Test]
    public void Each_request_body_is_written_as_before()
    {
        var reflection = new JsonSerializerOptions { TypeInfoResolver = new DefaultJsonTypeInfoResolver() };
        const string awkward = "Zoë+tag@example.invalid\"<&>";
        const string issuer = "svc+one@demo-tsr-test.iam.invalid";
        const long issued = 1893499200;

        Assert.Multiple(() =>
        {
            Assert.That(
                JsonSerializer.Serialize(new AccountLookup([awkward]), IdentityJson.Default.AccountLookup),
                Is.EqualTo(JsonSerializer.Serialize(new { email = new[] { awkward } }, reflection)));
            Assert.That(
                JsonSerializer.Serialize(new AccountDelete("uid+\"1\"ü"), IdentityJson.Default.AccountDelete),
                Is.EqualTo(JsonSerializer.Serialize(new { localId = "uid+\"1\"ü" }, reflection)));
            Assert.That(
                JsonSerializer.SerializeToUtf8Bytes(new JwtHeader("RS256", "JWT"), IdentityJson.Default.JwtHeader),
                Is.EqualTo(JsonSerializer.SerializeToUtf8Bytes(new { alg = "RS256", typ = "JWT" }, reflection)));
            Assert.That(
                JsonSerializer.SerializeToUtf8Bytes(new JwtClaims(issuer, "https://www.googleapis.com/auth/identitytoolkit", "https://oauth2.googleapis.com/token", issued, issued + 3600), IdentityJson.Default.JwtClaims),
                Is.EqualTo(JsonSerializer.SerializeToUtf8Bytes(new { iss = issuer, scope = "https://www.googleapis.com/auth/identitytoolkit", aud = "https://oauth2.googleapis.com/token", iat = issued, exp = issued + 3600 }, reflection)));
        });
    }
}
