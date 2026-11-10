using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Tsr.Platform.Api.Features.Health;
using Tsr.Platform.Api.Features.SubmitFeedback;

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
        services.AddScoped<SubmitFeedbackHandler>();
        return services;
    }

    public static IEndpointRouteBuilder MapPlatform(this IEndpointRouteBuilder routes)
    {
        routes.MapHealth();
        routes.MapSubmitFeedback();
        return routes;
    }
}
