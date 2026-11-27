using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Logging;
using Tsr.Shared.Api;

namespace Tsr.Search.Api.Domain;

/// <summary>One document of a Library index: its id and its JSON text (an object, without <c>indexed_at</c>, which the feed adds). The text is sent as it is, never parsed and printed again.</summary>
internal sealed record LibraryDocument(string Id, string Json);

/// <summary>
/// One full reconcile of one Library index (tsr-web <c>reindex-service.ts</c>): ensure the index, write every document in batches of <see cref="BatchSize"/> in the order given (Elasticsearch breaks equal scores by its own document order,
/// so the order is part of the answer), then delete the ids that are in the index and not in the source. An empty source refuses to run (SRCH-R17): nothing is written or deleted, the index is kept, and one warning with counts only is logged.
/// A source whose documents are unchanged since the last run that finished is not sent again (a 22 MB lecture file must not go every 10 minutes). The log holds counts and the index name, never a document.
/// One instance lives as long as the worker, because it remembers that last run.
/// </summary>
internal sealed partial class LibraryFeed(TimeProvider clock)
{
    public const int BatchSize = 100;

    public const int MaxShortRetries = 20;

    public static readonly TimeSpan ShortRetry = TimeSpan.FromSeconds(30);

    private readonly Dictionary<string, string> lastDone = [];

    private int emptyRuns;

    /// <summary>How long to wait before another run: after a run whose source was empty (the articles may not be copied yet), <see cref="ShortRetry"/>, for at most <see cref="MaxShortRetries"/> runs in a row; otherwise null, the normal interval.</summary>
    public TimeSpan? RetryDelay => emptyRuns is > 0 and <= MaxShortRetries ? ShortRetry : null;

    /// <summary>The report of the run; null when the engine is not configured or failed (the next run starts over).</summary>
    public async Task<ReconcileReport?> ReconcileAsync(ILibraryIndex index, string indexName, string mappingJson, IReadOnlyList<LibraryDocument> documents, ILogger log, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(index);
        ArgumentNullException.ThrowIfNull(documents);
        ArgumentNullException.ThrowIfNull(log);
        if (!index.IsConfigured)
        {
            return null;
        }

        var hash = Fingerprint(documents);
        var started = System.Diagnostics.Stopwatch.GetTimestamp();
        var upserted = 0;
        try
        {
            var created = await index.EnsureIndexAsync(indexName, mappingJson, ct);
            // An index that was just created (never there, or lost) is written in full, whatever the last run saw.
            if (!created && lastDone.TryGetValue(indexName, out var done) && done == hash)
            {
                emptyRuns = 0;
                return new ReconcileReport(0, 0, false);
            }

            if (documents.Count == 0)
            {
                emptyRuns++;
                LogEmpty(log, indexName);
                return new ReconcileReport(0, 0, true);
            }

            var before = await index.ListIdsAsync(indexName, ct);
            var indexedAt = WebsiteV1.Iso(clock.GetUtcNow());
            foreach (var batch in documents.Chunk(BatchSize))
            {
                await index.BulkAsync(UpsertLines(indexName, batch, indexedAt), ct);
                upserted += batch.Length;
            }

            var current = documents.Select(d => d.Id).ToHashSet(StringComparer.Ordinal);
            var stale = before.Where(id => !current.Contains(id)).Distinct(StringComparer.Ordinal).ToList();
            foreach (var batch in stale.Chunk(BatchSize))
            {
                await index.BulkAsync(DeleteLines(indexName, batch), ct);
            }

            emptyRuns = 0;
            lastDone[indexName] = hash;
            var seconds = System.Diagnostics.Stopwatch.GetElapsedTime(started).TotalSeconds;
            LogDone(log, indexName, upserted, stale.Count, seconds);
            return new ReconcileReport(upserted, stale.Count, false);
        }
        catch (SearchUnavailableException unavailable)
        {
            emptyRuns = 0;
            // The message is a status code, an exception type or a fixed phrase, never data (ElasticSearchIndex.Writer.cs).
            LogFailed(log, indexName, unavailable.Message, upserted);
            return null;
        }
    }

    /// <summary>One tick of the article feed: take the lock, read the published articles, reconcile the index. Null when the engine is not configured, another instance holds the lock, or the engine failed.</summary>
    public async Task<ReconcileReport?> TickAsync(ILibraryIndex index, ArticleFeedSource source, ILogger log, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(index);
        ArgumentNullException.ThrowIfNull(source);
        ArgumentNullException.ThrowIfNull(log);
        if (!index.IsConfigured)
        {
            LogNotConfigured(log);
            return null;
        }

        await using var run = await source.TryOpenAsync(ct);
        if (run is null)
        {
            LogLocked(log);
            return null;
        }

        var articles = await run.ArticlesAsync(ct);
        return await ReconcileAsync(index, ArticleSearchQuery.IndexName, LibraryIndexMappings.Articles, articles, log, ct);
    }

    private static string Fingerprint(IReadOnlyList<LibraryDocument> documents)
    {
        using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        foreach (var document in documents)
        {
            hash.AppendData(Encoding.UTF8.GetBytes(document.Id));
            hash.AppendData("\n"u8);
            hash.AppendData(Encoding.UTF8.GetBytes(document.Json));
            hash.AppendData("\n"u8);
        }

        return Convert.ToHexString(hash.GetHashAndReset());
    }

    private static string UpsertLines(string indexName, LibraryDocument[] batch, string indexedAt)
    {
        var lines = new StringBuilder();
        foreach (var document in batch)
        {
            lines.Append(Action("index", indexName, document.Id)).Append('\n')
                .Append(document.Json, 0, document.Json.Length - 1).Append(",\"indexed_at\":\"").Append(indexedAt).Append("\"}\n");
        }

        return lines.ToString();
    }

    private static string DeleteLines(string indexName, string[] ids)
    {
        var lines = new StringBuilder();
        foreach (var id in ids)
        {
            lines.Append(Action("delete", indexName, id)).Append('\n');
        }

        return lines.ToString();
    }

    private static string Action(string verb, string indexName, string id) =>
        new System.Text.Json.Nodes.JsonObject { [verb] = new System.Text.Json.Nodes.JsonObject { ["_index"] = indexName, ["_id"] = id } }.ToJsonString();

    [LoggerMessage(Level = LogLevel.Information, Message = "Library feed: Elasticsearch is not configured, nothing to do")]
    private static partial void LogNotConfigured(ILogger logger);

    [LoggerMessage(Level = LogLevel.Information, Message = "Library feed: another instance is running, skipping this tick")]
    private static partial void LogLocked(ILogger logger);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Library feed: the source of {Index} yielded no documents; nothing was written or deleted, the index was kept")]
    private static partial void LogEmpty(ILogger logger, string index);

    [LoggerMessage(Level = LogLevel.Information, Message = "Library feed: {Index} upserted {Upserted}, deleted {Deleted} ({Seconds:F1} s)")]
    private static partial void LogDone(ILogger logger, string index, int upserted, int deleted, double seconds);

    [LoggerMessage(Level = LogLevel.Error, Message = "Library feed: {Index}: {Reason} after {Upserted} upserted; nothing was deleted, the next run starts over")]
    private static partial void LogFailed(ILogger logger, string index, string reason, int upserted);
}
