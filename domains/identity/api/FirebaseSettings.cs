using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace Tsr.Identity.Api;

/// <summary>
/// Which Firebase project the API trusts and where its keys come from. Fails closed: a missing
/// project id stops start-up, and the emulator (unsigned tokens) is on only when every one of PHP's
/// four gate conditions holds (web/firebase-id-token-verifier.php), otherwise start-up stops.
/// </summary>
internal sealed record FirebaseSettings(string ProjectId, string? EmulatorHost)
{
    private const string ProjectKey = "TSR_FIREBASE_PROJECT_ID";
    private const string EmulatorKey = "TSR_AUTH_EMULATOR_HOST";
    private const string EmulatorProjectPrefix = "demo-";

    private static readonly string[] EmulatorHosts = ["firebase-emulator:9099", "127.0.0.1:9099", "localhost:9099"];

    public bool UseEmulator => EmulatorHost is not null;

    public string Issuer => "https://securetoken.google.com/" + ProjectId;

    public static FirebaseSettings Create(IConfiguration configuration, IHostEnvironment environment)
    {
        ArgumentNullException.ThrowIfNull(configuration);
        ArgumentNullException.ThrowIfNull(environment);

        var projectId = configuration[ProjectKey];
        if (string.IsNullOrWhiteSpace(projectId))
        {
            throw new InvalidOperationException(ProjectKey + " is not set. The API cannot verify sign-ins without it.");
        }

        var host = configuration[EmulatorKey];
        if (string.IsNullOrEmpty(host))
        {
            return new FirebaseSettings(projectId, null);
        }

        var failed = new List<string>();
        if (!environment.IsDevelopment())
        {
            failed.Add("environment");
        }

        if (!projectId.StartsWith(EmulatorProjectPrefix, StringComparison.Ordinal))
        {
            failed.Add("project");
        }

        if (!EmulatorHosts.Contains(host))
        {
            failed.Add("host");
        }

        if (failed.Count > 0)
        {
            throw new InvalidOperationException(
                EmulatorKey + " is set but the emulator gate failed on: " + string.Join(", ", failed) + ".");
        }

        return new FirebaseSettings(projectId, host);
    }
}
