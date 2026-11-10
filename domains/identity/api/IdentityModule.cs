using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Tsr.Identity.Api.Features.LinkAccount;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>identity (AuthN): who is calling. Public interface of the module.</summary>
public static class IdentityModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). identity uses none.</summary>
    public static readonly IReadOnlyList<string> Dependencies = [];

    /// <summary>
    /// Registers only identity's tables, for the one-off migrate job, which serves no requests and
    /// so needs no Firebase settings. The API itself starts with <see cref="AddIdentity"/>.
    /// </summary>
    public static IServiceCollection AddIdentityTables(this IServiceCollection services)
    {
        services.AddDomainContext<IdentityContext>(IdentityContext.SchemaName);
        return services;
    }

    /// <summary>
    /// Registers sign-in. Fails closed: without a Firebase project id, or with the emulator on outside
    /// Development, this throws and the API does not start (<see cref="FirebaseSettings"/>).
    /// </summary>
    public static IServiceCollection AddIdentity(this IServiceCollection services, IHostEnvironment env, IConfiguration configuration)
    {
        var settings = FirebaseSettings.Create(configuration, env);
        services.AddIdentityTables();
        services.AddFirebaseVerification(settings);
        services.AddScoped<MemberDirectory>();
        return services;
    }

    public static IApplicationBuilder UseIdentity(this IApplicationBuilder app) =>
        app.UseMiddleware<CallerMiddleware>();

    public static IEndpointRouteBuilder MapIdentity(this IEndpointRouteBuilder routes)
    {
        routes.MapLinkAccount();
        return routes;
    }
}
