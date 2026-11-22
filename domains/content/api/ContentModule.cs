using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
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
public static partial class ContentModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). Public reads need no access check.</summary>
    public static readonly IReadOnlyList<string> Dependencies = [];

    public static IServiceCollection AddContent(this IServiceCollection services)
    {
        services.AddDomainContext<ContentContext>(ContentContext.SchemaName);
        services.AddTsrDataSource();
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

    /// <summary>
    /// The one-off content load of a deploy (the run mode <c>--load-content</c>): one refresh over the directory <c>TSR_CONTENT_DIR</c> names. Returns true when the tables now hold the files or already did,
    /// false when the last set was kept (the cause is logged as an error). Never throws for a bad directory; a database failure propagates.
    /// </summary>
    public static async Task<bool> LoadContentAsync(IServiceProvider services, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(services);
        var log = services.GetRequiredService<ILoggerFactory>().CreateLogger("Tsr.Content.Api.ContentLoad");
        await using var scope = services.CreateAsyncScope();
        var outcome = await ContentRefresh.TickAsync(
            scope.ServiceProvider.GetRequiredService<ContentContext>(),
            scope.ServiceProvider.GetRequiredService<IConfiguration>()[ContentRefreshWorker.DirectorySetting],
            scope.ServiceProvider.GetRequiredService<TimeProvider>(),
            log,
            ct);
        switch (outcome.Result)
        {
            case RefreshResult.Kept:
                LogLoadFailed(log, outcome.Cause ?? "unknown");
                return false;
            case RefreshResult.Unchanged:
                LogLoadUnchanged(log);
                return true;
            default:
                return true;
        }
    }

    [LoggerMessage(Level = LogLevel.Error, Message = "Content load failed, the last set is kept: {Cause}")]
    private static partial void LogLoadFailed(ILogger logger, string cause);

    [LoggerMessage(Level = LogLevel.Information, Message = "Content load: the database already holds these files")]
    private static partial void LogLoadUnchanged(ILogger logger);

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
