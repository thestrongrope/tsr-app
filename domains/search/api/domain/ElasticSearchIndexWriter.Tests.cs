using System.Net;
using System.Text;
using System.Text.Json.Nodes;
using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The write side of the real index client against an in-process double of Elasticsearch: the requests it sends must have PHP's shapes (models/searchindex.php: ensureIndex, bulkUpsert, allIds, delete).
/// Not proved here, because it needs a real Elasticsearch: that the real server accepts the mapping and the bulk bodies.
/// </summary>
[TestFixture]
internal sealed class ElasticSearchIndexWriterTests
{
    private sealed record Seen(string Line, string Body, string ContentType);

    private sealed class Double : IDisposable
    {
        private readonly HttpListener _listener = new();
        private readonly Task _loop;

        public Double(Func<string, int, (int Status, string Body)> answer)
        {
            var probe = new System.Net.Sockets.TcpListener(IPAddress.Loopback, 0);
            probe.Start();
            var port = ((IPEndPoint)probe.LocalEndpoint).Port;
            probe.Stop();
            Url = new Uri($"http://127.0.0.1:{port}/");
            _listener.Prefixes.Add(Url.ToString());
            _listener.Start();
            _loop = Task.Run(async () =>
            {
                try
                {
                    while (true)
                    {
                        var context = await _listener.GetContextAsync();
                        using var input = context.Request.Headers["Content-Encoding"] == "gzip"
                            ? new System.IO.Compression.GZipStream(context.Request.InputStream, System.IO.Compression.CompressionMode.Decompress)
                            : context.Request.InputStream;
                        using var reader = new StreamReader(input, Encoding.UTF8);
                        var line = context.Request.HttpMethod + " " + context.Request.Url!.PathAndQuery;
                        Requests.Add(new Seen(line, await reader.ReadToEndAsync(), context.Request.ContentType ?? string.Empty));
                        var (status, body) = answer(line, Requests.Count);
                        context.Response.StatusCode = status;
                        context.Response.Headers["X-Elastic-Product"] = "Elasticsearch";
                        context.Response.ContentType = "application/json";
                        var bytes = Encoding.UTF8.GetBytes(body);
                        await context.Response.OutputStream.WriteAsync(bytes);
                        context.Response.Close();
                    }
                }
                catch (Exception exception) when (exception is HttpListenerException or ObjectDisposedException)
                {
                    // The listener was stopped by Dispose.
                }
            });
        }

        public Uri Url { get; }

        public List<Seen> Requests { get; } = [];

        public void Dispose()
        {
            _listener.Close();
            _loop.Wait(TimeSpan.FromSeconds(5));
        }
    }

    private static ElasticSearchIndex IndexOn(Double server) => new(SearchSettings.From(server.Url.ToString(), "pw"));

    [Test]
    public async Task Ensure_creates_the_index_with_PHPs_settings_and_mapping_when_it_is_missing()
    {
        using var server = new Double((line, _) => line.StartsWith("HEAD", StringComparison.Ordinal) ? (404, string.Empty) : (200, """{"acknowledged":true}"""));

        await IndexOn(server).EnsureIndexAsync(CancellationToken.None);

        Assert.That(server.Requests.Select(r => r.Line), Is.EqualTo(ExpectedEnsureLines));
        Assert.That(server.Requests[1].ContentType, Is.EqualTo("application/json"), "a real Elasticsearch answers 400 media_type_header_exception to any other type (found on the test stack, 12 Nov 2026)");
        var body = JsonNode.Parse(server.Requests[1].Body)!;
        Assert.That(body["settings"]!["number_of_shards"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(body["settings"]!["number_of_replicas"]!.GetValue<int>(), Is.Zero);
        var edge = body["settings"]!["analysis"]!["filter"]!["prefix_2_15"]!;
        Assert.That(edge["type"]!.GetValue<string>(), Is.EqualTo("edge_ngram"));
        Assert.That(edge["min_gram"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That(edge["max_gram"]!.GetValue<int>(), Is.EqualTo(15));
        Assert.That(body["settings"]!["analysis"]!["analyzer"]!["name_search"]!["filter"]!.AsArray().Select(n => n!.GetValue<string>()), Is.EqualTo(ExpectedSearchFilters));
        var properties = body["mappings"]!["properties"]!.AsObject();
        Assert.That(properties.Select(p => p.Key + ":" + p.Value!["type"]!.GetValue<string>()), Is.EqualTo(ExpectedFields));
        Assert.That(properties["name"]!["analyzer"]!.GetValue<string>(), Is.EqualTo("name_prefix"));
        Assert.That(properties["name"]!["search_analyzer"]!.GetValue<string>(), Is.EqualTo("name_search"));
    }

    [Test]
    public async Task Ensure_leaves_an_existing_index_alone()
    {
        using var server = new Double((_, _) => (200, string.Empty));

        await IndexOn(server).EnsureIndexAsync(CancellationToken.None);

        Assert.That(server.Requests.Select(r => r.Line), Is.EqualTo(ExpectedHeadOnly));
    }

    [Test]
    public async Task A_bulk_upsert_sends_an_index_action_and_the_document_per_line_as_ndjson()
    {
        using var server = new Double((_, _) => (200, """{"took":1,"errors":false,"items":[]}"""));
        var documents = new[]
        {
            SearchDocument.ForClass(5, "AB-1 &amp; C", 2, 3, "MIQDAD"),
            SearchDocument.ForStudent(900001, "Ali", 1, [5, 6], [1, 2]),
        };

        await IndexOn(server).BulkUpsertAsync(documents, CancellationToken.None);

        var request = server.Requests.Single();
        Assert.That(request.Line, Is.EqualTo("POST /_bulk"));
        Assert.That(request.ContentType, Does.StartWith("application/x-ndjson"));
        Assert.That(request.Body, Does.EndWith("\n"));
        var lines = request.Body.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.That(lines, Has.Length.EqualTo(4));
        Assert.That(lines[0], Is.EqualTo("""{"index":{"_index":"tsr-search","_id":"class:5"}}"""));
        // The serializer writes "&" as & (the same JSON); the entity in the code was decoded first.
        // The entity in the code was decoded first; the serializer may write "&" escaped, which is the same JSON, so this line is compared parsed.
        Assert.That(JsonNode.Parse(lines[1])!.ToJsonString(), Is.EqualTo(JsonNode.Parse("""{"kind":"class","id":5,"name":"AB-1 & C","gender":2,"level":"MIQDAD","level_id":3,"class_ids":[5],"class_genders":[2],"token":0}""")!.ToJsonString()));
        Assert.That(JsonNode.Parse(lines[1])!["name"]!.GetValue<string>(), Is.EqualTo("AB-1 & C"));
        Assert.That(lines[2], Is.EqualTo("""{"index":{"_index":"tsr-search","_id":"student:900001"}}"""));
        Assert.That(lines[3], Is.EqualTo("""{"kind":"student","id":900001,"name":"Ali","gender":1,"level":"","level_id":0,"class_ids":[5,6],"class_genders":[1,2],"token":900001}"""));
    }

    [Test]
    public async Task A_bulk_that_reports_errors_is_unavailable()
    {
        using var server = new Double((_, _) => (200, """{"took":1,"errors":true,"items":[{"index":{"status":400,"error":{"reason":"secret"}}}]}"""));

        var failure = await Assert.ThrowsAsync<SearchUnavailableException>(
            () => IndexOn(server).BulkUpsertAsync([SearchDocument.ForSubscriber(1, "A", 0)], CancellationToken.None));

        Assert.That(failure!.Message, Does.Not.Contain("secret"));
    }

    [Test]
    public async Task Listing_ids_scrolls_until_a_page_is_empty_then_clears_the_scroll()
    {
        using var server = new Double((line, count) => line switch
        {
            _ when count == 1 => (200, """{"_scroll_id":"s1","hits":{"hits":[{"_id":"class:5"},{"_id":"student:7"}]}}"""),
            _ when count == 2 => (200, """{"_scroll_id":"s2","hits":{"hits":[{"_id":"guide:2"}]}}"""),
            _ when count == 3 => (200, """{"_scroll_id":"s3","hits":{"hits":[]}}"""),
            _ => (200, """{"succeeded":true}"""),
        });

        var ids = await IndexOn(server).ListIdsAsync(CancellationToken.None);

        Assert.That(ids, Is.EqualTo(ExpectedIds));
        Assert.That(server.Requests.Select(r => r.Line), Is.EqualTo(ExpectedScrollLines));
        Assert.That(server.Requests.Select(r => r.ContentType), Is.All.EqualTo("application/json"));
        var first = JsonNode.Parse(server.Requests[0].Body)!;
        Assert.That(first["size"]!.GetValue<int>(), Is.EqualTo(1000));
        Assert.That(first["_source"]!.GetValue<bool>(), Is.False);
        Assert.That(first["query"]!["match_all"], Is.Not.Null);
        var next = JsonNode.Parse(server.Requests[1].Body)!;
        Assert.That(next["scroll"]!.GetValue<string>(), Is.EqualTo("1m"));
        Assert.That(next["scroll_id"]!.GetValue<string>(), Is.EqualTo("s1"));
    }

    [Test]
    public async Task A_bulk_delete_sends_a_delete_action_per_id()
    {
        using var server = new Double((_, _) => (200, """{"took":1,"errors":false,"items":[]}"""));

        await IndexOn(server).BulkDeleteAsync(["class:9", "student:7"], CancellationToken.None);

        var request = server.Requests.Single();
        Assert.That(request.Line, Is.EqualTo("POST /_bulk"));
        var lines = request.Body.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.That(lines, Is.EqualTo(ExpectedDeleteLines));
    }

    [TestCase(500)]
    [TestCase(401)]
    public async Task An_error_status_is_unavailable(int status)
    {
        using var server = new Double((_, _) => (status, """{"error":"secret internals"}"""));

        var failure = await Assert.ThrowsAsync<SearchUnavailableException>(() => IndexOn(server).BulkDeleteAsync(["class:9"], CancellationToken.None));

        Assert.That(failure!.Message, Does.Not.Contain("secret internals").And.Not.Contain("pw"));
    }

    [Test]
    public void The_index_is_configured_only_with_an_address()
    {
        Assert.That(new ElasticSearchIndex(SearchSettings.From("http://127.0.0.1:9", "pw")).IsConfigured, Is.True);
        Assert.That(new UnconfiguredSearchIndex().IsConfigured, Is.False);
    }

    private static readonly string[] ExpectedEnsureLines = ["HEAD /tsr-search", "PUT /tsr-search"];

    private static readonly string[] ExpectedHeadOnly = ["HEAD /tsr-search"];

    private static readonly string[] ExpectedSearchFilters = ["lowercase", "asciifolding", "arabic_normalization", "truncate_15"];

    private static readonly string[] ExpectedFields =
        ["kind:keyword", "id:long", "name:text", "gender:integer", "level:keyword", "level_id:integer", "class_ids:long", "class_genders:integer", "token:long"];

    private static readonly string[] ExpectedIds = ["class:5", "student:7", "guide:2"];

    private static readonly string[] ExpectedScrollLines =
        ["POST /tsr-search/_search?scroll=1m", "POST /_search/scroll", "POST /_search/scroll", "DELETE /_search/scroll"];

    private static readonly string[] ExpectedDeleteLines =
        ["""{"delete":{"_index":"tsr-search","_id":"class:9"}}""", """{"delete":{"_index":"tsr-search","_id":"student:7"}}"""];
}
