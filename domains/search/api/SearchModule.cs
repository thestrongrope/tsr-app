using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace Tsr.Search.Api;

/// <summary>
/// search: the read model behind <c>GET /search</c>. Routes only so far (a placeholder, Planned.cs), no tables and no
/// public interface yet. It will read other domains through their listed public interfaces, never their tables.
/// </summary>
public static class SearchModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). None yet.</summary>
    public static readonly IReadOnlyList<string> Dependencies = [];

    public static IServiceCollection AddSearch(this IServiceCollection services) => services;

    public static IEndpointRouteBuilder MapSearch(this IEndpointRouteBuilder routes)
    {
        routes.MapPlannedRoutes();
        return routes;
    }
}
