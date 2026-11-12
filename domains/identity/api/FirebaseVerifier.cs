using System.Globalization;
using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

namespace Tsr.Identity.Api;

internal static class FirebaseVerification
{
    private const int KeyFetchTimeoutSeconds = 5;
    private const int EmulatorTimeoutSeconds = 2;

    /// <summary>Registers the verifier: ASP.NET Core's JWT bearer handler against Google's keys, or the emulator.</summary>
    public static IServiceCollection AddFirebaseVerification(this IServiceCollection services, FirebaseSettings settings)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(settings);

        services.AddSingleton(settings);
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options => Configure(options, settings));
        services.AddHttpClient(FirebaseVerifier.EmulatorClient, client =>
        {
            client.Timeout = TimeSpan.FromSeconds(EmulatorTimeoutSeconds);
            if (settings.UseEmulator)
            {
                client.BaseAddress = new Uri("http://" + settings.EmulatorHost + "/");
            }
        });
        services.AddSingleton<ICallerVerifier, FirebaseVerifier>();
        return services;
    }

    private static void Configure(JwtBearerOptions options, FirebaseSettings settings)
    {
        // Claims keep the names Firebase gave them (sub, email), never mapped to long URIs.
        options.MapInboundClaims = false;
        options.BackchannelTimeout = TimeSpan.FromSeconds(KeyFetchTimeoutSeconds);
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = settings.Issuer,
            ValidateAudience = true,
            ValidAudience = settings.ProjectId,
            ValidateLifetime = true,
            RequireExpirationTime = true,
            // php-jwt sets no leeway, so neither do we.
            ClockSkew = TimeSpan.Zero,
        };

        if (!settings.UseEmulator)
        {
            options.Authority = settings.Issuer;
            options.Events = new JwtBearerEvents { OnTokenValidated = RefuseIssuedInTheFuture };
            return;
        }

        // The emulator issues unsigned tokens: no keys to fetch, but the shape is still checked.
        options.Configuration = new OpenIdConnectConfiguration();
        options.TokenValidationParameters.RequireSignedTokens = false;
        options.TokenValidationParameters.ValidateIssuerSigningKey = false;
        options.TokenValidationParameters.SignatureValidator = (token, _) => ReadUnsigned(token);
    }

    // php-jwt refuses a token issued in the future, but only when it has no nbf (nbf, already checked, wins).
    private static Task RefuseIssuedInTheFuture(TokenValidatedContext context)
    {
        if (context.SecurityToken is JsonWebToken jwt
            && !jwt.TryGetPayloadValue<long>("nbf", out _)
            && jwt.TryGetPayloadValue<long>("iat", out var issuedAt)
            && issuedAt > DateTimeOffset.UtcNow.ToUnixTimeSeconds())
        {
            context.Fail("Token issued in the future.");
        }

        return Task.CompletedTask;
    }

    private static JsonWebToken ReadUnsigned(string token)
    {
        var jwt = new JsonWebToken(token);
        var hasIssuedAt = jwt.TryGetPayloadValue<long>("iat", out _);
        if (jwt.Alg != "none" || jwt.EncodedSignature.Length != 0 || !hasIssuedAt)
        {
            throw new SecurityTokenInvalidSignatureException("Emulator tokens must be unsigned (alg none) and carry iat.");
        }

        return jwt;
    }
}

/// <summary>
/// Verifies a Firebase ID token from the Authorization header. Every refusal except "no header" and
/// "no email" is one <see cref="VerifyStatus.InvalidToken"/>, as PHP collapses them.
/// </summary>
internal sealed partial class FirebaseVerifier(
    IHttpClientFactory httpClients,
    FirebaseSettings settings,
    ILogger<FirebaseVerifier> logger) : ICallerVerifier
{
    public const string EmulatorClient = "firebase-emulator";

    private static readonly Verification NoCredentials = new(VerifyStatus.NoCredentials);
    private static readonly Verification Invalid = new(VerifyStatus.InvalidToken);
    private static readonly Verification NoEmail = new(VerifyStatus.NoEmail);

    public async Task<Verification> VerifyAsync(HttpRequest request, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(request);

        if (!BearerHeader().IsMatch(request.Headers.Authorization.ToString().Trim()))
        {
            return NoCredentials;
        }

        var result = await request.HttpContext.AuthenticateAsync(JwtBearerDefaults.AuthenticationScheme);
        if (!result.Succeeded)
        {
            LogRefused(result.Failure?.GetType().Name ?? "no token read");
            return Invalid;
        }

        var uid = result.Principal.FindFirstValue("sub");
        if (string.IsNullOrEmpty(uid))
        {
            LogRefused("subject missing");
            return Invalid;
        }

        return settings.UseEmulator
            ? await FromEmulatorAsync(request, result.Principal, uid, ct)
            : FromClaims(result.Principal, uid);
    }

    private static Verification FromClaims(ClaimsPrincipal principal, string uid)
    {
        var email = principal.FindFirstValue("email");
        if (string.IsNullOrEmpty(email))
        {
            return NoEmail;
        }

        var verified = principal.FindFirst("email_verified") is { ValueType: ClaimValueTypes.Boolean, Value: var value }
            && bool.TryParse(value, out var flag)
            && flag;
        return new Verification(VerifyStatus.Verified, new FirebaseIdentity(uid, email, verified, TextClaim(principal, "name"), TextClaim(principal, "picture")));
    }

    // A claim is used only when it is JSON text; PHP hands any value on, but a number or a flag is never a name.
    private static string? TextClaim(ClaimsPrincipal principal, string type) =>
        principal.FindFirst(type) is { ValueType: ClaimValueTypes.String, Value: var value } ? value : null;

    // The email and its verified flag come from the emulator's account, never from the unsigned
    // token, so a hand-made token cannot name another email (as PHP does).
    private async Task<Verification> FromEmulatorAsync(HttpRequest request, ClaimsPrincipal principal, string uid, CancellationToken ct)
    {
        var idToken = BearerHeader().Match(request.Headers.Authorization.ToString().Trim()).Groups[1].Value.Trim();
        try
        {
            using var client = httpClients.CreateClient(EmulatorClient);
            using var body = new StringContent("{\"idToken\":\"" + JsonEncodedText.Encode(idToken) + "\"}", System.Text.Encoding.UTF8, "application/json");
            using var response = await client.PostAsync(new Uri("identitytoolkit.googleapis.com/v1/accounts:lookup?key=local", UriKind.Relative), body, ct);
            if (!response.IsSuccessStatusCode)
            {
                LogRefused("emulator answered " + ((int)response.StatusCode).ToString(CultureInfo.InvariantCulture));
                return Invalid;
            }

            using var document = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(ct), cancellationToken: ct);
            return FromAccount(document.RootElement, principal, uid);
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException or JsonException)
        {
            LogRefused("emulator unavailable: " + e.GetType().Name);
            return Invalid;
        }
    }

    private Verification FromAccount(JsonElement root, ClaimsPrincipal principal, string uid)
    {
        if (root.ValueKind != JsonValueKind.Object
            || !root.TryGetProperty("users", out var users)
            || users.ValueKind != JsonValueKind.Array
            || users.GetArrayLength() == 0
            || users[0].ValueKind != JsonValueKind.Object)
        {
            LogRefused("emulator has no matching account");
            return Invalid;
        }

        var account = users[0];
        if (!account.TryGetProperty("localId", out var localId) || localId.ValueKind != JsonValueKind.String || localId.GetString() != uid)
        {
            LogRefused("emulator account is for another uid");
            return Invalid;
        }

        var email = account.TryGetProperty("email", out var e) && e.ValueKind == JsonValueKind.String ? e.GetString() : null;
        if (string.IsNullOrEmpty(email))
        {
            return NoEmail;
        }

        var verified = account.TryGetProperty("emailVerified", out var v) && v.ValueKind == JsonValueKind.True;
        return new Verification(VerifyStatus.Verified, new FirebaseIdentity(uid, email, verified, TextClaim(principal, "name"), TextClaim(principal, "picture")));
    }

    [GeneratedRegex(@"^Bearer\s+(.+)$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant, matchTimeoutMilliseconds: 200)]
    internal static partial Regex BearerHeader();

    [LoggerMessage(Level = LogLevel.Warning, Message = "Firebase token refused: {Reason}")]
    private partial void LogRefused(string reason);
}
