using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>TC-SRCH-R11-02 (the embedder half): the embedding service gives a query vector, or null on any failure (an error, a late answer, no vector, a vector of the wrong size), and a failure is logged with its kind only, never the text.</summary>
[TestFixture]
internal sealed class EmbeddingClientTests
{
    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> respond) : HttpMessageHandler
    {
        public List<(string Path, string Body)> Requests { get; } = [];

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests.Add((request.RequestUri!.AbsolutePath, request.Content is null ? string.Empty : await request.Content.ReadAsStringAsync(cancellationToken)));
            return await respond(request, cancellationToken);
        }
    }

    private sealed class CaptureLog : ILogger
    {
        public List<(LogLevel Level, string Line)> Lines { get; } = [];

        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            Lines.Add((logLevel, formatter(state, exception)));
    }

    private static HttpResponseMessage Json(string body, HttpStatusCode status = HttpStatusCode.OK) =>
        new(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    private static string Vectors(int size) => """{"vectors":[[""" + string.Join(",", Enumerable.Repeat("0.5", size)) + """]],"dim":384}""";

    private static EmbeddingClient Client(Handler handler, ILogger log, TimeSpan? timeout = null) =>
        new(new HttpClient(handler) { BaseAddress = new Uri("http://embeddings.invalid:8000") }, log, timeout ?? TimeSpan.FromSeconds(1.5));

    [Test]
    public async Task A_good_answer_gives_the_vector_and_the_request_is_the_websites()
    {
        var handler = new Handler((_, _) => Task.FromResult(Json(Vectors(384))));

        var vector = await Client(handler, new CaptureLog()).EmbedQueryAsync("sorrow \"and\" comfort", CancellationToken.None);

        Assert.That(vector, Has.Length.EqualTo(384));
        Assert.That(vector![0], Is.EqualTo(0.5f));
        Assert.That(handler.Requests.Single().Path, Is.EqualTo("/embed"));
        using var sent = JsonDocument.Parse(handler.Requests.Single().Body);
        Assert.That(sent.RootElement.GetProperty("texts")[0].GetString(), Is.EqualTo("sorrow \"and\" comfort"));
        Assert.That(sent.RootElement.GetProperty("mode").GetString(), Is.EqualTo("query"));
    }

    [Test]
    public async Task An_answer_that_is_an_error_gives_null_and_a_log_line_without_the_text()
    {
        var log = new CaptureLog();
        var client = Client(new Handler((_, _) => Task.FromResult(Json("{}", HttpStatusCode.InternalServerError))), log);

        var vector = await client.EmbedQueryAsync("secret query text", CancellationToken.None);

        Assert.That(vector, Is.Null);
        Assert.That(log.Lines, Has.Count.EqualTo(1));
        Assert.That(log.Lines[0].Level, Is.EqualTo(LogLevel.Warning));
        Assert.That(log.Lines[0].Line, Does.Contain("500").And.Not.Contain("secret"));
    }

    [Test]
    public async Task A_late_answer_gives_null_after_the_timeout_not_after_the_answer()
    {
        var log = new CaptureLog();
        var client = Client(new Handler(async (_, ct) =>
        {
            await Task.Delay(TimeSpan.FromSeconds(30), ct);
            return Json(Vectors(384));
        }), log, TimeSpan.FromMilliseconds(100));
        var started = System.Diagnostics.Stopwatch.GetTimestamp();

        var vector = await client.EmbedQueryAsync("slow", CancellationToken.None);

        Assert.That(vector, Is.Null);
        Assert.That(System.Diagnostics.Stopwatch.GetElapsedTime(started), Is.LessThan(TimeSpan.FromSeconds(5)));
        Assert.That(log.Lines.Single().Line, Does.Contain("timed out"));
    }

    [TestCase("""{"vectors":[]}""")]
    [TestCase("""{"nothing":true}""")]
    [TestCase("not json")]
    [TestCase("""{"vectors":[[0.5,0.25]]}""")]
    [TestCase("""{"vectors":[["a","b"]]}""")]
    public async Task An_answer_without_a_whole_vector_gives_null(string body)
    {
        var log = new CaptureLog();

        var vector = await Client(new Handler((_, _) => Task.FromResult(Json(body))), log).EmbedQueryAsync("q", CancellationToken.None);

        Assert.That(vector, Is.Null);
        Assert.That(log.Lines, Has.Count.EqualTo(1));
    }

    [Test]
    public async Task A_vector_with_a_number_too_large_for_a_float_gives_null_and_a_log_line_of_the_kind_only()
    {
        var log = new CaptureLog();
        var body = Vectors(384).Replace("0.5", "1e39", StringComparison.Ordinal);

        var vector = await Client(new Handler((_, _) => Task.FromResult(Json(body))), log).EmbedQueryAsync("secret text", CancellationToken.None);

        Assert.That(vector, Is.Null, "an infinite number would fail while the kNN body is written, and the search with it");
        Assert.That(log.Lines.Single().Line, Does.Contain("not 384 finite numbers").And.Not.Contain("secret").And.Not.Contain("1e39"));
    }

    [Test]
    public async Task A_vector_whose_length_overflows_a_float_gives_null_because_the_engine_refuses_it()
    {
        var body = Vectors(384).Replace("0.5", "1e19", StringComparison.Ordinal);

        var vector = await Client(new Handler((_, _) => Task.FromResult(Json(body))), new CaptureLog()).EmbedQueryAsync("q", CancellationToken.None);

        Assert.That(vector, Is.Null, "Elasticsearch: NaN or Infinite magnitude detected");
    }

    [Test]
    public async Task A_vector_of_zeros_gives_null_because_cosine_similarity_has_no_direction_for_it()
    {
        var log = new CaptureLog();
        var body = Vectors(384).Replace("0.5", "0", StringComparison.Ordinal);

        var vector = await Client(new Handler((_, _) => Task.FromResult(Json(body))), log).EmbedQueryAsync("q", CancellationToken.None);

        Assert.That(vector, Is.Null);
        Assert.That(log.Lines.Single().Line, Does.Contain("zeros"));
    }

    [Test]
    public void The_embedder_timeout_is_1500_milliseconds_as_the_websites() =>
        Assert.That(EmbeddingClient.Timeout, Is.EqualTo(TimeSpan.FromMilliseconds(1500)));

    [Test]
    public async Task A_service_that_cannot_be_reached_gives_null()
    {
        var log = new CaptureLog();
        var client = Client(new Handler((_, _) => throw new HttpRequestException("connection refused: embeddings.invalid")), log);

        var vector = await client.EmbedQueryAsync("q", CancellationToken.None);

        Assert.That(vector, Is.Null);
        Assert.That(log.Lines.Single().Line, Does.Not.Contain("embeddings.invalid"));
    }

    [Test]
    public async Task A_request_the_caller_gave_up_is_not_turned_into_null()
    {
        using var cancelled = new CancellationTokenSource();
        cancelled.Cancel();
        var client = Client(new Handler(async (_, ct) =>
        {
            await Task.Delay(TimeSpan.FromSeconds(30), ct);
            return Json(Vectors(384));
        }), new CaptureLog());

        await Assert.ThatAsync(() => client.EmbedQueryAsync("q", cancelled.Token), Throws.InstanceOf<OperationCanceledException>());
    }

    [Test]
    public async Task An_answer_over_the_size_limit_gives_null()
    {
        var huge = """{"vectors":[[""" + string.Join(",", Enumerable.Repeat("0.123456789", 40_000)) + "]]}";

        var vector = await Client(new Handler((_, _) => Task.FromResult(Json(huge))), new CaptureLog()).EmbedQueryAsync("q", CancellationToken.None);

        Assert.That(vector, Is.Null);
    }
}
