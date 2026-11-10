using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Tsr.Identity.Api;

/// <summary>identity (AuthN): who is calling. Public interface of the module.</summary>
public static class IdentityModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). identity uses none.</summary>
    public static readonly IReadOnlyList<string> Dependencies = [];

    public static IServiceCollection AddIdentity(this IServiceCollection services, IHostEnvironment env)
    {
        if (!env.IsDevelopment())
        {
            // Fail closed: there is no production verifier in this sample yet. The Firebase
            // verifier (docs/dev/identity.md in tsr-account) lands with the foundation step.
            throw new InvalidOperationException(
                "No caller verifier for environment '" + env.EnvironmentName + "'. Only Development is supported.");
        }

        services.AddSingleton<ICallerVerifier, DevTokenVerifier>();
        return services;
    }

    public static IApplicationBuilder UseIdentity(this IApplicationBuilder app) =>
        app.UseMiddleware<CallerMiddleware>();
}
