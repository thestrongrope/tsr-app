using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Tsr.Platform.Api.Domain;
using Tsr.Platform.Api.Features.AppVersion;
using Tsr.Platform.Api.Features.GeoCities;
using Tsr.Platform.Api.Features.GeoCountries;
using Tsr.Platform.Api.Features.GeoPostal;
using Tsr.Platform.Api.Features.Health;
using Tsr.Platform.Api.Features.ReleaseNotes;
using Tsr.Platform.Api.Features.SubmitFeedback;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api;

/// <summary>
/// platform: app version, release notes, health, feedback, geo. Public interface of the module.
/// To add a slice: create features/&lt;slice&gt;/, register its handler in AddPlatform and map its
/// endpoint in MapPlatform (see .claude/skills/add-slice).
/// </summary>
public static class PlatformModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7).</summary>
    public static readonly IReadOnlyList<string> Dependencies = ["access"];

    public static IServiceCollection AddPlatform(this IServiceCollection services)
    {
        services.AddDomainContext<PlatformContext>(PlatformContext.SchemaName);
        services.AddScoped<SubmitFeedbackHandler>();
        services.AddSingleton<AppCatalogSource>();
        services.AddScoped<AppVersionHandler>();
        services.AddScoped<ReleaseNotesHandler>();
        services.AddSingleton<GeoRateLimit>();
        services.AddScoped<GeoGate>();
        services.AddScoped<GeoCountriesHandler>();
        services.AddScoped<GeoPostalHandler>();
        services.AddScoped<GeoCitiesHandler>();
        return services;
    }

    public static IEndpointRouteBuilder MapPlatform(this IEndpointRouteBuilder routes)
    {
        routes.MapHealth();
        routes.MapSubmitFeedback();
        routes.MapAppVersion();
        routes.MapReleaseNotes();
        routes.MapGeoCountries();
        routes.MapGeoPostal();
        routes.MapGeoCities();
        return routes;
    }
}
