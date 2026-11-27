using System.Text.Json;
using Microsoft.Extensions.Logging;
using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>SRCH-R17: one reconcile of one Library index. An extra document is deleted; an empty source changes nothing; an unchanged source sends nothing. The index and the clock are fakes.</summary>
[TestFixture]
internal sealed class LibraryFeedTests
{
    private const string Articles = "tsr-articles";

    private sealed class FakeIndex : ILibraryIndex
    {
        public bool IsConfigured { get; set; } = true;

        public List<string> Ensured { get; } = [];

        public List<string> Bulks { get; } = [];

        public IReadOnlyList<string> Existing { get; set; } = [];

        public bool FailBulk { get; set; }

        public Task<string> SearchAsync(string index, string body, CancellationToken ct) => throw new NotSupportedException();

        public bool Created { get; set; }

        public Task<bool> EnsureIndexAsync(string index, string mappingJson, CancellationToken ct)
        {
            Ensured.Add(index + " " + mappingJson);
            return Task.FromResult(Created);
        }

        public Task<IReadOnlyList<string>> ListIdsAsync(string index, CancellationToken ct) => Task.FromResult(Existing);

        public Task BulkAsync(string ndjson, CancellationToken ct) =>
            FailBulk ? throw new SearchUnavailableException("Elasticsearch rejected part of a bulk write") : Task.Run(() => Bulks.Add(ndjson), ct);
    }

    private sealed class CaptureLog : ILogger
    {
        public List<(LogLevel Level, string Line)> Lines { get; } = [];

        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            Lines.Add((logLevel, formatter(state, exception)));
    }

    private sealed class FixedClock : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new(2030, 5, 6, 7, 8, 9, TimeSpan.Zero);
    }

    private static LibraryDocument Doc(string id, string title = "T") => new(id, $$"""{"slug":"{{id}}","title":"{{title}}"}""");

    private static Task<ReconcileReport?> RunAsync(LibraryFeed feed, FakeIndex index, IReadOnlyList<LibraryDocument> documents, ILogger? log = null) =>
        feed.ReconcileAsync(index, Articles, "{\"mappings\":{}}", documents, log ?? new CaptureLog(), CancellationToken.None);

    [Test]
    public async Task Each_document_is_written_with_its_slug_as_the_id_and_the_time_of_the_run()
    {
        var index = new FakeIndex();

        var report = await RunAsync(new LibraryFeed(new FixedClock()), index, [Doc("a"), Doc("b")]);

        Assert.That(report, Is.EqualTo(new ReconcileReport(2, 0, false)));
        Assert.That(index.Ensured, Is.EqualTo((string[])["tsr-articles {\"mappings\":{}}"]));
        var lines = index.Bulks.Single().Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.That(lines, Has.Length.EqualTo(4));
        Assert.That(lines[0], Is.EqualTo("""{"index":{"_index":"tsr-articles","_id":"a"}}"""));
        Assert.That(lines[1], Is.EqualTo("""{"slug":"a","title":"T","indexed_at":"2030-05-06T07:08:09.000Z"}"""));
        Assert.That(lines[2], Is.EqualTo("""{"index":{"_index":"tsr-articles","_id":"b"}}"""));
    }

    [Test]
    public async Task A_document_in_the_index_that_the_source_no_longer_has_is_deleted_and_the_rest_kept()
    {
        var index = new FakeIndex { Existing = ["a", "gone", "gone-too"] };

        var report = await RunAsync(new LibraryFeed(new FixedClock()), index, [Doc("a")]);

        Assert.That(report, Is.EqualTo(new ReconcileReport(1, 2, false)));
        Assert.That(index.Bulks, Has.Count.EqualTo(2));
        Assert.That(index.Bulks[1], Is.EqualTo("""
            {"delete":{"_index":"tsr-articles","_id":"gone"}}
            {"delete":{"_index":"tsr-articles","_id":"gone-too"}}

            """.ReplaceLineEndings("\n")));
    }

    [Test]
    public async Task Writes_and_deletes_go_in_batches_of_one_hundred()
    {
        var index = new FakeIndex { Existing = [.. Enumerable.Range(0, 250).Select(i => "old" + i)] };

        _ = await RunAsync(new LibraryFeed(new FixedClock()), index, [.. Enumerable.Range(0, 250).Select(i => Doc("new" + i))]);

        Assert.That(index.Bulks, Has.Count.EqualTo(6));
        Assert.That(index.Bulks[0].Split('\n', StringSplitOptions.RemoveEmptyEntries), Has.Length.EqualTo(200));
        Assert.That(index.Bulks[3].Split('\n', StringSplitOptions.RemoveEmptyEntries), Has.Length.EqualTo(100));
    }

    [Test]
    public async Task An_empty_source_writes_and_deletes_nothing_keeps_the_index_and_warns_with_counts_only()
    {
        var index = new FakeIndex { Existing = ["a", "b"] };
        var log = new CaptureLog();

        var report = await RunAsync(new LibraryFeed(new FixedClock()), index, [], log);

        Assert.That(report, Is.EqualTo(new ReconcileReport(0, 0, true)));
        Assert.That(index.Bulks, Is.Empty);
        Assert.That(index.Ensured, Has.Count.EqualTo(1), "the index is created even when the source is empty");
        Assert.That(log.Lines.Where(l => l.Level == LogLevel.Warning), Has.Exactly(1).Items);
        Assert.That(log.Lines.Single(l => l.Level == LogLevel.Warning).Line, Does.Contain("tsr-articles").And.Not.Contain("\"a\""));
    }

    [Test]
    public async Task An_unchanged_source_sends_nothing_the_second_time_and_a_changed_one_sends_again()
    {
        var index = new FakeIndex();
        var feed = new LibraryFeed(new FixedClock());

        _ = await RunAsync(feed, index, [Doc("a")]);
        var again = await RunAsync(feed, index, [Doc("a")]);
        var changed = await RunAsync(feed, index, [Doc("a", "New title")]);

        Assert.That(again, Is.EqualTo(new ReconcileReport(0, 0, false)));
        Assert.That(changed!.Upserted, Is.EqualTo(1));
        Assert.That(index.Bulks, Has.Count.EqualTo(2));
    }

    [Test]
    public async Task The_index_is_checked_on_every_run_even_when_the_source_is_unchanged()
    {
        var index = new FakeIndex();
        var feed = new LibraryFeed(new FixedClock());

        _ = await RunAsync(feed, index, [Doc("a")]);
        _ = await RunAsync(feed, index, [Doc("a")]);

        Assert.That(index.Ensured, Has.Count.EqualTo(2));
    }

    [Test]
    public async Task A_lost_index_is_rebuilt_in_full_even_when_the_source_is_unchanged()
    {
        var index = new FakeIndex();
        var feed = new LibraryFeed(new FixedClock());
        _ = await RunAsync(feed, index, [Doc("a"), Doc("b")]);

        index.Created = true;
        var report = await RunAsync(feed, index, [Doc("a"), Doc("b")]);

        Assert.That(report, Is.EqualTo(new ReconcileReport(2, 0, false)));
        Assert.That(index.Bulks, Has.Count.EqualTo(2));
    }

    [Test]
    public async Task An_empty_source_asks_for_a_retry_in_30_seconds_at_most_20_times_in_a_row_and_a_run_with_documents_ends_it()
    {
        var index = new FakeIndex();
        var feed = new LibraryFeed(new FixedClock());
        Assert.That(feed.RetryDelay, Is.Null, "nothing has run");

        for (var i = 1; i <= 20; i++)
        {
            _ = await RunAsync(feed, index, []);
            Assert.That(feed.RetryDelay, Is.EqualTo(TimeSpan.FromSeconds(30)), "empty run " + i);
        }

        _ = await RunAsync(feed, index, []);
        Assert.That(feed.RetryDelay, Is.Null, "the 21st empty run goes back to the normal interval");

        _ = await RunAsync(feed, index, [Doc("a")]);
        Assert.That(feed.RetryDelay, Is.Null);
        _ = await RunAsync(feed, index, []);
        Assert.That(feed.RetryDelay, Is.EqualTo(TimeSpan.FromSeconds(30)), "a run with documents starts the count again");
    }

    [Test]
    public async Task A_source_that_was_empty_at_start_is_written_in_full_when_the_articles_arrive()
    {
        var index = new FakeIndex();
        var feed = new LibraryFeed(new FixedClock());

        _ = await RunAsync(feed, index, []);
        var report = await RunAsync(feed, index, [Doc("a")]);

        Assert.That(report, Is.EqualTo(new ReconcileReport(1, 0, false)));
        Assert.That(index.Bulks, Has.Count.EqualTo(1));
    }

    [Test]
    public async Task A_failed_write_is_logged_without_content_nothing_is_deleted_and_the_next_run_tries_again()
    {
        var index = new FakeIndex { Existing = ["gone"], FailBulk = true };
        var feed = new LibraryFeed(new FixedClock());
        var log = new CaptureLog();

        var report = await RunAsync(feed, index, [Doc("a")], log);
        index.FailBulk = false;
        var retry = await RunAsync(feed, index, [Doc("a")]);

        Assert.That(report, Is.Null);
        Assert.That(log.Lines.Single(l => l.Level == LogLevel.Error).Line, Does.Not.Contain("\"slug\""));
        Assert.That(retry!.Upserted, Is.EqualTo(1), "a failed run is not remembered as done");
    }

    [Test]
    public async Task An_engine_that_is_not_configured_does_nothing()
    {
        var index = new FakeIndex { IsConfigured = false };

        var report = await RunAsync(new LibraryFeed(new FixedClock()), index, [Doc("a")]);

        Assert.That(report, Is.Null);
        Assert.That(index.Ensured, Is.Empty);
    }

    [Test]
    public void The_article_mapping_is_the_websites_and_is_valid_json()
    {
        using var mapping = JsonDocument.Parse(LibraryIndexMappings.Articles);

        var properties = mapping.RootElement.GetProperty("mappings").GetProperty("properties");
        Assert.That(properties.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["slug", "title", "excerpt", "content", "categories", "tags", "author", "language", "publishedDate", "modifiedDate", "status", "indexed_at"]));
        Assert.That(properties.GetProperty("title").GetProperty("analyzer").GetString(), Is.EqualTo("multilingual_analyzer"));
        Assert.That(mapping.RootElement.GetProperty("settings").GetProperty("number_of_shards").GetInt32(), Is.EqualTo(1));
        Assert.That(mapping.RootElement.GetProperty("settings").GetProperty("number_of_replicas").GetInt32(), Is.Zero);
    }
}
