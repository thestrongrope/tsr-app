using System.Diagnostics.CodeAnalysis;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;
using Tsr.Access.Api.Features.AdminPermissionGrant;
using Tsr.Access.Api.Features.AdminPermissionMember;
using Tsr.Access.Api.Features.AdminPermissionMembers;
using Tsr.Access.Api.Features.AdminPermissionRevoke;
using Tsr.Access.Api.Features.ClassAccessGrant;
using Tsr.Access.Api.Features.ClassAccessMember;
using Tsr.Access.Api.Features.ClassAccessMembers;
using Tsr.Access.Api.Features.ClassAccessOptions;
using Tsr.Access.Api.Features.ClassAccessPreview;
using Tsr.Access.Api.Features.ClassAccessRevoke;
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
        services.AddTsrDataSource();
        services.TryAddScoped<IClassScopes, NoClasses>();
        services.AddScoped(provider => new Permissions(
            provider.GetRequiredService<NpgsqlDataSource>(),
            provider.GetRequiredService<IClassScopes>()));
        services.AddScoped<MePermissionsHandler>();
        services.AddScoped<MePermissionHandler>();
        services.AddScoped<UserPermissionsHandler>();
        return services;
    }

    /// <summary>
    /// Registers access's context and migrations for the migrate job only (Entity Framework is JIT only). The host calls it
    /// in migrate mode just before <see cref="AddAccess"/>, so the migration order is unchanged.
    /// </summary>
    [RequiresUnreferencedCode("Entity Framework is JIT only: it reflects over the context.")]
    [RequiresDynamicCode("Entity Framework is JIT only: it reflects over the context.")]
    public static IServiceCollection AddAccessMigrations(this IServiceCollection services)
    {
        services.AddDomainContext<AccessContext>(AccessContext.SchemaName);
        return services;
    }

    /// <summary>
    /// Adds the <c>X-Permissions-Revision</c> response header to every request whose sign-in passed. The host calls it
    /// right after identity's middleware, which establishes the caller.
    /// </summary>
    public static IApplicationBuilder UsePermissionsRevision(this IApplicationBuilder app) =>
        app.UseMiddleware<PermissionsRevisionHeader>();

    public static IEndpointRouteBuilder MapAccess(this IEndpointRouteBuilder routes)
    {
        routes.MapMePermissions();
        routes.MapMePermission();
        routes.MapUserPermissions();
        routes.MapAdminPermissionMembers();
        routes.MapAdminPermissionMember();
        routes.MapAdminPermissionGrant();
        routes.MapAdminPermissionRevoke();
        routes.MapClassAccessMembers();
        routes.MapClassAccessMember();
        routes.MapClassAccessOptions();
        routes.MapClassAccessPreview();
        routes.MapClassAccessGrant();
        routes.MapClassAccessRevoke();
        return routes;
    }
}
