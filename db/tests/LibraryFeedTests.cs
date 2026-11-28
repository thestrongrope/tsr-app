using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;
using NUnit.Framework;
using Tsr.Content.Api.Domain;
using Tsr.Search.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// TC-SRCH-R17-01: one tick of the article feed over the synthetic articles of db/synthetic/content, read through <c>content.v_published_articles</c> as the limited role, with a fake index that holds one extra document.
/// The real index is proven by <c>v1-search.hurl</c> on a stack that has Elasticsearch (the worker's log line).
/// </summary>
public sealed class LibraryFeedTests
{
    private sealed class FakeIndex : ILibraryIndex
    {
        public bool IsConfigured => true;

        public List<string> Bulks { get; } = [];

        public List<string> Ensured { get; } = [];

        public Task<string> SearchAsync(string index, string body, CancellationToken ct) => throw new NotSupportedException();

        public bool Created { get; set; }

        public Task<bool> EnsureIndexAsync(string index, string mappingJson, CancellationToken ct)
        {
            Ensured.Add(index);
            return Task.FromResult(Created);
        }

        public Task<IReadOnlyList<string>> ListIdsAsync(string index, CancellationToken ct) =>
            Task.FromResult<IReadOnlyList<string>>(["the-zorvath-timetable", "ghost-article"]);

        public Task BulkAsync(string ndjson, CancellationToken ct)
        {
            Bulks.Add(ndjson);
            return Task.CompletedTask;
        }
    }

    private static readonly LectureSettings NoLectures = LectureSettings.From(null, null, null);

    [OneTimeSetUp]
    public async Task LoadAsync()
    {
        await TestDatabase.ExecuteAsync("truncate content.published_articles, content.categories, content.publications, content.refresh_state");
        using var factory = TestApi.Create();
        await using var scope = factory.Services.CreateAsyncScope();
        var directory = Path.Combine(TestDatabase.RepoRoot(), "db", "synthetic", "content");
        var outcome = await ContentRefresh.TickAsync(scope.ServiceProvider.GetRequiredService<NpgsqlDataSource>(), directory, TimeProvider.System, NullLogger.Instance, CancellationToken.None);
        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Refreshed));
    }

    [Test]
    public async Task A_tick_indexes_the_published_articles_newest_first_with_no_body_and_deletes_the_extra_document()
    {
        var index = new FakeIndex();
        var feed = new LibraryFeed(TimeProvider.System);

        var report = await feed.TickAsync(index, new ArticleFeedSource(new DbSettings(TestDatabase.AppConnection)), NoLectures, NullLogger.Instance, CancellationToken.None);

        Assert.That(report, Is.EqualTo(new ReconcileReport(12, 1, false)));
        var lines = index.Bulks[0].Split('\n', StringSplitOptions.RemoveEmptyEntries);
        var ids = lines.Where((_, i) => i % 2 == 0).Select(line => JsonElement.Parse(line).GetProperty("index").GetProperty("_id").GetString()).ToArray();
        Assert.That(ids, Has.Length.EqualTo(12));
        Assert.That(ids[0], Is.EqualTo("term-planner-for-next-year"));
        Assert.That(ids[^1], Is.EqualTo("glossary-habits-for-new-terms"));
        Assert.That(ids, Does.Not.Contain("unfinished-outline-on-margin-notes"), "a draft is never indexed");
        var first = JsonElement.Parse(lines[1]);
        Assert.That(first.EnumerateObject().Select(p => p.Name).Take(2), Is.EqualTo((string[])["slug", "title"]));
        Assert.That(first.GetProperty("content").GetString(), Is.Empty);
        Assert.That(first.GetProperty("status").GetString(), Is.EqualTo("publish"));
        Assert.That(first.GetProperty("indexed_at").GetString(), Does.Match(@"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"));
        Assert.That(index.Bulks[1], Is.EqualTo("""{"delete":{"_index":"tsr-articles","_id":"ghost-article"}}""" + "\n"));
    }

    [Test]
    public async Task A_lost_index_is_rebuilt_in_full_by_the_next_tick_though_the_articles_did_not_change()
    {
        var index = new FakeIndex();
        var feed = new LibraryFeed(TimeProvider.System);
        var source = new ArticleFeedSource(new DbSettings(TestDatabase.AppConnection));
        _ = await feed.TickAsync(index, source, NoLectures, NullLogger.Instance, CancellationToken.None);
        var unchanged = await feed.TickAsync(index, source, NoLectures, NullLogger.Instance, CancellationToken.None);

        index.Created = true;
        var rebuilt = await feed.TickAsync(index, source, NoLectures, NullLogger.Instance, CancellationToken.None);

        Assert.That(unchanged!.Upserted, Is.Zero);
        Assert.That(rebuilt!.Upserted, Is.EqualTo(12));
    }

    [Test]
    public async Task A_tick_also_indexes_the_lecture_file_line_for_line_with_the_vectors_exactly_as_the_file_has_them()
    {
        var fixture = Path.Combine(TestDatabase.RepoRoot(), "db", "synthetic", "lectures", "lectures.ndjson");
        var index = new FakeIndex();

        var report = await new LibraryFeed(TimeProvider.System).TickAsync(index, new ArticleFeedSource(new DbSettings(TestDatabase.AppConnection)), LectureSettings.From(null, null, fixture), NullLogger.Instance, CancellationToken.None);

        Assert.That(report, Is.EqualTo(new ReconcileReport(12, 1, false)), "the report is the articles'");
        var lectureBulk = index.Bulks.Single(b => b.Contains("\"_index\":\"tsr-lectures\"", StringComparison.Ordinal) && b.Contains("\"index\"", StringComparison.Ordinal)).Split('\n', StringSplitOptions.RemoveEmptyEntries);
        var lines = File.ReadAllLines(fixture).Where(line => line.Length > 0).ToArray();
        Assert.That(lectureBulk, Has.Length.EqualTo(24));
        for (var i = 0; i < lines.Length; i++)
        {
            Assert.That(lectureBulk[(2 * i) + 1], Does.StartWith(lines[i][..^1] + ",\"indexed_at\":\""), "line " + (i + 1));
        }
    }

    [TestCase(null)]
    [TestCase("/no/such/folder/lectures.ndjson")]
    public async Task The_lecture_index_is_created_empty_and_nothing_is_written_to_it_when_the_file_is_unset_or_missing(string? file)
    {
        var index = new FakeIndex();

        var report = await new LibraryFeed(TimeProvider.System).TickAsync(index, new ArticleFeedSource(new DbSettings(TestDatabase.AppConnection)), LectureSettings.From(null, null, file), NullLogger.Instance, CancellationToken.None);

        Assert.That(report, Is.EqualTo(new ReconcileReport(12, 1, false)), "the articles are indexed as ever");
        Assert.That(index.Ensured, Is.EqualTo((string[])["tsr-articles", "tsr-lectures"]));
        Assert.That(index.Bulks.Where(b => b.Contains("tsr-lectures", StringComparison.Ordinal)), Is.Empty, "no lecture is written and none is deleted");
    }

    [Test]
    public async Task A_tick_is_skipped_while_another_instance_holds_the_lock()
    {
        await using var other = new NpgsqlConnection(TestDatabase.AppConnection);
        await other.OpenAsync();
        await using (var take = new NpgsqlCommand("select pg_advisory_lock(@key)", other))
        {
            take.Parameters.AddWithValue("key", ArticleFeedSource.LockKey);
            _ = await take.ExecuteScalarAsync();
        }

        ILibraryIndex index = new FakeIndex();
        ReconcileReport? report;
        try
        {
            report = await new LibraryFeed(TimeProvider.System).TickAsync(index, new ArticleFeedSource(new DbSettings(TestDatabase.AppConnection)), NoLectures, NullLogger.Instance, CancellationToken.None);
        }
        finally
        {
            await using var release = new NpgsqlCommand("select pg_advisory_unlock(@key)", other);
            release.Parameters.AddWithValue("key", ArticleFeedSource.LockKey);
            _ = await release.ExecuteScalarAsync();
        }

        Assert.That(report, Is.Null);
        Assert.That(((FakeIndex)index).Bulks, Is.Empty);
    }
}
