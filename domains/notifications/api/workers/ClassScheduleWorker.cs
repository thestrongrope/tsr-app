using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Workers;

/// <summary>The scheduled class notification sender on its timer: one <see cref="ClassScheduleSend"/> tick a minute, started only by the run mode <c>--workers</c> with <c>class-schedules</c> in <c>TSR_WORKERS</c>.</summary>
internal sealed class ClassScheduleWorker(IServiceScopeFactory scopes, ILogger<ClassScheduleWorker> log) : PeriodicWorker(scopes, log)
{
    public const string WorkerName = "class-schedules";

    private static readonly TimeSpan TickEvery = TimeSpan.FromMinutes(1);

    public override string Name => WorkerName;

    protected override TimeSpan Interval => TickEvery;

    protected override async Task TickAsync(IServiceProvider services, CancellationToken ct) =>
        await ClassScheduleSend.TickAsync(
            services.GetRequiredService<NpgsqlDataSource>(),
            services.GetRequiredService<Permissions>(),
            services.GetRequiredService<TimeProvider>(),
            Log,
            ct);
}
