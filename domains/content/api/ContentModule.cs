using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Tsr.Content.Api.Domain;
using Tsr.Content.Api.Features.HolyQuran;
using Tsr.Content.Api.Features.ListPublishedArticles;
using Tsr.Content.Api.Features.V1Article;
using Tsr.Content.Api.Features.V1Articles;
using Tsr.Content.Api.Features.V1Categories;
using Tsr.Content.Api.Features.V1Publications;
using Tsr.Content.Api.Features.V1Tags;
using Tsr.Content.Api.Features.V1Videos;
using Tsr.Content.Api.Workers;
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
        // The latest videos: the channel's public feed over HTTP (10 seconds and 2 MB at most a call, no redirect followed), kept in memory by one LatestVideos.
        services.AddHttpClient(YouTubeFeed.ClientName, YouTubeFeed.Configure).ConfigurePrimaryHttpMessageHandler(YouTubeFeed.Handler);
        services.AddSingleton<IVideoFeed, YouTubeFeed>();
        services.AddSingleton<LatestVideos>();
        return services;
    }

    /// <summary>The background workers this domain owns, by the name written in <c>TSR_WORKERS</c>.</summary>
    public static readonly IReadOnlyList<string> WorkerNames = [ContentRefreshWorker.WorkerName];

    /// <summary>Registers the workers named in <paramref name="enabled"/> (the host has already refused unknown names). Called only in the run mode <c>--workers</c>.</summary>
    public static IServiceCollection AddContentWorkers(this IServiceCollection services, IReadOnlySet<string> enabled)
    {
        ArgumentNullException.ThrowIfNull(enabled);
        if (enabled.Contains(ContentRefreshWorker.WorkerName))
        {
            services.AddHostedService<ContentRefreshWorker>();
        }

        return services;
    }

    public static IEndpointRouteBuilder MapContent(this IEndpointRouteBuilder routes)
    {
        routes.MapListPublishedArticles();
        routes.MapHolyQuran();
        routes.MapV1Articles();
        routes.MapV1Article();
        routes.MapV1Categories();
        routes.MapV1Tags();
        routes.MapV1Publications();
        routes.MapV1Videos();
        return routes;
    }
}
