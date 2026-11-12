using System.Diagnostics;
using Microsoft.Extensions.Logging;

namespace Tsr.Search.Api.Domain;

/// <summary>What one reconcile did, in counts. <see cref="Refused"/>: the source yielded no documents, so nothing was deleted.</summary>
internal sealed record ReconcileReport(int Upserted, int Deleted, bool Refused);

/// <summary>
/// The full reconcile (PHP SearchIndexModel::reconcile, run nightly by cli/reindex_search.php; here every 10 minutes): write every document the database says should exist, then delete the ids that were in the index and
/// are not wanted now. The delete phase is reached only when the whole source was written without a failure and yielded at least one document, so a failed or empty read never shrinks the index.
/// The log holds counts only, never a name, token or id.
/// </summary>
internal static partial class SearchFeed
{
    public const int BatchSize = 500;

    /// <summary>One tick. Null when it did nothing (not configured, another instance holds the lock) or Elasticsearch failed (the next tick starts over).</summary>
    public static async Task<ReconcileReport?> TickAsync(ISearchIndexWriter index, ISearchDocumentSource source, ILogger log, CancellationToken ct)
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

        var started = Stopwatch.GetTimestamp();
        var upserted = 0;
        try
        {
            await index.EnsureIndexAsync(ct);
            var before = await index.ListIdsAsync(ct);
            var seen = new HashSet<string>(StringComparer.Ordinal);
            var batch = new List<SearchDocument>(BatchSize);
            await foreach (var document in run.DocumentsAsync(ct))
            {
                if (!seen.Add(document.DocId))
                {
                    continue;
                }

                batch.Add(document);
                if (batch.Count == BatchSize)
                {
                    await index.BulkUpsertAsync(batch, ct);
                    upserted += batch.Count;
                    batch.Clear();
                }
            }

            if (batch.Count > 0)
            {
                await index.BulkUpsertAsync(batch, ct);
                upserted += batch.Count;
            }

            if (seen.Count == 0)
            {
                var refusedAfter = Stopwatch.GetElapsedTime(started).TotalSeconds;
                LogRefused(log, refusedAfter);
                return new ReconcileReport(0, 0, true);
            }

            var deleted = await DeleteUnseenAsync(index, before, seen, ct);
            var seconds = Stopwatch.GetElapsedTime(started).TotalSeconds;
            LogDone(log, upserted, deleted, seconds);
            return new ReconcileReport(upserted, deleted, false);
        }
        catch (SearchUnavailableException)
        {
            var failedAfter = Stopwatch.GetElapsedTime(started).TotalSeconds;
            LogFailed(log, upserted, failedAfter);
            return null;
        }
    }

    private static async Task<int> DeleteUnseenAsync(ISearchIndexWriter index, IReadOnlyList<string> before, HashSet<string> seen, CancellationToken ct)
    {
        var stale = before.Where(id => !seen.Contains(id)).Distinct(StringComparer.Ordinal).ToList();
        foreach (var chunk in stale.Chunk(BatchSize))
        {
            await index.BulkDeleteAsync(chunk, ct);
        }

        return stale.Count;
    }

    [LoggerMessage(Level = LogLevel.Information, Message = "Search feed: Elasticsearch is not configured, nothing to do")]
    private static partial void LogNotConfigured(ILogger logger);

    [LoggerMessage(Level = LogLevel.Information, Message = "Search feed: another instance is running, skipping this tick")]
    private static partial void LogLocked(ILogger logger);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Search feed: the database yielded no documents, nothing was deleted ({Seconds:F1} s)")]
    private static partial void LogRefused(ILogger logger, double seconds);

    [LoggerMessage(Level = LogLevel.Information, Message = "Search feed: upserted {Upserted}, deleted {Deleted} ({Seconds:F1} s)")]
    private static partial void LogDone(ILogger logger, int upserted, int deleted, double seconds);

    [LoggerMessage(Level = LogLevel.Error, Message = "Search feed: Elasticsearch failed after {Upserted} upserted; nothing was deleted, the next tick starts over ({Seconds:F1} s)")]
    private static partial void LogFailed(ILogger logger, int upserted, double seconds);
}
