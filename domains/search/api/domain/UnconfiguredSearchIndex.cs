namespace Tsr.Search.Api.Domain;

/// <summary>The index when <c>TSR_ELASTICSEARCH_URL</c> is not a valid http(s) address: every search is "unavailable" (PHP: "Elasticsearch is not configured").</summary>
internal sealed class UnconfiguredSearchIndex : ISearchIndex
{
    public Task<IReadOnlyList<SearchHit>> SearchAsync(string kind, string text, SearchScope scope, int size, CancellationToken ct) =>
        throw new SearchUnavailableException("Elasticsearch is not configured");
}
