using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Npgsql;
using Tsr.Notifications.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Workers;

/// <summary>The push drain on its timer: one <see cref="PushDrain"/> tick a minute, started only by the run mode <c>--workers</c> with <c>push-drain</c> in <c>TSR_WORKERS</c>.</summary>
internal sealed class PushDrainWorker(IServiceScopeFactory scopes, ILogger<PushDrainWorker> log) : PeriodicWorker(scopes, log)
{
    public const string WorkerName = "push-drain";

    private static readonly TimeSpan TickEvery = TimeSpan.FromMinutes(1);

    public override string Name => WorkerName;

    protected override TimeSpan Interval => TickEvery;

    protected override async Task TickAsync(IServiceProvider services, CancellationToken ct) =>
        await PushDrain.TickAsync(
            services.GetRequiredService<NpgsqlDataSource>(),
            services.GetRequiredService<IPushSender>(),
            services.GetRequiredService<TimeProvider>(),
            Log,
            ct);
}
