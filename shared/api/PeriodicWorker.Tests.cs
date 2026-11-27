using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using NUnit.Framework;

namespace Tsr.Shared.Api;

public sealed class PeriodicWorkerTests
{
    private sealed class Scoped;

    private sealed class CaptureLog : ILogger
    {
        public List<string> Lines { get; } = [];

        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
        {
            lock (Lines)
            {
                Lines.Add(formatter(state, exception) + (exception is null ? string.Empty : " | exception attached"));
            }
        }
    }

    private sealed class TestWorker(IServiceScopeFactory scopes, ILogger log, Func<int, IServiceProvider, CancellationToken, Task> tick, int stopAfter) : PeriodicWorker(scopes, log)
    {
        private readonly TaskCompletionSource done = new(TaskCreationOptions.RunContinuationsAsynchronously);
        private int ticks;

        public override string Name => "test-worker";

        protected override TimeSpan Interval => TimeSpan.FromMilliseconds(20);

        public Task Done => done.Task;

        protected override async Task TickAsync(IServiceProvider services, CancellationToken ct)
        {
            var number = Interlocked.Increment(ref ticks);
            try
            {
                await tick(number, services, ct);
            }
            finally
            {
                if (number >= stopAfter)
                {
                    done.TrySetResult();
                }
            }
        }
    }

    private sealed class RetryingWorker(IServiceScopeFactory scopes, ILogger log, int retries) : PeriodicWorker(scopes, log)
    {
        private int ticks;

        public override string Name => "retrying-worker";

        public int Ticks => Volatile.Read(ref ticks);

        // An hour: only the retry hook can make a second tick happen within this test.
        protected override TimeSpan Interval => TimeSpan.FromHours(1);

        protected override TimeSpan? DelayBeforeRetry => Ticks <= retries ? TimeSpan.FromMilliseconds(5) : null;

        protected override Task TickAsync(IServiceProvider services, CancellationToken ct)
        {
            Interlocked.Increment(ref ticks);
            return Task.CompletedTask;
        }
    }

    [Test]
    public async Task A_worker_that_asks_for_a_retry_ticks_again_after_the_delay_and_then_waits_for_the_interval()
    {
        await using var provider = Services();
        using var worker = new RetryingWorker(provider.GetRequiredService<IServiceScopeFactory>(), new CaptureLog(), retries: 3);

        await worker.StartAsync(CancellationToken.None);
        var deadline = DateTime.UtcNow.AddSeconds(10);
        while (worker.Ticks < 4 && DateTime.UtcNow < deadline)
        {
            await Task.Delay(10);
        }

        await Task.Delay(200);
        await worker.StopAsync(CancellationToken.None);
        Assert.That(worker.Ticks, Is.EqualTo(4), "one tick, three retries, then the one-hour interval");
    }

    private static ServiceProvider Services() => new ServiceCollection().AddScoped<Scoped>().BuildServiceProvider();

    private static async Task WaitAsync(Task task) => await task.WaitAsync(TimeSpan.FromSeconds(10));

    [Test]
    public async Task It_ticks_again_and_again_each_in_its_own_scope()
    {
        using var services = Services();
        var seen = new List<Scoped>();
        using var worker = new TestWorker(
            services.GetRequiredService<IServiceScopeFactory>(),
            new CaptureLog(),
            (_, provider, _) =>
            {
                lock (seen)
                {
                    seen.Add(provider.GetRequiredService<Scoped>());
                }

                return Task.CompletedTask;
            },
            3);

        await worker.StartAsync(CancellationToken.None);
        await WaitAsync(worker.Done);
        await worker.StopAsync(CancellationToken.None);

        Assert.That(seen, Has.Count.GreaterThanOrEqualTo(3));
        Assert.That(seen.Distinct().Count(), Is.EqualTo(seen.Count), "a fresh scope for every tick");
    }

    [Test]
    public async Task A_failing_tick_is_logged_by_type_name_only_and_the_loop_goes_on()
    {
        using var services = Services();
        var log = new CaptureLog();
        using var worker = new TestWorker(
            services.GetRequiredService<IServiceScopeFactory>(), log, (number, _, _) => number == 1 ? throw new InvalidOperationException("secret-device-token") : Task.CompletedTask, 3);

        await worker.StartAsync(CancellationToken.None);
        await WaitAsync(worker.Done);
        await worker.StopAsync(CancellationToken.None);

        var lines = string.Join('\n', log.Lines);
        Assert.That(lines, Does.Contain("InvalidOperationException").And.Contain("test-worker"));
        Assert.That(lines, Does.Not.Contain("secret-device-token"));
        Assert.That(lines, Does.Not.Contain("exception attached"), "the exception object (its message and stack) is never logged");
    }

    [Test]
    public async Task A_tick_cancelled_by_a_timeout_while_the_host_runs_is_logged_by_type_name_and_the_loop_goes_on()
    {
        using var services = Services();
        var log = new CaptureLog();
        using var worker = new TestWorker(
            services.GetRequiredService<IServiceScopeFactory>(), log, (number, _, _) => number == 1 ? throw new TaskCanceledException("secret-device-token") : Task.CompletedTask, 3);

        await worker.StartAsync(CancellationToken.None);
        await WaitAsync(worker.Done);
        await worker.StopAsync(CancellationToken.None);

        var lines = string.Join('\n', log.Lines);
        Assert.That(lines, Does.Contain("TaskCanceledException"));
        Assert.That(lines, Does.Not.Contain("secret-device-token"));
    }

    [Test]
    public async Task Stopping_ends_the_loop_and_a_tick_in_flight_sees_the_cancellation()
    {
        using var services = Services();
        var started = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var cancelled = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        using var worker = new TestWorker(
            services.GetRequiredService<IServiceScopeFactory>(),
            new CaptureLog(),
            async (_, _, ct) =>
            {
                started.TrySetResult();
                try
                {
                    await Task.Delay(Timeout.Infinite, ct);
                }
                catch (OperationCanceledException)
                {
                    cancelled.TrySetResult();
                    throw;
                }
            },
            int.MaxValue);

        await worker.StartAsync(CancellationToken.None);
        await WaitAsync(started.Task);
        await worker.StopAsync(CancellationToken.None);

        await WaitAsync(cancelled.Task);
    }
}
