using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Tsr.Access.Api.Features.MePermission;
using Tsr.Access.Api.Features.MePermissions;
using Tsr.Access.Api.Features.UserPermissions;
using Tsr.Shared.Api;

namespace Tsr.Access.Api;

/// <summary>
/// access (AuthZ): what a caller may do. Public interface of the module: <see cref="Permissions"/>, its
/// target and result types, and the one port <see cref="IClassScopes"/> that <c>classes</c> will supply.
/// Every other domain lists "access" as a dependency, because every handler checks a permission.
/// </summary>
public static class AccessModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). access uses none; classes will supply a port, not be used.</summary>
    public static readonly IReadOnlyList<string> Dependencies = [];

    /// <summary>
    /// Registers access. The default <see cref="IClassScopes"/> answers "no classes"; a domain that supplies the
    /// real one registers it before this call, and the default then steps aside.
    /// </summary>
    public static IServiceCollection AddAccess(this IServiceCollection services)
    {
        services.AddDomainContext<AccessContext>(AccessContext.SchemaName);
        services.TryAddScoped<IClassScopes, NoClasses>();
        services.AddScoped(provider => new Permissions(
            provider.GetRequiredService<AccessContext>(),
            provider.GetRequiredService<IClassScopes>()));
        services.AddScoped<MePermissionsHandler>();
        services.AddScoped<MePermissionHandler>();
        services.AddScoped<UserPermissionsHandler>();
        return services;
    }

    public static IEndpointRouteBuilder MapAccess(this IEndpointRouteBuilder routes)
    {
        routes.MapMePermissions();
        routes.MapMePermission();
        routes.MapUserPermissions();
        routes.MapPlannedRoutes();
        return routes;
    }
}
