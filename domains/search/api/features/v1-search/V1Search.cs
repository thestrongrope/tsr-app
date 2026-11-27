using System.Diagnostics;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Tsr.Search.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Search.Api.Features.V1Search;

// Slice: GET /api/v1/search?q=&limit=&offset=&category= -> the published articles that match q, best match first, in the answer shape supported app builds read from today's website (shared/api/WebsiteV1.cs).
// Public: no caller, no permission. A port of tsr-web web/src/app/api/v1/search/route.ts and search() (api/lib/search-service.ts); that code is the rule, quirks kept:
//   - the rate limit runs first, then q (trimmed; missing or blank is a 400 VALIDATION_ERROR), then the search.
//   - limit is 20 by default and kept between 1 and 100, offset 0 by default and never below 0 (WebsiteV1.IntParam); one category, used as written; `fields` is accepted and ignored.
//   - pagination.total is the number of results on THIS page and hasMore is true exactly when that number equals limit.
//   - Elasticsearch when configured and answering; otherwise the database fallback (domain/ArticleFallback.cs), searchEngine "fuse". Cache-Control public, max-age=60, an ETag, Vary, and never a 304.
//   - deliberate difference: highlights are HTML-encoded (Elasticsearch `encoder: html`; the fallback encodes the text around the match before it adds <em>), so no markup of an article reaches an HTML reader. tsr-web does not encode.
//   - no search event is written here (the analytics port is a later task, plan 12b); the one place that would write it is after the search, before the answer.
// Contract: spec/api.yaml. Behaviour: spec/tests/v1-search.hurl, db/tests/V1SearchTests.cs.

internal static class V1SearchSlice
{
    private const int MaxAgeSeconds = 60;

    private const int DefaultLimit = 20;

    private const int MaxLimit = 100;

    public static IEndpointRouteBuilder MapV1Search(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/api/v1/search", HandleAsync).WithV1Failures();
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, MemberRateLimit limiter, ILibraryIndex index, IArticleFallback fallback, ILoggerFactory loggers, CancellationToken ct)
    {
        if (SearchRateLimit.Refuse(limiter, context, SearchRateLimit.ArticleBucket) is { } refusal)
        {
            return refusal;
        }

        var query = context.Request.Query;
        var q = query["q"].FirstOrDefault()?.Trim();
        if (string.IsNullOrEmpty(q))
        {
            return WebsiteV1.Error(StatusCodes.Status400BadRequest, WebsiteV1.ValidationError, "Missing required parameter: q");
        }

        var limit = WebsiteV1.IntParam(query["limit"].FirstOrDefault(), DefaultLimit, 1, MaxLimit);
        var offset = WebsiteV1.IntParam(query["offset"].FirstOrDefault(), 0, 0);
        if (ArticleSearchQuery.Validate(q, limit, offset) is { } reason)
        {
            return WebsiteV1.Error(StatusCodes.Status400BadRequest, WebsiteV1.ValidationError, reason);
        }

        var category = query["category"].FirstOrDefault();
        var request = new ArticleSearchRequest(q, string.IsNullOrEmpty(category) ? null : category, limit, offset);

        var started = Stopwatch.GetTimestamp();
        var outcome = await ArticleSearch.RunAsync(index, fallback, request, loggers.CreateLogger("Tsr.Search.Api.Features.V1Search"), ct);
        var took = (long)Stopwatch.GetElapsedTime(started).TotalMilliseconds;

        return WebsiteV1.OkAlways(
            json => Write(json, outcome, q, took),
            MaxAgeSeconds,
            swr: 0,
            new WebsiteV1.Pagination(outcome.Results.Count, limit, offset, HasMore: outcome.Results.Count == limit));
    }

    private static void Write(Utf8JsonWriter json, ArticleSearchOutcome outcome, string q, long took)
    {
        json.WriteStartObject();
        json.WriteStartArray("results");
        foreach (var result in outcome.Results)
        {
            result.Write(json);
        }

        json.WriteEndArray();
        json.WriteString("query", q);
        json.WriteString("searchEngine", outcome.Engine);
        json.WriteNumber("took", took);
        json.WriteEndObject();
    }
}
