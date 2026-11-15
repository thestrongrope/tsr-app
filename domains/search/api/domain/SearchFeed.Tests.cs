using Microsoft.Extensions.Logging;
using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>The reconcile algorithm (PHP SearchIndexModel::reconcile) against a fake index and a fake source.</summary>
[TestFixture]
internal sealed class SearchFeedTests
{
    private sealed class FakeIndex : ISearchIndexWriter
    {
        public bool IsConfigured { get; set; } = true;

        public List<string> Present { get; } = [];

        public List<int> UpsertSizes { get; } = [];

        public List<string> Upserted { get; } = [];

        public List<string> Deleted { get; } = [];

        public int Ensured { get; private set; }

        public int FailOnUpsertCall { get; set; }

        public Task EnsureIndexAsync(CancellationToken ct)
        {
            Ensured++;
            return Task.CompletedTask;
        }

        public Task BulkUpsertAsync(IReadOnlyList<SearchDocument> documents, CancellationToken ct)
        {
            UpsertSizes.Add(documents.Count);
            if (UpsertSizes.Count == FailOnUpsertCall)
            {
                throw new SearchUnavailableException("rejected");
            }

            Upserted.AddRange(documents.Select(d => d.DocId));
            return Task.CompletedTask;
        }

        public Task<IReadOnlyList<string>> ListIdsAsync(CancellationToken ct) => Task.FromResult<IReadOnlyList<string>>(Present.ToList());

        public Task BulkDeleteAsync(IReadOnlyList<string> ids, CancellationToken ct)
        {
            Deleted.AddRange(ids);
            return Task.CompletedTask;
        }
    }

    private sealed class FakeSource(IReadOnlyList<SearchDocument> documents, bool locked = false) : ISearchDocumentSource
    {
        public IReadOnlyList<SearchDocument> Documents => documents;

        public bool Disposed { get; private set; }

        public Task<ISearchSourceRun?> TryOpenAsync(CancellationToken ct) =>
            Task.FromResult<ISearchSourceRun?>(locked ? null : new Run(this));

        private sealed class Run(FakeSource owner) : ISearchSourceRun
        {
            public async IAsyncEnumerable<SearchDocument> DocumentsAsync([System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken ct)
            {
                foreach (var document in owner.Documents)
                {
                    yield return document;
                }

                await Task.CompletedTask;
            }

            public ValueTask DisposeAsync()
            {
                owner.Disposed = true;
                return ValueTask.CompletedTask;
            }
        }
    }

    private sealed class CapturingLog : ILogger
    {
        public List<string> Lines { get; } = [];

        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            Lines.Add(formatter(state, exception));
    }

    private static readonly int[] ExpectedBatches = [500, 500, 200];

    private static readonly string[] ExpectedDeletes = ["subscriber:9", "student:2", "class:9"];

    private static readonly string[] OnlyTheSubscriber = ["subscriber:9"];

    private static List<SearchDocument> Subscribers(int count) =>
        Enumerable.Range(1, count).Select(i => SearchDocument.ForSubscriber(i, "Secret Name " + i, 1)).ToList();

    [Test]
    public async Task Documents_are_upserted_in_batches_of_500()
    {
        var index = new FakeIndex();

        var report = await SearchFeed.TickAsync(index, new FakeSource(Subscribers(1200)), new CapturingLog(), CancellationToken.None);

        Assert.That(index.UpsertSizes, Is.EqualTo(ExpectedBatches));
        Assert.That(report, Is.EqualTo(new ReconcileReport(1200, 0, false)));
        Assert.That(index.Ensured, Is.EqualTo(1));
    }

    [Test]
    public async Task Exactly_the_ids_present_and_not_seen_are_deleted()
    {
        var index = new FakeIndex { Present = { "subscriber:1", "subscriber:9", "student:2", "class:9" } };
        List<SearchDocument> wanted = [.. Subscribers(2), SearchDocument.ForStudent(5, "Secret Student", 1, [], []), SearchDocument.ForClass(1, "C1", 1, 2, "Level")];

        var report = await SearchFeed.TickAsync(index, new FakeSource(wanted), new CapturingLog(), CancellationToken.None);

        Assert.That(index.Deleted, Is.EquivalentTo(ExpectedDeletes));
        Assert.That(report!.Deleted, Is.EqualTo(3));
    }

    [Test]
    public async Task A_kind_whose_read_came_back_empty_keeps_its_documents_while_the_other_kinds_are_reconciled()
    {
        var index = new FakeIndex { Present = { "subscriber:1", "subscriber:9", "student:2", "student:3", "teacher:4", "odd-id" } };
        var log = new CapturingLog();

        var report = await SearchFeed.TickAsync(index, new FakeSource(Subscribers(2)), log, CancellationToken.None);

        Assert.That(index.Deleted, Is.EqualTo(OnlyTheSubscriber), "no student or teacher was read, so none of theirs is deleted");
        Assert.That(report, Is.EqualTo(new ReconcileReport(2, 1, false)));
        Assert.That(string.Join("\n", log.Lines), Does.Contain("kept 4").And.Not.Contain("student:").And.Not.Contain("odd-id"));
    }

    [Test]
    public async Task An_empty_source_deletes_nothing_and_says_it_refused()
    {
        var index = new FakeIndex { Present = { "subscriber:1" } };

        var report = await SearchFeed.TickAsync(index, new FakeSource([]), new CapturingLog(), CancellationToken.None);

        Assert.That(index.Deleted, Is.Empty);
        Assert.That(report!.Refused, Is.True);
    }

    [Test]
    public async Task A_failed_batch_ends_the_tick_and_deletes_nothing()
    {
        var index = new FakeIndex { Present = { "class:9" }, FailOnUpsertCall = 2 };
        var source = new FakeSource(Subscribers(1200));

        var report = await SearchFeed.TickAsync(index, source, new CapturingLog(), CancellationToken.None);

        Assert.That(report, Is.Null);
        Assert.That(index.Deleted, Is.Empty);
        Assert.That(source.Disposed, Is.True, "the lock is released");
    }

    [Test]
    public async Task Nothing_happens_when_the_index_is_not_configured()
    {
        var index = new FakeIndex { IsConfigured = false };
        var log = new CapturingLog();

        var report = await SearchFeed.TickAsync(index, new FakeSource(Subscribers(3)), log, CancellationToken.None);

        Assert.That(report, Is.Null);
        Assert.That(index.Ensured, Is.Zero);
        Assert.That(log.Lines, Has.Count.EqualTo(1));
    }

    [Test]
    public async Task A_held_lock_skips_the_tick()
    {
        var index = new FakeIndex();

        var report = await SearchFeed.TickAsync(index, new FakeSource(Subscribers(3), locked: true), new CapturingLog(), CancellationToken.None);

        Assert.That(report, Is.Null);
        Assert.That(index.Ensured, Is.Zero);
    }

    [Test]
    public async Task The_log_holds_counts_only()
    {
        var index = new FakeIndex { Present = { "student:77" } };
        var log = new CapturingLog();

        await SearchFeed.TickAsync(index, new FakeSource(Subscribers(2)), log, CancellationToken.None);

        var text = string.Join("\n", log.Lines);
        Assert.That(text, Does.Not.Contain("Secret").And.Not.Contain("student:77"));
        Assert.That(text, Does.Contain("2").And.Contain("1"));
    }
}
