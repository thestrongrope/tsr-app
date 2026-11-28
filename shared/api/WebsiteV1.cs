using System.Buffers;
using System.Globalization;
using System.Security.Cryptography;
using System.Text.Encodings.Web;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace Tsr.Shared.Api;

/// <summary>
/// The answer shape of the public <c>/api/v1/</c> routes, which supported app builds already read from today's website:
/// <c>{success, data, meta, pagination?}</c> and, for a failure, <c>{success: false, error: {code, message}, meta}</c>. It is the named exception to the API's <c>{"detail"}</c> errors.
/// A port of tsr-web's <c>web/src/app/api/lib/api-response.ts</c> and <c>cache-utils.ts</c>, with the cross-origin headers its <c>middleware.ts</c> adds to every <c>/api/</c> answer.
/// One difference, on purpose: tsr-web hashes its ETag over route-specific values; here it is over <c>data</c> and <c>pagination</c> only, never <c>meta</c>, whose timestamp changes on every answer.
/// The JSON is written with <see cref="Utf8JsonWriter"/>: no reflection, and a field that is absent is left out as JavaScript leaves out <c>undefined</c>.
/// Every answer also says <c>X-Content-Type-Options: nosniff</c> (not in tsr-web): a failure's message can repeat text of the request, and no browser should read it as a page.
/// </summary>
public static partial class WebsiteV1
{
    public const string ValidationError = "VALIDATION_ERROR";

    public const string NotFound = "NOT_FOUND";

    private const string InternalError = "INTERNAL_ERROR";

    // tsr-web errorResponse, for an error that is not one of its own: the same words whatever failed.
    private const string InternalErrorMessage = "An unexpected error occurred";

    private const string ApiVersion = "1.0";

    // JavaScript's Date.toISOString.
    private const string IsoShape = "yyyy-MM-dd'T'HH:mm:ss.fff'Z'";

    // As JSON.stringify: only what JSON must escape, so text in any script is sent as written.
    private static readonly JsonWriterOptions Json = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    public sealed record Pagination(int Total, int Limit, int Offset, bool HasMore);

    /// <summary>Endpoint metadata: this endpoint answers failures in the <c>/api/v1/</c> shape. <see cref="WithV1Failures"/> adds it; a test finds it.</summary>
    public sealed class FailureShape
    {
        public static readonly FailureShape Instance = new();

        private FailureShape()
        {
        }
    }

    /// <summary>
    /// A 200 with <paramref name="data"/> (which writes exactly one JSON value), or a 304 when the request's validators match.
    /// <paramref name="swr"/> 0 sends no <c>stale-while-revalidate</c>. <paramref name="lastModified"/> is given only by a route that sends <c>Last-Modified</c>.
    /// </summary>
    public static IResult Ok(Action<Utf8JsonWriter> data, int maxAge, int swr, Pagination? pagination = null, DateTimeOffset? lastModified = null) =>
        new OkResult(data, maxAge, swr, pagination, lastModified);

    /// <summary>A 200 whatever validators the request carries: tsr-web's videos route sends an ETag but never compares it.</summary>
    public static IResult OkAlways(Action<Utf8JsonWriter> data, int maxAge, int swr, Pagination pagination) =>
        new OkResult(data, maxAge, swr, pagination, lastModified: null, conditional: false);

    /// <summary>
    /// Makes one <c>GET</c> route of <c>/api/v1/</c> answer as tsr-web answers an unknown error: whatever its handler throws is a 500 in the failure shape, with nothing of the exception in it.
    /// The route is mapped by the slice itself (<c>routes.MapGet(pattern, HandleAsync).WithV1Failures()</c>), so the request delegate generator sees the handler's real signature.
    /// </summary>
    public static RouteHandlerBuilder WithV1Failures(this RouteHandlerBuilder route) =>
        route.AddEndpointFilter(AnswerFailureAsync).WithMetadata(FailureShape.Instance);

    /// <summary>A failure. No cache headers, and <c>meta.cache.maxAge</c> 0, as tsr-web's <c>errorResponse</c> without a cache config.</summary>
    public static IResult Error(int status, string code, string message) => new ErrorResult(status, code, message);

    /// <summary>
    /// tsr-web <c>parseIntParam</c>: JavaScript's <c>parseInt(raw, 10)</c> (leading white space, one sign, then digits; whatever follows is ignored), clamped to the bounds.
    /// Nothing readable gives <paramref name="fallback"/>, unclamped. A number past the largest integer stops there (JavaScript goes on; no list is that long).
    /// </summary>
    public static int IntParam(string? raw, int fallback, int min, int max = int.MaxValue)
    {
        var text = raw.AsSpan().TrimStart();
        var negative = text.StartsWith("-", StringComparison.Ordinal);
        if (negative || text.StartsWith("+", StringComparison.Ordinal))
        {
            text = text[1..];
        }

        long value = 0;
        var digits = 0;
        while (digits < text.Length && char.IsAsciiDigit(text[digits]))
        {
            value = Math.Min((value * 10) + (text[digits] - '0'), int.MaxValue);
            digits++;
        }

        return digits == 0 ? fallback : (int)Math.Clamp(negative ? -value : value, min, max);
    }

    /// <summary>The log has the exception's type name only: its message can hold text of the request or of the database. A request the caller gave up is not a failure.</summary>
    private static async ValueTask<object?> AnswerFailureAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;
        try
        {
            return await next(context);
        }
        catch (Exception failure) when (!http.RequestAborted.IsCancellationRequested)
        {
            var log = http.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger(typeof(WebsiteV1).FullName!);
            LogFailure(log, http.Request.Path, failure.GetType().Name);
            return Error(StatusCodes.Status500InternalServerError, InternalError, InternalErrorMessage);
        }
    }

    private static byte[] Fragment(Action<Utf8JsonWriter> write)
    {
        var buffer = new ArrayBufferWriter<byte>();
        using (var json = new Utf8JsonWriter(buffer, Json))
        {
            write(json);
        }

        return buffer.WrittenSpan.ToArray();
    }

    private static void WriteMeta(Utf8JsonWriter json, DateTimeOffset now, int maxAge)
    {
        json.WriteStartObject("meta");
        json.WriteString("timestamp", Iso(now));
        json.WriteString("version", ApiVersion);
        json.WriteStartObject("cache");
        json.WriteString("expires", Iso(now.AddSeconds(maxAge)));
        json.WriteNumber("maxAge", maxAge);
        json.WriteEndObject();
        json.WriteEndObject();
    }

    /// <summary>JavaScript's <c>Date.toISOString</c>.</summary>
    public static string Iso(DateTimeOffset at) => at.UtcDateTime.ToString(IsoShape, CultureInfo.InvariantCulture);

    private static DateTimeOffset Now(HttpContext http) => http.RequestServices.GetRequiredService<TimeProvider>().GetUtcNow();

    /// <summary>On every answer, the 304 and the failures too: the cross-origin headers of tsr-web's <c>middleware.ts</c>, and <c>nosniff</c>.</summary>
    public static void AddFixedHeaders(HttpResponse response)
    {
        response.Headers.XContentTypeOptions = "nosniff";
        response.Headers.AccessControlAllowOrigin = "*";
        response.Headers.AccessControlAllowMethods = "GET, POST, PUT, DELETE, OPTIONS";
        response.Headers.AccessControlAllowHeaders = "Content-Type, Authorization, X-Requested-With";
    }

    private static Task WriteAsync(HttpContext http, int status, byte[] body)
    {
        http.Response.StatusCode = status;
        http.Response.ContentType = "application/json";
        http.Response.ContentLength = body.Length;
        return http.Response.Body.WriteAsync(body, http.RequestAborted).AsTask();
    }

    private sealed class OkResult(Action<Utf8JsonWriter> data, int maxAge, int swr, Pagination? pagination, DateTimeOffset? lastModified, bool conditional = true) : IResult
    {
        public Task ExecuteAsync(HttpContext httpContext)
        {
            var dataJson = Fragment(data);
            var pageJson = pagination is null ? [] : Fragment(WritePagination);
            var etag = ETag(dataJson, pageJson);
            AddFixedHeaders(httpContext.Response);
            if (conditional && IsNotModified(httpContext.Request, etag))
            {
                // tsr-web's notModifiedResponse: the status and nothing else.
                httpContext.Response.StatusCode = StatusCodes.Status304NotModified;
                return Task.CompletedTask;
            }

            var headers = httpContext.Response.Headers;
            headers.CacheControl = swr > 0
                ? string.Create(CultureInfo.InvariantCulture, $"public, max-age={maxAge}, stale-while-revalidate={swr}")
                : string.Create(CultureInfo.InvariantCulture, $"public, max-age={maxAge}");
            headers.ETag = etag;
            if (lastModified is { } modified)
            {
                headers.LastModified = modified.UtcDateTime.ToString("r", CultureInfo.InvariantCulture);
            }

            headers.Vary = "Accept-Encoding";
            var now = Now(httpContext);
            var body = Fragment(json =>
            {
                json.WriteStartObject();
                json.WriteBoolean("success", true);
                json.WritePropertyName("data");
                json.WriteRawValue(dataJson, skipInputValidation: true);
                WriteMeta(json, now, maxAge);
                if (pagination is not null)
                {
                    json.WritePropertyName("pagination");
                    json.WriteRawValue(pageJson, skipInputValidation: true);
                }

                json.WriteEndObject();
            });
            return WriteAsync(httpContext, StatusCodes.Status200OK, body);
        }

        private void WritePagination(Utf8JsonWriter json)
        {
            json.WriteStartObject();
            json.WriteNumber("total", pagination!.Total);
            json.WriteNumber("limit", pagination.Limit);
            json.WriteNumber("offset", pagination.Offset);
            json.WriteBoolean("hasMore", pagination.HasMore);
            json.WriteEndObject();
        }

        /// <summary>MD5 as tsr-web's <c>generateETag</c>: a cache validator, not a secret, and the length today's clients already see.</summary>
        private static string ETag(byte[] dataJson, byte[] pageJson)
        {
            using var hash = IncrementalHash.CreateHash(HashAlgorithmName.MD5);
            hash.AppendData(dataJson);
            hash.AppendData(pageJson);
            return "\"" + Convert.ToHexStringLower(hash.GetHashAndReset()) + "\"";
        }

        /// <summary>
        /// tsr-web <c>checkConditionalRequest</c>: <c>If-None-Match</c> equal to the ETag as one whole text (no list, no weak form), or, on a route with a <c>Last-Modified</c>,
        /// an <c>If-Modified-Since</c> that is not older than it. JavaScript's dates count milliseconds, so the comparison does too.
        /// Unlike tsr-web, where either one is enough: a request that carries <c>If-None-Match</c> is judged by it alone (RFC 9110 section 13.1.3),
        /// so a cache that sends both headers does not keep an old copy of a corrected article whose date did not move.
        /// </summary>
        private bool IsNotModified(HttpRequest request, string etag)
        {
            if (request.Headers.IfNoneMatch.Count > 0)
            {
                return request.Headers.IfNoneMatch.ToString() == etag;
            }

            var since = request.Headers.IfModifiedSince.ToString();
            var styles = DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal;
            return lastModified is { } modified
                && DateTimeOffset.TryParse(since, CultureInfo.InvariantCulture, styles, out var clientDate)
                && modified.ToUnixTimeMilliseconds() <= clientDate.ToUnixTimeMilliseconds();
        }
    }

    private sealed class ErrorResult(int status, string code, string message) : IResult
    {
        public Task ExecuteAsync(HttpContext httpContext)
        {
            AddFixedHeaders(httpContext.Response);
            var now = Now(httpContext);
            var body = Fragment(json =>
            {
                json.WriteStartObject();
                json.WriteBoolean("success", false);
                json.WriteStartObject("error");
                json.WriteString("code", code);
                json.WriteString("message", message);
                json.WriteEndObject();
                WriteMeta(json, now, maxAge: 0);
                json.WriteEndObject();
            });
            return WriteAsync(httpContext, status, body);
        }
    }

    [LoggerMessage(Level = LogLevel.Error, Message = "An /api/v1/ route failed: {Path}: {Failure}")]
    private static partial void LogFailure(ILogger logger, string path, string failure);
}
