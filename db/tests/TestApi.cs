using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Tsr.Identity.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// The API in-process against the test database, as the limited role. Firebase is replaced by
/// <see cref="StubVerifier"/>: a test says who is calling in request headers, so no token or emulator is needed.
/// The real verifier is covered by identity's unit tests and by the Hurl contract against the emulator.
/// </summary>
internal static class TestApi
{
    public const string Uid = "X-Test-Uid";
    public const string Email = "X-Test-Email";
    public const string Verified = "X-Test-Verified";
    public const string Outcome = "X-Test-Outcome";
    public const string Name = "X-Test-Name";
    public const string Picture = "X-Test-Picture";

    /// <param name="appConnection">The connection string the API uses; the shared test database when left out.</param>
    public static WebApplicationFactory<Program> Create(string? appConnection = null) =>
        new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseSetting("TSR_DB", appConnection ?? TestDatabase.AppConnection);
            builder.UseSetting("TSR_FIREBASE_PROJECT_ID", "demo-tsr-test");
            builder.UseSetting("TSR_AUTH_EMULATOR_HOST", "localhost:9099");
            builder.UseSetting("TSR_GOTENBERG_URL", "http://gotenberg.invalid:3000");
            // Set to nothing: no test reads the real channel's feed (unset, the API reads the channel in the code).
            builder.UseSetting("TSR_YOUTUBE_CHANNEL_ID", string.Empty);
            builder.ConfigureTestServices(services => services.AddSingleton<ICallerVerifier, StubVerifier>());
        });

    /// <summary>Headers that make <see cref="StubVerifier"/> answer "this Firebase user".</summary>
    public static IEnumerable<KeyValuePair<string, string>> SignedInAs(string uid, string email, bool verified = true) =>
    [
        new(Uid, uid),
        new(Email, email),
        new(Verified, verified ? "true" : "false"),
    ];

    private sealed class StubVerifier : ICallerVerifier
    {
        public Task<Verification> VerifyAsync(HttpRequest request, CancellationToken ct)
        {
            var outcome = request.Headers[Outcome].ToString();
            var result = outcome switch
            {
                "missing" => new Verification(VerifyStatus.NoCredentials),
                "invalid" => new Verification(VerifyStatus.InvalidToken),
                "noemail" => new Verification(VerifyStatus.NoEmail),
                _ => new Verification(
                    VerifyStatus.Verified,
                    new FirebaseIdentity(
                        request.Headers[Uid].ToString(),
                        request.Headers[Email].ToString(),
                        request.Headers[Verified] == "true",
                        request.Headers.TryGetValue(Name, out var name) ? name.ToString() : null,
                        request.Headers.TryGetValue(Picture, out var picture) ? picture.ToString() : null)),
            };
            return Task.FromResult(result);
        }
    }
}
