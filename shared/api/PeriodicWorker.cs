using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Tsr.Shared.Api;

/// <summary>
/// The loop every background worker shares (run mode <c>--workers</c>, setting <c>TSR_WORKERS</c>). A worker is ONE tick (find due work, claim it, do it, record it) in <see cref="TickAsync"/>; this class only
/// calls it now and then: once at start, then every <see cref="Interval"/>, each time in a fresh DI scope, until the host stops. A tick that throws is logged by the exception's type name only (a message
/// can hold a device token or an address) and the loop goes on. Ticks never overlap within one worker (the next waits for the last). No scheduling library.
/// </summary>
public abstract partial class PeriodicWorker(IServiceScopeFactory scopes, ILogger log) : BackgroundService
{
    /// <summary>The worker's name as it is written in <c>TSR_WORKERS</c>; used in log lines.</summary>
    public abstract string Name { get; }

    /// <summary>The logger a tick may use (the same one the loop reports failures to).</summary>
    protected ILogger Log => log;

    /// <summary>The wait between two ticks.</summary>
    protected abstract TimeSpan Interval { get; }

    /// <summary>Asked after every tick: a delay shorter than <see cref="Interval"/> after which to run another tick at once (for work that was not ready yet), or null to wait for the interval. The worker bounds its own retries.</summary>
    protected virtual TimeSpan? DelayBeforeRetry => null;

    /// <summary>One tick. <paramref name="services"/> is a scope made for this tick and disposed after it.</summary>
    protected abstract Task TickAsync(IServiceProvider services, CancellationToken ct);

    /// <summary>One tick in its own scope, as the loop runs it. A failure is logged and swallowed here (the loop must go on), including a cancellation that is not the host stopping (an HTTP timeout); only the host stopping passes through.</summary>
    public async Task RunTickAsync(CancellationToken ct)
    {
        try
        {
            await using var scope = scopes.CreateAsyncScope();
            await TickAsync(scope.ServiceProvider, ct);
        }
        catch (Exception e) when (e is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            LogTickFailed(log, Name, e.GetType().Name);
        }
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await Task.Yield();
        using var timer = new PeriodicTimer(Interval);
        try
        {
            do
            {
                await RunTickAsync(stoppingToken);
                while (DelayBeforeRetry is { } delay)
                {
                    await Task.Delay(delay, stoppingToken);
                    await RunTickAsync(stoppingToken);
                }
            }
            while (await timer.WaitForNextTickAsync(stoppingToken));
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // The host is stopping: the loop ends here.
        }
    }

    [LoggerMessage(Level = LogLevel.Error, Message = "Worker {Worker}: a tick failed with {Kind}")]
    private static partial void LogTickFailed(ILogger logger, string worker, string kind);
}
