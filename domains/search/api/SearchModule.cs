using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using Tsr.Search.Api.Domain;
using Tsr.Search.Api.Features.Search;
using Tsr.Search.Api.Features.V1LectureSearch;
using Tsr.Search.Api.Features.V1Search;
using Tsr.Shared.Api;
using Tsr.Search.Api.Workers;

namespace Tsr.Search.Api;

/// <summary>
/// search: the read model behind <c>GET /search</c>. No tables: the index lives in Elasticsearch (settings <c>TSR_ELASTICSEARCH_URL</c> and
/// <c>TSR_ELASTICSEARCH_PASSWORD</c>, both optional), fed by the search-feed worker (workers/SearchFeedWorker.cs).
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
        services.AddSingleton<ISearchIndexWriter>(provider =>
        {
            var settings = provider.GetRequiredService<SearchSettings>();
            return settings.Url is null ? new UnconfiguredSearchIndex() : new ElasticSearchIndex(settings);
        });
        services.AddSingleton<ILibraryIndex>(provider =>
        {
            var settings = provider.GetRequiredService<SearchSettings>();
            return settings.Url is null ? new UnconfiguredSearchIndex() : new ElasticSearchIndex(settings);
        });
        services.AddSingleton(provider =>
        {
            var configuration = provider.GetRequiredService<IConfiguration>();
            return LectureSettings.From(configuration[LectureSettings.EmbeddingsUrlKey], configuration[LectureSettings.SemanticWeightKey], configuration[LectureSettings.LecturesFileKey]);
        });
        // The embedding service is asked only when the meaning layer is on (a weight above 0 and an address); the client gives up after 1.5 seconds.
        services.AddSingleton<IQueryEmbedder>(provider =>
        {
            var settings = provider.GetRequiredService<LectureSettings>();
            if (!settings.SemanticEnabled)
            {
                return NoQueryEmbedder.Instance;
            }

            var http = new HttpClient { BaseAddress = settings.EmbeddingsUrl, Timeout = TimeSpan.FromSeconds(5) };
            return new EmbeddingClient(http, provider.GetRequiredService<ILoggerFactory>().CreateLogger("Tsr.Search.Api.Domain.EmbeddingClient"), EmbeddingClient.Timeout);
        });
        services.TryAddSingleton<MemberRateLimit>();
        services.AddScoped<IArticleFallback, ArticleFallback>();
        services.AddScoped<ISearchFacts, SearchFacts>();
        services.AddScoped<SearchEngine>();
        return services;
    }

    /// <summary>The background workers this domain owns, by the name written in <c>TSR_WORKERS</c>.</summary>
    public static readonly IReadOnlyList<string> WorkerNames = [SearchFeedWorker.WorkerName, LibraryFeedWorker.WorkerName];

    /// <summary>Registers the workers named in <paramref name="enabled"/> (the host has already refused unknown names). Called only in the run mode <c>--workers</c>.</summary>
    public static IServiceCollection AddSearchWorkers(this IServiceCollection services, IReadOnlySet<string> enabled)
    {
        ArgumentNullException.ThrowIfNull(enabled);
        if (enabled.Contains(SearchFeedWorker.WorkerName))
        {
            services.AddScoped<ISearchDocumentSource, SearchDocumentSource>();
            services.AddHostedService<SearchFeedWorker>();
        }

        if (enabled.Contains(LibraryFeedWorker.WorkerName))
        {
            services.AddSingleton<LibraryFeed>();
            services.AddScoped<ArticleFeedSource>();
            services.AddHostedService<LibraryFeedWorker>();
        }

        return services;
    }

    public static IEndpointRouteBuilder MapSearch(this IEndpointRouteBuilder routes)
    {
        routes.MapSearchRoute();
        routes.MapV1Search();
        routes.MapV1LectureSearch();
        return routes;
    }
}
