using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Tsr.Search.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Search.Api.Workers;

/// <summary>The search feed on its timer: one full reconcile at start and then every 10 minutes, started only by the run mode <c>--workers</c> with <c>search-feed</c> in <c>TSR_WORKERS</c>.</summary>
internal sealed class SearchFeedWorker(IServiceScopeFactory scopes, ILogger<SearchFeedWorker> log) : PeriodicWorker(scopes, log)
{
    public const string WorkerName = "search-feed";

    private static readonly TimeSpan TickEvery = TimeSpan.FromMinutes(10);

    public override string Name => WorkerName;

    protected override TimeSpan Interval => TickEvery;

    protected override async Task TickAsync(IServiceProvider services, CancellationToken ct) =>
        _ = await SearchFeed.TickAsync(
            services.GetRequiredService<ISearchIndexWriter>(),
            services.GetRequiredService<ISearchDocumentSource>(),
            Log,
            ct);
}
