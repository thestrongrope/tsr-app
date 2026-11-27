using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Tsr.Search.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Search.Api.Workers;

/// <summary>
/// The Library search feed on its timer: one full reconcile of the article index at start and then every 10 minutes (so the index matches the published articles within 10 minutes, SRCH-R17), started only by the run mode
/// <c>--workers</c> with <c>library-search-feed</c> in <c>TSR_WORKERS</c>. Separate from <c>search-feed</c>, so production can switch the Library indexes on alone.
/// </summary>
internal sealed class LibraryFeedWorker(IServiceScopeFactory scopes, ILogger<LibraryFeedWorker> log, LibraryFeed feed) : PeriodicWorker(scopes, log)
{
    public const string WorkerName = "library-search-feed";

    private static readonly TimeSpan TickEvery = TimeSpan.FromMinutes(10);

    public override string Name => WorkerName;

    protected override TimeSpan Interval => TickEvery;

    // The start-up race: the first run may come before the articles are copied. Retry soon, a bounded number of times (LibraryFeed), then the normal interval.
    protected override TimeSpan? DelayBeforeRetry => feed.RetryDelay;

    protected override async Task TickAsync(IServiceProvider services, CancellationToken ct) =>
        _ = await feed.TickAsync(services.GetRequiredService<ILibraryIndex>(), services.GetRequiredService<ArticleFeedSource>(), Log, ct);
}
