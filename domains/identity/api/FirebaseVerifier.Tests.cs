using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;
using NUnit.Framework;

namespace Tsr.Identity.Api.Tests;

/// <summary>
/// Token verification: Google's keys (a local key stands in for them), issuer, audience, subject,
/// expiry and the Firebase Auth emulator mode. Every refusal is "invalid", as in PHP.
/// </summary>
public sealed class FirebaseVerifierTests
{
    private const string Project = "tsr-test";
    private const string DemoProject = "demo-tsr-test";
    private static readonly RsaSecurityKey SigningKey = new(RSA.Create(2048)) { KeyId = "k1" };
    private static readonly RsaSecurityKey OtherKey = new(RSA.Create(2048)) { KeyId = "k1" };

    [Test]
    public async Task A_valid_token_gives_the_uid_email_and_verified_flag()
    {
        var result = await VerifyProductionAsync("Bearer " + Sign(new() { ["email"] = "a@example.invalid", ["email_verified"] = true }));

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.Verified));
        Assert.That(result.Identity, Is.EqualTo(new FirebaseIdentity("uid-1", "a@example.invalid", true)));
    }

    [Test]
    public async Task The_name_and_picture_claims_travel_with_the_identity()
    {
        var token = Sign(new() { ["email"] = "a@example.invalid", ["name"] = "Synthetic Person", ["picture"] = "https://example.invalid/p.png" });

        var result = await VerifyProductionAsync("Bearer " + token);

        Assert.That(result.Identity?.Name, Is.EqualTo("Synthetic Person"));
        Assert.That(result.Identity?.Picture, Is.EqualTo("https://example.invalid/p.png"));
    }

    [Test]
    public async Task A_name_or_picture_that_is_not_text_is_ignored()
    {
        var token = Sign(new() { ["email"] = "a@example.invalid", ["name"] = 42, ["picture"] = true });

        var result = await VerifyProductionAsync("Bearer " + token);

        Assert.That(result.Identity?.Name, Is.Null);
        Assert.That(result.Identity?.Picture, Is.Null);
    }

    [Test]
    public async Task In_emulator_mode_the_name_and_picture_come_from_the_token_payload_as_in_PHP()
    {
        var token = Unsigned(DemoProject, new() { ["name"] = "Synthetic Person", ["picture"] = "https://example.invalid/p.png" });

        var result = await VerifyEmulatorAsync("Bearer " + token, Account("uid-1", "a@example.invalid", true));

        Assert.That(result.Identity?.Name, Is.EqualTo("Synthetic Person"));
        Assert.That(result.Identity?.Picture, Is.EqualTo("https://example.invalid/p.png"));
    }

    [TestCase(null)]
    [TestCase("")]
    [TestCase("Basic abc")]
    [TestCase("Bearer")]
    [TestCase("Bearer   ")]
    public async Task A_missing_or_non_bearer_header_is_no_credentials(string? header)
    {
        var result = await VerifyProductionAsync(header);

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.NoCredentials));
    }

    [Test]
    public async Task The_bearer_scheme_is_case_insensitive()
    {
        var result = await VerifyProductionAsync("bEaReR " + Sign(new() { ["email"] = "a@example.invalid" }));

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.Verified));
    }

    [Test]
    public async Task Garbage_is_an_invalid_token()
    {
        Assert.That((await VerifyProductionAsync("Bearer abc.def.ghi")).Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task An_expired_token_is_invalid_with_no_clock_skew_allowed()
    {
        var token = Sign(new() { ["email"] = "a@example.invalid" }, expires: DateTime.UtcNow.AddSeconds(-2));

        Assert.That((await VerifyProductionAsync("Bearer " + token)).Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task A_token_not_valid_yet_is_invalid()
    {
        var token = Sign(new() { ["email"] = "a@example.invalid" }, notBefore: DateTime.UtcNow.AddMinutes(5), expires: DateTime.UtcNow.AddMinutes(65));

        Assert.That((await VerifyProductionAsync("Bearer " + token)).Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task A_token_issued_in_the_future_with_no_not_before_is_invalid()
    {
        // php-jwt (leeway 0) refuses a token whose iat is ahead of now when it carries no nbf.
        var token = Sign(new() { ["email"] = "a@example.invalid" }, omitNotBefore: true, issuedAt: DateTime.UtcNow.AddMinutes(5));

        Assert.That((await VerifyProductionAsync("Bearer " + token)).Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task Quirk_a_future_iat_is_accepted_when_the_token_has_a_valid_not_before()
    {
        // php-jwt checks iat only when nbf is absent, so nbf in the past wins.
        var token = Sign(new() { ["email"] = "a@example.invalid" }, issuedAt: DateTime.UtcNow.AddMinutes(5));

        Assert.That((await VerifyProductionAsync("Bearer " + token)).Status, Is.EqualTo(VerifyStatus.Verified));
    }

    [Test]
    public async Task Quirk_an_emulator_token_issued_in_the_future_is_accepted()
    {
        // PHP's emulator decoder checks only that iat is numeric, not that it is past.
        var token = Unsigned(DemoProject, new(), issuedAt: DateTimeOffset.UtcNow.AddMinutes(5));

        var result = await VerifyEmulatorAsync("Bearer " + token, Account("uid-1", "a@example.invalid", true));

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.Verified));
    }

    [Test]
    public async Task A_wrong_issuer_is_invalid()
    {
        var token = Sign(new() { ["email"] = "a@example.invalid" }, issuer: "https://securetoken.google.com/other");

        Assert.That((await VerifyProductionAsync("Bearer " + token)).Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task A_wrong_audience_is_invalid()
    {
        var token = Sign(new() { ["email"] = "a@example.invalid" }, audience: "other");

        Assert.That((await VerifyProductionAsync("Bearer " + token)).Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [TestCase("")]
    [TestCase(null)]
    public async Task An_empty_or_missing_subject_is_invalid(string? subject)
    {
        var claims = new Dictionary<string, object> { ["email"] = "a@example.invalid", ["sub"] = subject! };
        if (subject is null)
        {
            claims.Remove("sub");
        }

        var token = Sign(claims, defaultSubject: false);

        Assert.That((await VerifyProductionAsync("Bearer " + token)).Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task A_token_signed_with_another_key_is_invalid()
    {
        var token = Sign(new() { ["email"] = "a@example.invalid" }, key: OtherKey);

        Assert.That((await VerifyProductionAsync("Bearer " + token)).Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task An_unsigned_token_is_invalid_outside_the_emulator()
    {
        var token = Unsigned(Project, new() { ["email"] = "a@example.invalid" });

        Assert.That((await VerifyProductionAsync("Bearer " + token)).Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task A_valid_token_without_an_email_is_no_email()
    {
        var result = await VerifyProductionAsync("Bearer " + Sign(new()));

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.NoEmail));
    }

    [Test]
    public async Task Only_a_json_true_counts_as_a_verified_email()
    {
        var result = await VerifyProductionAsync("Bearer " + Sign(new() { ["email"] = "a@example.invalid", ["email_verified"] = "true" }));

        Assert.That(result.Identity!.EmailVerified, Is.False);
    }

    [Test]
    public async Task An_emulator_token_takes_its_email_from_the_emulator_account_not_the_token()
    {
        var token = Unsigned(DemoProject, new() { ["email"] = "attacker@example.invalid", ["email_verified"] = true });

        var result = await VerifyEmulatorAsync("Bearer " + token, Account("uid-1", "real@example.invalid", true));

        Assert.That(result.Identity, Is.EqualTo(new FirebaseIdentity("uid-1", "real@example.invalid", true)));
    }

    [Test]
    public async Task An_emulator_account_that_is_not_verified_gives_an_unverified_identity()
    {
        var token = Unsigned(DemoProject, new());

        var result = await VerifyEmulatorAsync("Bearer " + token, Account("uid-1", "u@example.invalid", false));

        Assert.That(result.Identity!.EmailVerified, Is.False);
    }

    [Test]
    public async Task An_emulator_account_without_an_email_is_no_email()
    {
        var token = Unsigned(DemoProject, new());

        var result = await VerifyEmulatorAsync("Bearer " + token, Account("uid-1", null, false));

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.NoEmail));
    }

    [Test]
    public async Task An_emulator_account_for_another_uid_is_invalid()
    {
        var token = Unsigned(DemoProject, new());

        var result = await VerifyEmulatorAsync("Bearer " + token, Account("someone-else", "u@example.invalid", true));

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [TestCase(HttpStatusCode.InternalServerError)]
    [TestCase(HttpStatusCode.NotFound)]
    public async Task An_emulator_that_does_not_answer_ok_is_invalid(HttpStatusCode status)
    {
        var token = Unsigned(DemoProject, new());

        var result = await VerifyEmulatorAsync("Bearer " + token, new HttpResponseMessage(status));

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task An_emulator_that_cannot_be_reached_is_invalid()
    {
        var token = Unsigned(DemoProject, new());

        var result = await VerifyEmulatorAsync("Bearer " + token, null);

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task A_signed_token_is_invalid_in_emulator_mode()
    {
        var token = Sign(new() { ["email"] = "a@example.invalid" }, audience: DemoProject, issuer: "https://securetoken.google.com/" + DemoProject);

        var result = await VerifyEmulatorAsync("Bearer " + token, Account("uid-1", "a@example.invalid", true));

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task An_expired_emulator_token_is_invalid()
    {
        var token = Unsigned(DemoProject, new(), expires: DateTimeOffset.UtcNow.AddSeconds(-2));

        var result = await VerifyEmulatorAsync("Bearer " + token, Account("uid-1", "a@example.invalid", true));

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task An_emulator_token_for_another_project_is_invalid()
    {
        var token = Unsigned("demo-other", new());

        var result = await VerifyEmulatorAsync("Bearer " + token, Account("uid-1", "a@example.invalid", true));

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    [Test]
    public async Task An_emulator_token_without_iat_is_invalid()
    {
        var token = Unsigned(DemoProject, new(), includeIssuedAt: false);

        var result = await VerifyEmulatorAsync("Bearer " + token, Account("uid-1", "a@example.invalid", true));

        Assert.That(result.Status, Is.EqualTo(VerifyStatus.InvalidToken));
    }

    private static Task<Verification> VerifyProductionAsync(string? header)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddFirebaseVerification(new FirebaseSettings(Project, null));
        services.PostConfigure<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme, o =>
        {
            var configuration = new OpenIdConnectConfiguration();
            configuration.SigningKeys.Add(SigningKey);
            o.ConfigurationManager = new StaticConfigurationManager<OpenIdConnectConfiguration>(configuration);
        });
        return VerifyAsync(services, header);
    }

    private static Task<Verification> VerifyEmulatorAsync(string header, HttpResponseMessage? lookupResponse)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddFirebaseVerification(new FirebaseSettings(DemoProject, "localhost:9099"));
        services.AddHttpClient(FirebaseVerifier.EmulatorClient)
            .ConfigurePrimaryHttpMessageHandler(() => new FakeEmulator(lookupResponse));
        return VerifyAsync(services, header);
    }

    private static async Task<Verification> VerifyAsync(ServiceCollection services, string? header)
    {
        await using var provider = services.BuildServiceProvider();
        var context = new DefaultHttpContext { RequestServices = provider };
        if (header is not null)
        {
            context.Request.Headers.Authorization = header;
        }

        return await provider.GetRequiredService<ICallerVerifier>().VerifyAsync(context.Request, CancellationToken.None);
    }

    private static HttpResponseMessage Account(string uid, string? email, bool verified)
    {
        var user = new Dictionary<string, object?> { ["localId"] = uid, ["emailVerified"] = verified };
        if (email is not null)
        {
            user["email"] = email;
        }

        var body = JsonSerializer.Serialize(new { users = new[] { user } });
        return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
    }

    private static string Sign(
        Dictionary<string, object> claims,
        DateTime? expires = null,
        DateTime? notBefore = null,
        string? issuer = null,
        string? audience = null,
        SecurityKey? key = null,
        bool defaultSubject = true,
        DateTime? issuedAt = null,
        bool omitNotBefore = false)
    {
        if (defaultSubject)
        {
            claims["sub"] = "uid-1";
        }

        var descriptor = new SecurityTokenDescriptor
        {
            Claims = claims,
            Issuer = issuer ?? "https://securetoken.google.com/" + Project,
            Audience = audience ?? Project,
            NotBefore = notBefore ?? DateTime.UtcNow.AddMinutes(-1),
            IssuedAt = issuedAt ?? DateTime.UtcNow.AddMinutes(-1),
            Expires = expires ?? DateTime.UtcNow.AddMinutes(30),
            SigningCredentials = new SigningCredentials(key ?? SigningKey, SecurityAlgorithms.RsaSha256),
        };
        var handler = new JsonWebTokenHandler();
        var token = handler.CreateToken(descriptor);
        return omitNotBefore ? WithoutNotBefore(token, descriptor.SigningCredentials) : token;
    }

    // The handler always stamps nbf, so a token without one is re-signed from its payload minus nbf.
    private static string WithoutNotBefore(string token, SigningCredentials credentials)
    {
        var payload = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(new JsonWebToken(token).EncodedPayload.Length > 0
            ? Encoding.UTF8.GetString(Base64UrlEncoder.DecodeBytes(new JsonWebToken(token).EncodedPayload))
            : "{}")!;
        payload.Remove("nbf");
        return new JsonWebTokenHandler().CreateToken(JsonSerializer.Serialize(payload), credentials);
    }

    private static string Unsigned(string project, Dictionary<string, object> claims, DateTimeOffset? expires = null, bool includeIssuedAt = true, DateTimeOffset? issuedAt = null)
    {
        claims["iss"] = "https://securetoken.google.com/" + project;
        claims["aud"] = project;
        claims["sub"] = "uid-1";
        claims["exp"] = (expires ?? DateTimeOffset.UtcNow.AddMinutes(30)).ToUnixTimeSeconds();
        if (includeIssuedAt)
        {
            claims["iat"] = (issuedAt ?? DateTimeOffset.UtcNow.AddMinutes(-1)).ToUnixTimeSeconds();
        }

        return Base64Url("""{"alg":"none","typ":"JWT"}""") + "." + Base64Url(JsonSerializer.Serialize(claims)) + ".";
    }

    private static string Base64Url(string text) => Base64UrlEncoder.Encode(Encoding.UTF8.GetBytes(text));

    /// <summary>Stands in for the emulator's accounts:lookup. A null response means the connection fails.</summary>
    private sealed class FakeEmulator(HttpResponseMessage? response) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            response is null ? throw new HttpRequestException("connection refused") : Task.FromResult(response);
    }
}
