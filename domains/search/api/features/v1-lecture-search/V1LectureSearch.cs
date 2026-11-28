using System.Diagnostics;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Search.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Search.Api.Features.V1LectureSearch;

// Slice: GET /api/v1/lectures/search?q=&limit=&offset=&language= -> the lectures that match q, best first, each with the chapters that matched; without q, every lecture newest first. The answer shape of today's website (shared/api/WebsiteV1.cs).
// Public: no caller, no permission. A port of tsr-web web/src/app/api/v1/lectures/search/route.ts and searchLectures (api/lib/lectures-search-service.ts); that code is the rule, quirks kept:
//   - the rate limit runs first (its own bucket, 60 a minute), then the numbers; q is optional and used UNTRIMMED (blank after a trim means browse, with `query` empty); limit and offset as article search; one language, an exact filter, empty means none.
//   - Elasticsearch only. Not configured, failing or unreadable is a 500 INTERNAL_ERROR in the website's shape with nothing of the failure in it (WithV1Failures): no database fallback (owner decision d2).
//   - the meaning layer (domain/LectureSearch.cs) when TSR_LECTURES_SEMANTIC_WEIGHT is above 0 and TSR_EMBEDDINGS_URL is set; an embedding service that fails gives the keyword answer with searchEngine "elasticsearch".
//   - pagination.total is data.total and hasMore is true exactly when offset plus the results on this page is below it. Cache-Control public, max-age=60, an ETag, Vary, and never a 304.
//   - bounds the website does not have (deliberate, plan 3.10): offset plus limit at most 10000, q at most 200 characters and language at most 10 letters and hyphens, a 400 in the website's error shape before any outside call (the same as article search).
//   - highlights are HTML-encoded (Elasticsearch `encoder: html`); tsr-web's are not. No search event is written here (the analytics port is a later task, plan 12b).
// Contract: spec/api.yaml. Behaviour: spec/tests/v1-lecture-search.hurl, db/tests/V1LectureSearchTests.cs.

internal static class V1LectureSearchSlice
{
    private const int MaxAgeSeconds = 60;

    private const int DefaultLimit = 20;

    private const int MaxLimit = 100;

    public static IEndpointRouteBuilder MapV1LectureSearch(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/api/v1/lectures/search", HandleAsync).WithV1Failures();
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, MemberRateLimit limiter, ILibraryIndex index, IQueryEmbedder embedder, LectureSettings settings, CancellationToken ct)
    {
        if (SearchRateLimit.Refuse(limiter, context, SearchRateLimit.LectureBucket) is { } refusal)
        {
            return refusal;
        }

        var query = context.Request.Query;
        var q = query["q"].FirstOrDefault() ?? string.Empty;
        var limit = WebsiteV1.IntParam(query["limit"].FirstOrDefault(), DefaultLimit, 1, MaxLimit);
        var offset = WebsiteV1.IntParam(query["offset"].FirstOrDefault(), 0, 0);
        var language = query["language"].FirstOrDefault();
        if ((ArticleSearchQuery.Validate(q, limit, offset) ?? LectureSearchQuery.ValidateLanguage(language)) is { } reason)
        {
            return WebsiteV1.Error(StatusCodes.Status400BadRequest, WebsiteV1.ValidationError, reason);
        }

        var started = Stopwatch.GetTimestamp();
        var weight = settings.SemanticEnabled ? settings.SemanticWeight : 0;
        var outcome = await LectureSearch.RunAsync(index, embedder, weight, new LectureSearchRequest(q, string.IsNullOrEmpty(language) ? null : language, limit, offset), ct);
        var took = (long)Stopwatch.GetElapsedTime(started).TotalMilliseconds;

        return WebsiteV1.OkAlways(
            json => Write(json, outcome, took),
            MaxAgeSeconds,
            swr: 0,
            new WebsiteV1.Pagination((int)Math.Min(outcome.Total, int.MaxValue), limit, offset, HasMore: (long)offset + outcome.Results.Count < outcome.Total));
    }

    private static void Write(Utf8JsonWriter json, LectureSearchOutcome outcome, long took)
    {
        json.WriteStartObject();
        json.WriteStartArray("results");
        foreach (var result in outcome.Results)
        {
            result.Write(json);
        }

        json.WriteEndArray();
        json.WriteString("query", outcome.Query);
        json.WriteString("searchEngine", outcome.Engine);
        json.WriteNumber("total", outcome.Total);
        json.WriteNumber("took", took);
        json.WriteEndObject();
    }
}
