using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Tsr.Content.Api.Features.ListPublishedArticles;
using Tsr.Shared.Api;

namespace Tsr.Content.Api;

/// <summary>content: Quran, articles, lectures, books. Registration and routes of the module.</summary>
public static class ContentModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). Public reads need no access check.</summary>
    public static readonly IReadOnlyList<string> Dependencies = [];

    public static IServiceCollection AddContent(this IServiceCollection services)
    {
        services.AddDomainContext<ContentContext>(ContentContext.SchemaName);
        services.AddScoped<ListPublishedArticlesHandler>();
        return services;
    }

    public static IEndpointRouteBuilder MapContent(this IEndpointRouteBuilder routes)
    {
        routes.MapListPublishedArticles();
        routes.MapPlannedRoutes();
        return routes;
    }
}
