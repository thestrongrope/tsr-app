using System.Globalization;
using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The rate limit of the two search routes (tsr-web <c>api/lib/rate-limit.ts</c>): 60 requests in a minute per client, counted separately for each route. The client is the caller's address
/// after the trusted proxies (<see cref="ClientAddress"/>), not the first <c>X-Forwarded-For</c> entry, which any client can write; the window slides and a refused request is not counted (<see cref="MemberRateLimit"/>).
/// The refusal is tsr-web's: <c>{"success": false, "error": "Too many requests"}</c> (the error is a string, and there is no <c>meta</c>) with <c>Retry-After</c>, <c>X-RateLimit-Limit</c> and <c>X-RateLimit-Remaining: 0</c>.
/// </summary>
internal static class SearchRateLimit
{
    public const string ArticleBucket = "v1-search";

    public const string LectureBucket = "v1-lecture-search";

    public const int MaxRequests = 60;

    public const int WindowSeconds = 60;

    /// <summary>Null when the request may go on; otherwise the 429 to send.</summary>
    public static IResult? Refuse(MemberRateLimit limit, HttpContext http, string bucket)
    {
        ArgumentNullException.ThrowIfNull(limit);
        ArgumentNullException.ThrowIfNull(http);
        var key = ClientAddress.RateKey(http);
        return limit.Allow(bucket, key, MaxRequests, WindowSeconds) ? null : new TooManyRequests(limit.RetryAfterSeconds(bucket, key, WindowSeconds));
    }

    private sealed class TooManyRequests(int retryAfterSeconds) : IResult
    {
        private static readonly byte[] Body = System.Text.Encoding.UTF8.GetBytes("""{"success":false,"error":"Too many requests"}""");

        public Task ExecuteAsync(HttpContext httpContext)
        {
            var response = httpContext.Response;
            WebsiteV1.AddFixedHeaders(response);
            response.StatusCode = StatusCodes.Status429TooManyRequests;
            response.ContentType = "application/json";
            response.Headers["Retry-After"] = retryAfterSeconds.ToString(CultureInfo.InvariantCulture);
            response.Headers["X-RateLimit-Limit"] = MaxRequests.ToString(CultureInfo.InvariantCulture);
            response.Headers["X-RateLimit-Remaining"] = "0";
            response.ContentLength = Body.Length;
            return response.Body.WriteAsync(Body, httpContext.RequestAborted).AsTask();
        }
    }
}
