using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Npgsql;
using Tsr.Content.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Content.Api.Workers;

/// <summary>
/// The content refresh on its timer: one refresh at start and then every 5 minutes, started only by the run mode <c>--workers</c> with <c>content-refresh</c> in <c>TSR_WORKERS</c>.
/// The content directory is the setting <c>TSR_CONTENT_DIR</c>; without it every tick keeps the last set and records why.
/// </summary>
internal sealed class ContentRefreshWorker(IServiceScopeFactory scopes, ILogger<ContentRefreshWorker> log) : PeriodicWorker(scopes, log)
{
    public const string WorkerName = "content-refresh";

    public const string DirectorySetting = "TSR_CONTENT_DIR";

    private static readonly TimeSpan TickEvery = TimeSpan.FromMinutes(5);

    public override string Name => WorkerName;

    protected override TimeSpan Interval => TickEvery;

    protected override async Task TickAsync(IServiceProvider services, CancellationToken ct) =>
        _ = await ContentRefresh.TickAsync(
            services.GetRequiredService<NpgsqlDataSource>(),
            services.GetRequiredService<IConfiguration>()[DirectorySetting],
            services.GetRequiredService<TimeProvider>(),
            Log,
            ct);
}
