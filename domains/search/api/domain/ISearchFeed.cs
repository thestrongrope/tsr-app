namespace Tsr.Search.Api.Domain;

/// <summary>
/// The write side of the index boundary (PHP models/searchindex.php): what a reconcile needs. Separate from <see cref="ISearchIndex"/> (the query side) so the many fakes of the query side stay small.
/// Every call has a timeout; a failure is <see cref="SearchUnavailableException"/>.
/// </summary>
internal interface ISearchIndexWriter
{
    /// <summary>False when no valid <c>TSR_ELASTICSEARCH_URL</c> is set: the feed does nothing.</summary>
    bool IsConfigured { get; }

    /// <summary>Creates the index with PHP's settings and mapping when it does not exist yet.</summary>
    Task EnsureIndexAsync(CancellationToken ct);

    /// <summary>Adds or replaces these documents in one bulk request. Any document Elasticsearch refuses fails the whole call.</summary>
    Task BulkUpsertAsync(IReadOnlyList<SearchDocument> documents, CancellationToken ct);

    /// <summary>The index id of every document present (followed page by page with the scroll API).</summary>
    Task<IReadOnlyList<string>> ListIdsAsync(CancellationToken ct);

    /// <summary>Removes these documents in one bulk request; one already gone is done.</summary>
    Task BulkDeleteAsync(IReadOnlyList<string> ids, CancellationToken ct);
}

/// <summary>One run over the database for the feed, holding the "one run at a time" lock until it is disposed.</summary>
internal interface ISearchSourceRun : IAsyncDisposable
{
    /// <summary>Every document the index should hold, once each, read page by page (1000 rows a page).</summary>
    IAsyncEnumerable<SearchDocument> DocumentsAsync(CancellationToken ct);
}

/// <summary>What the index should hold, read through other domains' published views only (PHP models/searchsource.php <c>allDocs</c>).</summary>
internal interface ISearchDocumentSource
{
    /// <summary>Starts a run, or null when another instance holds the lock.</summary>
    Task<ISearchSourceRun?> TryOpenAsync(CancellationToken ct);
}
