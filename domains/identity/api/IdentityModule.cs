using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>identity (AuthN): who is calling. Public interface of the module.</summary>
public static class IdentityModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). identity uses none.</summary>
    public static readonly IReadOnlyList<string> Dependencies = [];

    /// <summary>
    /// Registers only identity's tables, for the one-off migrate job, which serves no requests and
    /// so needs no caller verifier. The API itself starts with <see cref="AddIdentity"/>.
    /// </summary>
    public static IServiceCollection AddIdentityTables(this IServiceCollection services)
    {
        services.AddDomainContext<IdentityContext>(IdentityContext.SchemaName);
        return services;
    }

    public static IServiceCollection AddIdentity(this IServiceCollection services, IHostEnvironment env)
    {
        if (!env.IsDevelopment())
        {
            // Fail closed: there is no production verifier in this sample yet. The Firebase
            // verifier (docs/dev/identity.md in tsr-account) lands with the foundation step.
            throw new InvalidOperationException(
                "No caller verifier for environment '" + env.EnvironmentName + "'. Only Development is supported.");
        }

        services.AddIdentityTables();
        services.AddSingleton<ICallerVerifier, DevTokenVerifier>();
        return services;
    }

    public static IApplicationBuilder UseIdentity(this IApplicationBuilder app) =>
        app.UseMiddleware<CallerMiddleware>();
}
