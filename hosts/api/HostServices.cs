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
    public static void AddDomains(IServiceCollection services, IHostEnvironment environment, IConfiguration configuration, RunMode mode)
    {
        // Registration order is migration order: identity owns users, which other domains reference.
        // The migrate job serves no requests and resolves no slice: it registers identity's tables but no caller verifier, so it runs in any environment.
        // The worker host loads the same modules as the API (other modules' services need identity's), so it needs the API's identity settings too.
        if (mode is RunMode.Migrate)
        {
            services.AddIdentityTables();
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
        // Registered after platform, whose migration creates the collation classes uses.
        services.AddClasses();
        services.AddAssessment();
        services.AddNotifications();
        services.AddSearch();
    }
}
