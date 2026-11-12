using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Tsr.Search.Api.Domain;
using Tsr.Search.Api.Features.Search;

namespace Tsr.Search.Api;

/// <summary>
/// search: the read model behind <c>GET /search</c>. No tables: the index lives in Elasticsearch (settings <c>TSR_ELASTICSEARCH_URL</c> and
/// <c>TSR_ELASTICSEARCH_PASSWORD</c>, both optional), fed by a worker that is not built yet (docs/specs/initial-build/lane-search-notes.md).
/// It reads other domains only through their published views, and asks <c>access</c> what the caller may see.
/// </summary>
public static class SearchModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7).</summary>
    public static readonly IReadOnlyList<string> Dependencies = ["access"];

    public static IServiceCollection AddSearch(this IServiceCollection services)
    {
        services.AddSingleton(provider =>
        {
            var configuration = provider.GetRequiredService<IConfiguration>();
            return SearchSettings.From(configuration[SearchSettings.UrlKey], configuration[SearchSettings.PasswordKey]);
        });
        // Without a valid address the index is "not configured": every kind answers as unavailable, as PHP does when Elasticsearch is down.
        services.AddSingleton<ISearchIndex>(provider =>
        {
            var settings = provider.GetRequiredService<SearchSettings>();
            return settings.Url is null ? new UnconfiguredSearchIndex() : new ElasticSearchIndex(settings);
        });
        services.AddScoped<ISearchFacts, SearchFacts>();
        services.AddScoped<SearchEngine>();
        return services;
    }

    public static IEndpointRouteBuilder MapSearch(this IEndpointRouteBuilder routes)
    {
        routes.MapSearchRoute();
        return routes;
    }
}
