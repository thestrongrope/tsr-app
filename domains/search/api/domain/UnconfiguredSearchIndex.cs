namespace Tsr.Search.Api.Domain;

/// <summary>The index when <c>TSR_ELASTICSEARCH_URL</c> is not a valid http(s) address: every search is "unavailable" (PHP: "Elasticsearch is not configured"), and the feed does nothing.</summary>
internal sealed class UnconfiguredSearchIndex : ISearchIndex, ISearchIndexWriter
{
    public bool IsConfigured => false;

    public Task<IReadOnlyList<SearchHit>> SearchAsync(string kind, string text, SearchScope scope, int size, CancellationToken ct) =>
        throw new SearchUnavailableException("Elasticsearch is not configured");

    public Task EnsureIndexAsync(CancellationToken ct) => throw new SearchUnavailableException("Elasticsearch is not configured");

    public Task BulkUpsertAsync(IReadOnlyList<SearchDocument> documents, CancellationToken ct) => throw new SearchUnavailableException("Elasticsearch is not configured");

    public Task<IReadOnlyList<string>> ListIdsAsync(CancellationToken ct) => throw new SearchUnavailableException("Elasticsearch is not configured");

    public Task BulkDeleteAsync(IReadOnlyList<string> ids, CancellationToken ct) => throw new SearchUnavailableException("Elasticsearch is not configured");
}
