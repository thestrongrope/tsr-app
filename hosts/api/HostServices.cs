using System.Diagnostics.CodeAnalysis;
using System.Runtime.CompilerServices;
using Tsr.Access.Api;
using Tsr.Assessment.Api;
using Tsr.Classes.Api;
using Tsr.Content.Api;
using Tsr.Identity.Api;
using Tsr.Membership.Api;
using Tsr.Notifications.Api;
using Tsr.Platform.Api;
using Tsr.Search.Api;
using Tsr.Shared.Api;

namespace Tsr.Host.Api;

/// <summary>How the one API image was started: the API itself, the one-off migrate job (<c>--migrate</c>), the one-off content load (<c>--load-content</c>), or the background workers (<c>--workers</c>).</summary>
public enum RunMode
{
    Api,
    Migrate,
    LoadContent,
    Workers,
}

/// <summary>The domains' services as this host loads them, in one place so a test can build the same container <c>Program</c> builds, for each run mode.</summary>
public static class HostServices
{
    /// <summary>The run-time switch behind <see cref="CanMigrate"/>; the native publish sets it off (Tsr.Host.Api.csproj).</summary>
    public const string MigrationsSwitch = "Tsr.Host.Api.Migrations";

    /// <summary>Why <c>--migrate</c> refuses in the native build.</summary>
    public const string NoMigrations =
        "--migrate needs Entity Framework, which this native build leaves out. Run the migrate image instead (hosts/api/Dockerfile, target migrate).";

    /// <summary>
    /// True where the migrate job can run: every build but the native publish. There dynamic code is unsupported and the publish also turns the switch off,
    /// so the compiler removes every Entity Framework call behind this check and the binary holds no Entity Framework.
    /// </summary>
    [FeatureSwitchDefinition(MigrationsSwitch)]
    [FeatureGuard(typeof(RequiresDynamicCodeAttribute))]
    [FeatureGuard(typeof(RequiresUnreferencedCodeAttribute))]
    // IL4000: the analyzer proves a guard only from one bare run-time check, and none exists for trimming. Sound here: the native publish sets the
    // switch off and has no dynamic code; the JIT migrate image is not trimmed.
    [UnconditionalSuppressMessage("Trimming", "IL4000", Justification = "Off in the native publish (switch and dynamic code); the JIT build is not trimmed.")]
    public static bool CanMigrate => RuntimeFeature.IsDynamicCodeSupported && MigrationsSwitchOn;

    private static bool MigrationsSwitchOn => !AppContext.TryGetSwitch(MigrationsSwitch, out var on) || on;

    public static void AddDomains(IServiceCollection services, IHostEnvironment environment, IConfiguration configuration, RunMode mode)
    {
        // The migrate job serves no requests and resolves no slice: it registers identity's tables but no caller verifier, so it runs in any environment.
        // The worker host loads the same modules as the API (other modules' services need identity's), so it needs the API's identity settings too.
        if (mode is RunMode.Migrate)
        {
            AddMigrations(services);
        }
        else
        {
            services.AddIdentity(environment, configuration);
        }

        services.AddTsrDataSource();
        services.AddAccess();
        services.AddPlatform();
        services.AddMembership();
        services.AddContent();
        services.AddClasses();
        services.AddAssessment();
        services.AddNotifications();
        services.AddSearch();
    }

    /// <summary>Applies every domain's migrations (the migrate job). Refuses in the native build.</summary>
    public static Task MigrateAsync(IServiceProvider services, CancellationToken ct)
    {
        if (!CanMigrate)
        {
            throw new InvalidOperationException(NoMigrations);
        }

        return services.MigrateDatabasesAsync(ct);
    }

    // Registration order is migration order: identity owns users, which other domains reference; classes comes after platform, whose migration
    // creates the collation classes uses. The migrate job stays on Entity Framework migrations; the other modes register no context.
    private static void AddMigrations(IServiceCollection services)
    {
        if (!CanMigrate)
        {
            throw new InvalidOperationException(NoMigrations);
        }

        services.AddIdentityTables();
        services.AddAccessMigrations();
        services.AddPlatformMigrations();
        services.AddMembershipMigrations();
        services.AddContentMigrations();
        services.AddClassesMigrations();
        services.AddAssessmentMigrations();
        services.AddNotificationsMigrations();
    }
}
