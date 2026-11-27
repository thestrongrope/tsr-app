using Elastic.Clients.Elasticsearch;
using Elastic.Transport;
using HttpMethod = Elastic.Transport.HttpMethod;

namespace Tsr.Search.Api.Domain;

/// <summary>The write side (PHP models/searchindex.php: ensureIndex, bulkUpsert, allIds, delete). Raw JSON through the client's transport, because the mapping and the bulk bodies are PHP's, byte for shape.</summary>
internal sealed partial class ElasticSearchIndex : ISearchIndexWriter, ILibraryIndex
{
    /// <summary>The most scroll pages one listing reads (1000 ids each): a stop for a loop that would not end.</summary>
    private const int MaxScrollPages = 2000;

    // A bulk of 500 documents may take longer than a search (5 seconds, set on the client): 30 seconds a write call.
    private static readonly TimeSpan WriteTimeout = TimeSpan.FromSeconds(30);

    public bool IsConfigured => true;

    // Every request asks for plain JSON (Accept), so a body must be sent as plain JSON too: the client's own default type carries a version
    // ("compatible-with"), and Elasticsearch refuses a request whose two headers disagree (400 media_type_header_exception).
    private const string JsonType = "application/json";

    public Task EnsureIndexAsync(CancellationToken ct) => EnsureIndexAsync(IndexName, SearchIndexMapping.Json, ct);

    public async Task<bool> EnsureIndexAsync(string index, string mappingJson, CancellationToken ct)
    {
        var head = await SendAsync(HttpMethod.HEAD, "/" + index, PostData.Empty, null, ct);
        if (head.ApiCallDetails.HttpStatusCode != 404)
        {
            Require(head);
            return false;
        }

        Require(await SendAsync(HttpMethod.PUT, "/" + index, PostData.String(mappingJson), JsonType, ct));
        return true;
    }

    public async Task BulkUpsertAsync(IReadOnlyList<SearchDocument> documents, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(documents);
        var lines = new System.Text.StringBuilder();
        foreach (var document in documents)
        {
            lines.Append(Action("index", document.DocId)).Append('\n').Append(document.ToJson().ToJsonString()).Append('\n');
        }

        await BulkAsync(lines.ToString(), ct);
    }

    public async Task BulkDeleteAsync(IReadOnlyList<string> ids, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(ids);
        var lines = new System.Text.StringBuilder();
        foreach (var id in ids)
        {
            lines.Append(Action("delete", id)).Append('\n');
        }

        await BulkAsync(lines.ToString(), ct);
    }

    public Task<IReadOnlyList<string>> ListIdsAsync(CancellationToken ct) => ListIdsAsync(IndexName, ct);

    public async Task<IReadOnlyList<string>> ListIdsAsync(string index, CancellationToken ct)
    {
        var ids = new List<string>();
        var first = """{"size":1000,"_source":false,"query":{"match_all":{}}}""";
        var page = await ReadPageAsync(HttpMethod.POST, "/" + index + "/_search?scroll=1m", first, ct);
        var scrollId = page.ScrollId;
        for (var pages = 0; page.Ids.Count > 0; pages++)
        {
            if (pages >= MaxScrollPages)
            {
                throw new SearchUnavailableException("Elasticsearch listing did not end");
            }

            ids.AddRange(page.Ids);
            var next = new System.Text.Json.Nodes.JsonObject { ["scroll"] = "1m", ["scroll_id"] = page.ScrollId }.ToJsonString();
            page = await ReadPageAsync(HttpMethod.POST, "/_search/scroll", next, ct);
            scrollId = page.ScrollId;
        }

        await ClearScrollAsync(scrollId, ct);
        return ids;
    }

    private async Task<(IReadOnlyList<string> Ids, string ScrollId)> ReadPageAsync(HttpMethod method, string path, string body, CancellationToken ct)
    {
        var response = await SendAsync(method, path, PostData.String(body), JsonType, ct);
        Require(response);
        var node = System.Text.Json.Nodes.JsonNode.Parse(response.Body) ?? throw new SearchUnavailableException("Elasticsearch answered without a body");
        var hits = node["hits"]?["hits"]?.AsArray() ?? [];
        var ids = hits.Select(h => h?["_id"]?.GetValue<string>() ?? throw new SearchUnavailableException("Elasticsearch listed a hit without an id")).ToList();
        return (ids, node["_scroll_id"]?.GetValue<string>() ?? string.Empty);
    }

    // The scroll context expires by itself after a minute; clearing it only frees the server sooner, so a failed clear is not a failure of the tick.
    private async Task ClearScrollAsync(string scrollId, CancellationToken ct)
    {
        if (scrollId.Length == 0)
        {
            return;
        }

        var body = new System.Text.Json.Nodes.JsonObject { ["scroll_id"] = scrollId }.ToJsonString();
        _ = await SendAsync(HttpMethod.DELETE, "/_search/scroll", PostData.String(body), JsonType, ct);
    }

    public async Task BulkAsync(string ndjson, CancellationToken ct)
    {
        var response = await SendAsync(HttpMethod.POST, "/_bulk", PostData.String(ndjson), "application/x-ndjson", ct);
        Require(response);
        var node = System.Text.Json.Nodes.JsonNode.Parse(response.Body);
        if (node?["errors"]?.GetValue<bool>() == true)
        {
            throw new SearchUnavailableException("Elasticsearch rejected part of a bulk write");
        }
    }

    private static string Action(string verb, string id) =>
        new System.Text.Json.Nodes.JsonObject { [verb] = new System.Text.Json.Nodes.JsonObject { ["_index"] = IndexName, ["_id"] = id } }.ToJsonString();

    private async Task<StringResponse> SendAsync(HttpMethod method, string path, PostData data, string? contentType, CancellationToken ct, TimeSpan? timeout = null)
    {
        var configuration = new RequestConfiguration { RequestTimeout = timeout ?? WriteTimeout, ContentType = contentType, Accept = "application/json" };
        try
        {
            return await _client.Transport.RequestAsync<StringResponse>(new EndpointPath(method, path), data, null, configuration, ct);
        }
        catch (Exception exception) when (exception is TransportException or HttpRequestException or TaskCanceledException && !ct.IsCancellationRequested)
        {
            throw new SearchUnavailableException("Elasticsearch could not be reached: " + exception.GetType().Name);
        }
    }

    // The reason names the request and Elasticsearch's own error type (a fixed word such as "illegal_argument_exception"), never the request's content.
    private static void Require(StringResponse response)
    {
        if (!response.ApiCallDetails.HasSuccessfulStatusCode)
        {
            var details = response.ApiCallDetails;
            throw new SearchUnavailableException($"Elasticsearch answered {details.HttpStatusCode} to {details.HttpMethod} {details.Uri?.AbsolutePath} ({ErrorType(response.Body)})");
        }
    }

    private static string ErrorType(string? body)
    {
        try
        {
            var type = System.Text.Json.Nodes.JsonNode.Parse(body ?? string.Empty)?["error"]?["type"]?.GetValue<string>();
            return type is { Length: > 0 and <= 80 } ? type : "no error type";
        }
        catch (Exception exception) when (exception is System.Text.Json.JsonException or InvalidOperationException)
        {
            return "no error type";
        }
    }
}
