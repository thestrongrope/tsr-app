using System.Net;
using System.Text;
using System.Text.Json.Nodes;
using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The real index client against an in-process double of Elasticsearch (a loopback listener that records the request and answers as told): the request it sends, and how a failure reads.
/// Not proved here, because it needs a real Elasticsearch: the analyzers of the mapping, the scoring, the real error bodies and the client's version handshake beyond the product header.
/// </summary>
[TestFixture]
internal sealed class ElasticSearchIndexTests
{
    private sealed class Double : IDisposable
    {
        private readonly HttpListener _listener = new();
        private readonly Task _loop;

        public Double(int status, string body)
        {
            var port = FreePort();
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
                        Requests.Add((context.Request.HttpMethod + " " + context.Request.Url!.AbsolutePath, await reader.ReadToEndAsync(), context.Request.Headers["Authorization"] ?? string.Empty));
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

        public List<(string Line, string Body, string Authorization)> Requests { get; } = [];

        public void Dispose()
        {
            _listener.Close();
            _loop.Wait(TimeSpan.FromSeconds(5));
        }

        private static int FreePort()
        {
            var probe = new System.Net.Sockets.TcpListener(IPAddress.Loopback, 0);
            probe.Start();
            var port = ((IPEndPoint)probe.LocalEndpoint).Port;
            probe.Stop();
            return port;
        }
    }

    // The client writes a list of one as the bare object, which Elasticsearch reads the same way.
    private static JsonArray List(JsonNode node) => node as JsonArray ?? [node.DeepClone()];

    private const string TwoHits = """{"took":1,"timed_out":false,"_shards":{"total":1,"successful":1,"skipped":0,"failed":0},"hits":{"total":{"value":2,"relation":"eq"},"hits":[{"_index":"tsr-search","_id":"class:5","_score":1.0,"_source":{"id":5,"name":"AB-1"}},{"_index":"tsr-search","_id":"class:6","_score":0.5,"_source":{"id":6}}]}}""";

    private const string TwoHitsWithNonAsciiName = """{"took":1,"timed_out":false,"_shards":{"total":1,"successful":1,"skipped":0,"failed":0},"hits":{"total":{"value":2,"relation":"eq"},"hits":[{"_index":"tsr-search","_id":"class:5","_score":1.0,"_source":{"id":5,"name":"Zoë ال"}},{"_index":"tsr-search","_id":"class:6","_score":0.5,"_source":{"id":6}}]}}""";

    private const string OneHitWithATextId = """{"took":1,"timed_out":false,"_shards":{"total":1,"successful":1,"skipped":0,"failed":0},"hits":{"total":{"value":1,"relation":"eq"},"hits":[{"_index":"tsr-search","_id":"class:5","_score":1.0,"_source":{"id":"abc","name":"AB-1"}}]}}""";

    [Test]
    public async Task An_unlimited_scope_sends_the_text_as_a_match_value_and_only_the_kind_filter()
    {
        using var server = new Double(200, TwoHits);
        var index = new ElasticSearchIndex(SearchSettings.From(server.Url.ToString(), "pw"));

        var hits = await index.SearchAsync("class", "x OR *:* \"q\" (a) \\", SearchScope.Everything, 100, CancellationToken.None);

        Assert.That(hits, Is.EqualTo(new List<SearchHit> { new(5, "AB-1"), new(6, string.Empty) }));
        var request = server.Requests.Single();
        Assert.That(request.Line, Is.EqualTo("POST /tsr-search/_search"));
        var body = JsonNode.Parse(request.Body)!;
        Assert.That(body["size"]!.GetValue<int>(), Is.EqualTo(100));
        Assert.That(body["_source"]!["includes"]!.AsArray().Select(n => n!.GetValue<string>()), Is.EqualTo(new List<string> { "id", "name" }));
        var match = List(body["query"]!["bool"]!["must"]!)[0]!["match"]!["name"]!;
        Assert.That(match["query"]!.GetValue<string>(), Is.EqualTo("x OR *:* \"q\" (a) \\"));
        Assert.That(match["operator"]!.GetValue<string>(), Is.EqualTo("and"));
        var filter = List(body["query"]!["bool"]!["filter"]!);
        Assert.That(filter, Has.Count.EqualTo(1));
        Assert.That(filter[0]!["terms"]!["kind"]![0]!.GetValue<string>(), Is.EqualTo("class"));
        Assert.That(request.Authorization, Is.EqualTo("Basic " + Convert.ToBase64String(Encoding.UTF8.GetBytes("elastic:pw"))));
    }

    [Test]
    public async Task A_limited_scope_adds_a_should_filter_that_needs_one_of_the_terms()
    {
        using var server = new Double(200, TwoHits);
        var index = new ElasticSearchIndex(SearchSettings.From(server.Url.ToString(), string.Empty));
        var scope = SearchScope.Limited([new TermsClause("class_genders", [1]), new TermsClause("class_ids", [4, 9])]);

        await index.SearchAsync("student", "ab", scope, 100, CancellationToken.None);

        var filter = List(JsonNode.Parse(server.Requests.Single().Body)!["query"]!["bool"]!["filter"]!);
        Assert.That(filter, Has.Count.EqualTo(2));
        Assert.That(filter[0]!["terms"]!["kind"]![0]!.GetValue<string>(), Is.EqualTo("student"));
        var should = filter[1]!["bool"]!;
        Assert.That(should["minimum_should_match"]!.GetValue<int>(), Is.EqualTo(1));
        var clauses = List(should["should"]!);
        Assert.That(clauses, Has.Count.EqualTo(2));
        Assert.That(clauses[0]!["terms"]!["class_genders"]!.AsArray().Select(n => n!.GetValue<long>()), Is.EqualTo(new List<long> { 1 }));
        Assert.That(clauses[1]!["terms"]!["class_ids"]!.AsArray().Select(n => n!.GetValue<long>()), Is.EqualTo(new List<long> { 4, 9 }));
    }

    [TestCase(500)]
    [TestCase(503)]
    [TestCase(404)]
    [TestCase(401)]
    public async Task An_error_answer_is_unavailable_never_an_empty_result(int status)
    {
        using var server = new Double(status, """{"error":{"type":"x","reason":"secret internals"},"status":0}""");
        var index = new ElasticSearchIndex(SearchSettings.From(server.Url.ToString(), "pw"));

        var failure = await Assert.ThrowsAsync<SearchUnavailableException>(() => index.SearchAsync("class", "ab", SearchScope.Everything, 100, CancellationToken.None));

        Assert.That(failure!.Message, Does.Not.Contain("secret internals").And.Not.Contain("pw"));
    }

    [Test]
    public async Task Found_documents_are_read_with_their_ids_and_names()
    {
        using var server = new Double(200, TwoHitsWithNonAsciiName);
        var index = new ElasticSearchIndex(SearchSettings.From(server.Url.ToString(), "pw"));

        var hits = await index.SearchAsync("class", "ab", SearchScope.Everything, 100, CancellationToken.None);

        Assert.That(hits, Is.EqualTo(new List<SearchHit> { new(5, "Zoë ال"), new(6, string.Empty) }));
    }

    [Test]
    public async Task A_document_that_cannot_be_read_makes_its_kind_unavailable()
    {
        using var server = new Double(200, OneHitWithATextId);
        var index = new ElasticSearchIndex(SearchSettings.From(server.Url.ToString(), "pw"));

        await Assert.ThrowsAsync<SearchUnavailableException>(() => index.SearchAsync("class", "ab", SearchScope.Everything, 100, CancellationToken.None));
    }

    [Test]
    public async Task A_server_that_is_not_listening_is_unavailable()
    {
        var closed = new Double(200, "{}");
        var url = closed.Url;
        closed.Dispose();
        var index = new ElasticSearchIndex(SearchSettings.From(url.ToString(), "pw"));

        await Assert.ThrowsAsync<SearchUnavailableException>(() => index.SearchAsync("class", "ab", SearchScope.Everything, 100, CancellationToken.None));
    }
}
