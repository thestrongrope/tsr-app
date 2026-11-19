using System.Collections.Concurrent;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using NUnit.Framework;
using Tsr.Content.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// The one-off content load of a deploy (LIB-R32, LIB-R34, LIB-R35): <see cref="ContentModule.LoadContentAsync"/> against a real database as the limited role.
/// The directory is the setting TSR_CONTENT_DIR, as in production. Each test writes its own content directory; invented text only.
/// </summary>
public sealed class ContentLoadTests
{
    private const string Slugs = "select coalesce(string_agg(slug, ',' order by slug), '') from content.published_articles";

    private sealed class CaptureProvider : ILoggerProvider
    {
        public ConcurrentQueue<(LogLevel Level, string Line)> Lines { get; } = new();

        public ILogger CreateLogger(string categoryName) => new CaptureLogger(Lines);

        public void Dispose()
        {
        }
    }

    private sealed class CaptureLogger(ConcurrentQueue<(LogLevel Level, string Line)> lines) : ILogger
    {
        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            lines.Enqueue((logLevel, formatter(state, exception)));
    }

    private CaptureProvider log = null!;
    private ContentTestFiles files = null!;
    private WebApplicationFactory<Program>? factory;

    [SetUp]
    public async Task StartAsync()
    {
        files = new ContentTestFiles();
        log = new CaptureProvider();
        await TestDatabase.ExecuteAsync("truncate content.published_articles, content.categories, content.publications, content.refresh_state");
    }

    [TearDown]
    public void Stop()
    {
        factory?.Dispose();
        log.Dispose();
        files.Dispose();
    }

    private async Task<bool> LoadAsync(string directory)
    {
        factory = TestApi.Create().WithWebHostBuilder(builder =>
        {
            builder.UseSetting("TSR_CONTENT_DIR", directory);
            builder.ConfigureLogging(logging => logging.AddProvider(log));
        });
        return await ContentModule.LoadContentAsync(factory.Services, CancellationToken.None);
    }

    private static Task<string> SlugsAsync() => TestDatabase.ScalarAsync<string>(Slugs, TestDatabase.OwnerConnection);

    private void TwoArticles()
    {
        files.Article("first-article");
        files.Article("second-article", day: 2);
        files.Category("shared-category", "title: Shared\norder: 1");
    }

    [Test]
    public async Task A_load_copies_the_content_directory_and_reports_success()
    {
        TwoArticles();

        var loaded = await LoadAsync(files.Root);
        var slugs = await SlugsAsync();

        Assert.Multiple(() =>
        {
            Assert.That(loaded, Is.True);
            Assert.That(slugs, Is.EqualTo("first-article,second-article"));
        });
    }

    [Test]
    public async Task A_load_that_fails_keeps_the_last_set_and_reports_failure()
    {
        TwoArticles();
        Assert.That(await LoadAsync(files.Root), Is.True);

        var loaded = await LoadAsync(Path.Combine(files.Root, "missing"));
        var slugs = await SlugsAsync();

        Assert.Multiple(() =>
        {
            Assert.That(loaded, Is.False);
            Assert.That(slugs, Is.EqualTo("first-article,second-article"));
        });
    }

    [Test]
    public async Task A_load_that_fails_logs_the_cause_as_an_error()
    {
        _ = await LoadAsync(Path.Combine(files.Root, "missing"));

        var errors = log.Lines.Where(l => l.Level == LogLevel.Error).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(errors, Has.Count.EqualTo(1));
            Assert.That(errors[0].Line, Does.Contain("no content directory"));
        });
    }
}
