namespace Tsr.Search.Api.Domain;

/// <summary>
/// The external boundary of the Library searches: Elasticsearch, as raw JSON in and out (the bodies are written by <see cref="ArticleSearchQuery"/> and read with <c>JsonDocument</c>, so no typed client object is involved).
/// Every method throws <see cref="SearchUnavailableException"/> when the engine is not configured, cannot be reached, or refuses the request. Fake in unit tests.
/// </summary>
internal interface ILibraryIndex
{
    /// <summary>False when no valid <c>TSR_ELASTICSEARCH_URL</c> is set: nothing will answer, and the feed has nothing to do.</summary>
    bool IsConfigured { get; }

    /// <summary>The text of the engine's answer to a search body, within the client's search timeout.</summary>
    Task<string> SearchAsync(string index, string body, CancellationToken ct);

    /// <summary>Creates the index with the settings and mappings of <paramref name="mappingJson"/> when it does not exist; true when it was created now (it was missing, or lost), false when it was already there.</summary>
    Task<bool> EnsureIndexAsync(string index, string mappingJson, CancellationToken ct);

    /// <summary>The ids of every document of the index (a bounded scroll).</summary>
    Task<IReadOnlyList<string>> ListIdsAsync(string index, CancellationToken ct);

    /// <summary>One bulk request of newline-delimited JSON; any rejected item fails the call.</summary>
    Task BulkAsync(string ndjson, CancellationToken ct);
}
