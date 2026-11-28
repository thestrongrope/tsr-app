namespace Tsr.Search.Api.Domain;

/// <summary>
/// Weighted reciprocal rank fusion, as tsr-web's <c>rrfFuse</c> (<c>lectures-search-service.ts</c>) does it: for each list in order, a lecture at 0-based place i adds <c>weight / (60 + i + 1)</c> to its score. The first list's hit is the one kept for a lecture in
/// several lists (so a lecture found by keywords keeps its highlights and matched chapters), and the sort by score, best first, is stable: equal scores keep the order in which the lectures were first met. Fusing by rank sidesteps the scale difference between a keyword score and a cosine.
/// </summary>
internal static class ReciprocalRank
{
    private const int K = 60;

    public static IReadOnlyList<LectureResult> Fuse(IReadOnlyList<(IReadOnlyList<LectureResult> Hits, double Weight)> lists) =>
        [.. FuseScored(lists).Select(scored => scored.Hit)];

    /// <summary>The fused list with each lecture's fused score (the answer sends the lecture's own score, so only a test reads these).</summary>
    public static IReadOnlyList<(LectureResult Hit, double Score)> FuseScored(IReadOnlyList<(IReadOnlyList<LectureResult> Hits, double Weight)> lists)
    {
        ArgumentNullException.ThrowIfNull(lists);
        var order = new List<string>();
        var scores = new Dictionary<string, double>(StringComparer.Ordinal);
        var kept = new Dictionary<string, LectureResult>(StringComparer.Ordinal);
        foreach (var (hits, weight) in lists)
        {
            for (var place = 0; place < hits.Count; place++)
            {
                var slug = hits[place].Slug;
                if (!scores.TryGetValue(slug, out var score))
                {
                    order.Add(slug);
                    kept[slug] = hits[place];
                }

                scores[slug] = score + (weight / (K + place + 1));
            }
        }

        // OrderByDescending is stable, as the website's Array.prototype.sort is.
        return [.. order.OrderByDescending(slug => scores[slug]).Select(slug => (kept[slug], scores[slug]))];
    }
}
