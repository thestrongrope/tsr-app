using Microsoft.Extensions.DependencyInjection;
using Tsr.Shared.Api;

namespace Tsr.Access.Api;

/// <summary>
/// access (AuthZ): what a caller may do. Public interface of the module: <see cref="Permissions"/>.
/// Every other domain lists "access" as a dependency, because every handler checks a permission.
/// </summary>
public static class AccessModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). access uses none.</summary>
    public static readonly IReadOnlyList<string> Dependencies = [];

    public static IServiceCollection AddAccess(this IServiceCollection services)
    {
        services.AddDomainContext<AccessContext>(AccessContext.SchemaName);
        services.AddScoped(provider => new Permissions(provider.GetRequiredService<AccessContext>()));
        return services;
    }
}
