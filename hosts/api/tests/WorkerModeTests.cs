using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// The start-up rules of the worker run mode: workers exist only with <c>--workers</c> and only those named in <c>TSR_WORKERS</c>; an unknown name refuses to start; with nothing named the process starts and does nothing.
/// The rules sit in <see cref="WorkerMode"/> so they are tested without running a host that never ends.
/// </summary>
public sealed class WorkerModeTests
{
    private static int Workers(IServiceCollection services) => services.Count(d => d.ServiceType == typeof(IHostedService));

    [Test]
    public void Without_the_run_mode_no_worker_is_registered_even_when_the_setting_names_one()
    {
        var services = new ServiceCollection();

        var enabled = WorkerMode.Register(services, workersMode: false, "push-drain");

        Assert.That(Workers(services), Is.Zero);
        Assert.That(enabled, Is.Empty);
    }

    [Test]
    public void With_the_run_mode_a_named_worker_is_registered()
    {
        var services = new ServiceCollection();

        var enabled = WorkerMode.Register(services, workersMode: true, "push-drain");

        Assert.That(Workers(services), Is.EqualTo(1));
        Assert.That(enabled, Is.EqualTo(["push-drain"]));
    }

    [Test]
    public void The_search_feed_is_a_known_worker_and_is_registered_by_its_name()
    {
        var services = new ServiceCollection();

        var enabled = WorkerMode.Register(services, workersMode: true, "search-feed");

        Assert.That(WorkerMode.KnownNames, Does.Contain("search-feed"));
        Assert.That(Workers(services), Is.EqualTo(1));
        Assert.That(enabled, Is.EqualTo(["search-feed"]));
    }

    [Test]
    public void A_name_is_trimmed_and_a_repeated_one_is_registered_once()
    {
        var services = new ServiceCollection();

        var enabled = WorkerMode.Register(services, workersMode: true, " Push-Drain , push-drain ,");

        Assert.That(Workers(services), Is.EqualTo(1));
        Assert.That(enabled, Is.EqualTo(["push-drain"]));
    }

    [TestCase(null)]
    [TestCase("")]
    [TestCase("  ,  ")]
    public void With_the_run_mode_and_no_names_it_starts_and_registers_nothing(string? setting)
    {
        var services = new ServiceCollection();

        var enabled = WorkerMode.Register(services, workersMode: true, setting);

        Assert.That(Workers(services), Is.Zero);
        Assert.That(enabled, Is.Empty);
    }

    [Test]
    public void An_unknown_name_refuses_to_start_and_says_which_and_what_is_known()
    {
        var error = Assert.Throws<InvalidOperationException>(() => WorkerMode.Register(new ServiceCollection(), workersMode: true, "push-drain,nonsense"));

        Assert.That(error!.Message, Does.Contain("nonsense").And.Contain("TSR_WORKERS").And.Contain("push-drain"));
    }

    [Test]
    public void An_unknown_name_is_refused_only_in_the_run_mode()
    {
        Assert.DoesNotThrow(() => WorkerMode.Register(new ServiceCollection(), workersMode: false, "nonsense"));
    }

    [Test]
    public async Task The_entry_point_refuses_an_unknown_name_with_the_run_mode()
    {
        var entry = typeof(Program).Assembly.EntryPoint ?? throw new InvalidOperationException("The API assembly has no entry point.");
        // --workers goes last: the command line reader takes the argument after a bare switch as its value.
        string[] args = ["--environment=Production", "--TSR_DB=Host=unused", "--TSR_WORKERS=nonsense", "--workers"];

        var error = await Assert.ThrowsAsync<System.Reflection.TargetInvocationException>(async () =>
        {
            var result = await Task.Run(() => entry.Invoke(null, [args]));
            if (result is Task task)
            {
                await task;
            }
        });

        Assert.That(error!.InnerException, Is.InstanceOf<InvalidOperationException>());
        Assert.That(error.InnerException!.Message, Does.Contain("nonsense"));
    }

    private sealed class OneLine : Microsoft.Extensions.Logging.ILogger
    {
        public List<string> Lines { get; } = [];

        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull => null;

        public bool IsEnabled(Microsoft.Extensions.Logging.LogLevel logLevel) => true;

        public void Log<TState>(Microsoft.Extensions.Logging.LogLevel logLevel, Microsoft.Extensions.Logging.EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            Lines.Add(formatter(state, exception));
    }

    [Test]
    public void With_no_worker_named_one_line_says_the_process_does_nothing_and_which_setting_to_set()
    {
        var log = new OneLine();

        WorkerMode.Announce(log, []);

        Assert.That(log.Lines, Has.Count.EqualTo(1));
        Assert.That(log.Lines[0], Does.Contain("TSR_WORKERS").And.Contain("does nothing"));
    }

    [Test]
    public void The_normal_api_host_runs_no_worker_even_with_the_setting_set()
    {
        using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseSetting("TSR_DB", "Host=unused");
            builder.UseSetting("TSR_FIREBASE_PROJECT_ID", "demo-tsr-test");
            builder.UseSetting("TSR_AUTH_EMULATOR_HOST", "localhost:9099");
            builder.UseSetting("TSR_GOTENBERG_URL", "http://gotenberg.invalid:3000");
            builder.UseSetting("TSR_WORKERS", "push-drain");
        });

        var hosted = factory.Services.GetServices<IHostedService>();

        Assert.That(hosted.OfType<PeriodicWorker>(), Is.Empty);
    }
}
