namespace Tsr.Search.Api.Domain;

/// <summary>What <c>GET /api/v1/lectures/search</c> asked for. <see cref="Q"/> is as the caller sent it (untrimmed, as tsr-web uses it); blank after a trim means browse.</summary>
internal sealed record LectureSearchRequest(string Q, string? Language, int Limit, int Offset);

/// <summary>The lectures of the page, the text to echo (empty for a browse), the engine name and the total the answer reports.</summary>
internal sealed record LectureSearchOutcome(IReadOnlyList<LectureResult> Results, string Query, string Engine, long Total);

/// <summary>
/// The engine work of lecture search (tsr-web <c>searchLectures</c>, <c>lectures-search-service.ts</c>). There is no fallback: an engine that is not configured, fails or answers with something that is not a search answer is a
/// <see cref="SearchUnavailableException"/> for the caller (a 500 in the website's failure shape, SRCH-R12). Only the embedding service degrades: with no vector the answer is the keyword answer (SRCH-R11).
/// Browse: a blank text lists the lectures newest first. Search: the strict keyword body; when it finds fewer than 3 lectures in total (the total, not the page, so a deep page does not trigger it) the fuzzy body is sent once and its answer replaces the strict one.
/// Meaning layer (<paramref name="semanticWeight"/> above 0): the keyword search asks for a pool of 50, the query vector comes from the embedder, a kNN search gives a second ranking, and the two are fused by rank. The total is then the length of the fused list;
/// with no vector the pool of 50 is cut by offset and limit and the total stays the engine's (the website's quirk, kept: a page at offset 50 or more is empty while the total says there is more).
/// </summary>
internal static class LectureSearch
{
    /// <summary>A strict stage that finds fewer lectures than this is retried with fuzziness (the query was probably misspelt).</summary>
    private const int FuzzyBelow = 3;

    public static async Task<LectureSearchOutcome> RunAsync(ILibraryIndex index, IQueryEmbedder embedder, double semanticWeight, LectureSearchRequest request, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(index);
        ArgumentNullException.ThrowIfNull(embedder);
        ArgumentNullException.ThrowIfNull(request);
        if (!index.IsConfigured)
        {
            throw new SearchUnavailableException("Elasticsearch is not configured");
        }

        return string.IsNullOrWhiteSpace(request.Q)
            ? await BrowseAsync(index, request, ct)
            : await SearchAsync(index, embedder, semanticWeight, request, ct);
    }

    private static async Task<LectureSearchOutcome> BrowseAsync(ILibraryIndex index, LectureSearchRequest request, CancellationToken ct)
    {
        var page = await ReadAsync(index, LectureSearchQuery.Browse(request.Language, request.Limit, request.Offset), ct);
        return new LectureSearchOutcome([.. page.Hits.Select(hit => hit.ForBrowse())], string.Empty, "elasticsearch", page.Total);
    }

    private static async Task<LectureSearchOutcome> SearchAsync(ILibraryIndex index, IQueryEmbedder embedder, double semanticWeight, LectureSearchRequest request, CancellationToken ct)
    {
        var semantic = semanticWeight > 0;
        var page = await ReadAsync(index, LectureSearchQuery.Keyword(request.Q, request.Language, request.Limit, request.Offset, semantic, fuzzy: false), ct);
        if (page.Total < FuzzyBelow)
        {
            page = await ReadAsync(index, LectureSearchQuery.Keyword(request.Q, request.Language, request.Limit, request.Offset, semantic, fuzzy: true), ct);
        }

        if (!semantic)
        {
            return new LectureSearchOutcome(page.Hits, request.Q, "elasticsearch", page.Total);
        }

        var vector = await embedder.EmbedQueryAsync(request.Q, ct);
        if (vector is null)
        {
            return new LectureSearchOutcome(Page(page.Hits, request), request.Q, "elasticsearch", page.Total);
        }

        var meaning = await ReadAsync(index, LectureSearchQuery.Knn(vector, request.Language), ct);
        var fused = ReciprocalRank.Fuse([(page.Hits, LectureSettings.KeywordWeight), (meaning.Hits, semanticWeight)]);
        return new LectureSearchOutcome(Page(fused, request), request.Q, "elasticsearch+semantic", fused.Count);
    }

    private static IReadOnlyList<LectureResult> Page(IReadOnlyList<LectureResult> hits, LectureSearchRequest request) =>
        [.. hits.Skip(request.Offset).Take(request.Limit)];

    private static async Task<LecturePage> ReadAsync(ILibraryIndex index, string body, CancellationToken ct) =>
        LectureResult.ReadPage(await index.SearchAsync(LectureSearchQuery.IndexName, body, ct));
}
