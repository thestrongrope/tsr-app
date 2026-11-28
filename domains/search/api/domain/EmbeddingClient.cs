using System.Buffers;
using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace Tsr.Search.Api.Domain;

/// <summary>The external boundary of the meaning layer: the embedding service. Fake in unit tests.</summary>
internal interface IQueryEmbedder
{
    /// <summary>The vector of a search text, or null when the service could not give a whole one (an error, a late answer, no vector). A failure is logged by its kind only, never the text. A caller that gave up still gets the cancellation.</summary>
    Task<float[]?> EmbedQueryAsync(string q, CancellationToken ct);
}

/// <summary>
/// The embedding service client (tsr-web <c>embedQuery</c>): <c>POST {url}/embed</c> with <c>{"texts": [q], "mode": "query"}</c>; the answer's <c>vectors[0]</c> is the vector. The model is <c>BAAI/bge-small-en-v1.5</c>, so a vector has 384 numbers; &/// kNN request fail and take the whole search with it, so it counts as no vector. The call has a timeout (1.5 seconds, tsr-web's <c>EMBED_TIMEOUT_MS</c>) and the answer is read up to a size limit. Any failure gives null, so lecture search degrades to keywords only (SRCH-R11).
/// </summary>
internal sealed partial class EmbeddingClient(HttpClient http, ILogger log, TimeSpan timeout) : IQueryEmbedder
{
    public const int Dimensions = 384;

    /// <summary>How long the service has to answer (tsr-web <c>EMBED_TIMEOUT_MS</c>).</summary>
    public static readonly TimeSpan Timeout = TimeSpan.FromMilliseconds(1500);

    /// <summary>A vector of 384 numbers is about 10 KB as text; far more than this is not the service.</summary>
    private const int MaxAnswerBytes = 256 * 1024;

    public async Task<float[]?> EmbedQueryAsync(string q, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(q);
        using var limit = CancellationTokenSource.CreateLinkedTokenSource(ct);
        limit.CancelAfter(timeout);
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "/embed") { Content = new StringContent(Body(q), System.Text.Encoding.UTF8, "application/json") };
            using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, limit.Token);
            if (!response.IsSuccessStatusCode)
            {
                LogFailed(log, "answered " + (int)response.StatusCode);
                return null;
            }

            var bytes = await ReadLimitedAsync(response, limit.Token);
            return bytes is null ? Failed("answered more than the limit") : Vector(bytes);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            return Failed("timed out");
        }
        catch (HttpRequestException)
        {
            return Failed("could not be reached");
        }
    }

    private static string Body(string q)
    {
        var buffer = new ArrayBufferWriter<byte>();
        using (var json = new Utf8JsonWriter(buffer))
        {
            json.WriteStartObject();
            json.WriteStartArray("texts");
            json.WriteStringValue(q);
            json.WriteEndArray();
            json.WriteString("mode", "query");
            json.WriteEndObject();
        }

        return System.Text.Encoding.UTF8.GetString(buffer.WrittenSpan);
    }

    private static async Task<byte[]?> ReadLimitedAsync(HttpResponseMessage response, CancellationToken ct)
    {
        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        using var read = new MemoryStream();
        var chunk = new byte[8192];
        int count;
        while ((count = await stream.ReadAsync(chunk, ct)) > 0)
        {
            if (read.Length + count > MaxAnswerBytes)
            {
                return null;
            }

            read.Write(chunk, 0, count);
        }

        return read.ToArray();
    }

    private float[]? Vector(byte[] answer)
    {
        try
        {
            using var document = JsonDocument.Parse(answer);
            if (!document.RootElement.TryGetProperty("vectors", out var vectors) || vectors.ValueKind != JsonValueKind.Array || vectors.GetArrayLength() == 0)
            {
                return Failed("answered without a vector");
            }

            var first = vectors[0];
            if (first.ValueKind != JsonValueKind.Array || first.GetArrayLength() != Dimensions || first.EnumerateArray().Any(n => n.ValueKind != JsonValueKind.Number))
            {
                return Failed("answered with a vector that is not 384 finite numbers");
            }

            var numbers = first.EnumerateArray().Select(n => n.GetSingle()).ToArray();
            // The engine measures the vector in floats and refuses one whose length is NaN or infinite (measured on 9.2.3), so the sum of squares must fit a float too.
            var squares = 0f;
            foreach (var n in numbers)
            {
                squares += n * n;
            }

            if (numbers.Any(n => !float.IsFinite(n)) || !float.IsFinite(squares))
            {
                return Failed("answered with a vector that is not 384 finite numbers");
            }

            // Cosine similarity has no direction for a vector of zeros, and the engine may refuse it (and the whole search with it).
            return numbers.All(n => n == 0) ? Failed("answered with a vector of zeros") : numbers;
        }
        catch (JsonException)
        {
            return Failed("answered with text that is not JSON");
        }
    }

    private float[]? Failed(string kind)
    {
        LogFailed(log, kind);
        return null;
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "Lecture search: the embedding service {Kind}; answering from keywords only")]
    private static partial void LogFailed(ILogger logger, string kind);
}

/// <summary>The embedder when the meaning layer is off: never asked (the weight is 0); it has no vector to give.</summary>
internal sealed class NoQueryEmbedder : IQueryEmbedder
{
    public static NoQueryEmbedder Instance { get; } = new();

    private NoQueryEmbedder()
    {
    }

    public Task<float[]?> EmbedQueryAsync(string q, CancellationToken ct) => Task.FromResult<float[]?>(null);
}
