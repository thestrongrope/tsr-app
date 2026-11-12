using Elastic.Clients.Elasticsearch;
using Elastic.Clients.Elasticsearch.Core.Search;
using Elastic.Clients.Elasticsearch.QueryDsl;
using Elastic.Transport;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The real index: Elasticsearch through the official client, typed query objects only (the caller's text is the value of a
/// <c>match</c> clause, never query syntax). PHP: models/searchindex.php searchRaw (index <c>tsr-search</c>, the user "elastic",
/// 5 second timeout, 2 second connect). The query is <c>bool</c>: must <c>match name {query, operator and}</c>; filter <c>terms kind</c>
/// and, when the scope is limited, a <c>bool should [terms ...] minimum_should_match 1</c>.
/// </summary>
internal sealed class ElasticSearchIndex : ISearchIndex
{
    public const string IndexName = "tsr-search";

    private readonly ElasticsearchClient _client;

    public ElasticSearchIndex(SearchSettings settings)
    {
        ArgumentNullException.ThrowIfNull(settings);
        var connection = new ElasticsearchClientSettings(settings.Url ?? throw new ArgumentException("The index address is required.", nameof(settings)))
            .RequestTimeout(TimeSpan.FromSeconds(5))
            .Authentication(new BasicAuthentication(SearchSettings.User, settings.Password));
        _client = new ElasticsearchClient(connection);
    }

    public async Task<IReadOnlyList<SearchHit>> SearchAsync(string kind, string text, SearchScope scope, int size, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(scope);
        var filters = new List<Query> { new TermsQuery { Field = "kind", Terms = new TermsQueryField([FieldValue.String(kind)]) } };
        if (scope.AnyOf is { } anyOf)
        {
            filters.Add(new BoolQuery
            {
                Should = anyOf.Select(ToQuery).ToList(),
                MinimumShouldMatch = 1,
            });
        }

        var request = new SearchRequest(IndexName)
        {
            Size = size,
            Source = new SourceConfig(new SourceFilter { Includes = Fields.FromStrings(["id", "name"]) }),
            Query = new BoolQuery
            {
                Must = [new MatchQuery { Field = "name", Query = text, Operator = Operator.And }],
                Filter = filters,
            },
        };

        SearchResponse<IndexedDocument> response;
        try
        {
            response = await _client.SearchAsync<IndexedDocument>(request, ct);
        }
        catch (Exception exception) when (exception is TransportException or HttpRequestException or TaskCanceledException && !ct.IsCancellationRequested)
        {
            throw new SearchUnavailableException("Elasticsearch could not be reached: " + exception.GetType().Name);
        }

        // Any answer that is not a success is "down", a 404 (the index is missing) included: PHP raises on every status of 300 or more, and an empty list would read as "nothing found".
        if (!response.IsValidResponse || !response.ApiCallDetails.HasSuccessfulStatusCode)
        {
            throw new SearchUnavailableException("Elasticsearch answered " + response.ApiCallDetails.HttpStatusCode);
        }

        return response.Documents.Select(d => new SearchHit(d.Id, d.Name ?? string.Empty)).ToList();
    }

    private static Query ToQuery(TermsClause clause) =>
        new TermsQuery { Field = clause.Field, Terms = new TermsQueryField(clause.Values.Select(v => FieldValue.Long(v)).ToList()) };

    /// <summary>The two fields of a document this query reads back (the document shape is in docs/specs/initial-build/lane-search-notes.md).</summary>
    internal sealed class IndexedDocument
    {
        public long Id { get; set; }

        public string? Name { get; set; }
    }
}
