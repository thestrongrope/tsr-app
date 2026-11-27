using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The database fallback of article search (SRCH-R6), used while the engine is down or not configured. tsr-web falls back to Fuse.js; this is a plain SQL search over <c>content.v_published_articles</c>, the published view of content (rule 2).
/// Each word of the text (white space separated, 2 characters or more, at most <see cref="MaxWords"/>) must occur, without regard to case, in at least one of the title, excerpt, body, tags or categories (<c>ILIKE</c>, the word a bound parameter
/// with <c>%</c>, <c>_</c> and <c>\</c> escaped, so it matches itself only). The rank of an article is the sum, over the words, of Fuse's weights of the fields the word is in: title 2, excerpt 1.5, body 1, tags 1.2, categories 0.8; equal ranks are
/// ordered newest first, then by slug. The category is an exact member of the article's categories. The score is the rank over the best rank of all matches, 0 to 1.
/// What differs from Fuse.js: a misspelt word finds nothing, its operators (<c>'</c> <c>!</c> <c>^</c> <c>=</c> <c>|</c>) are ordinary text, and the order and the scores differ. The page holds at most 100 articles (the route's own limit).
/// </summary>
internal sealed class ArticleFallback(NpgsqlDataSource source) : IArticleFallback
{
    public const int MaxWords = 10;

    private const int MinWordLength = 2;

    /// <summary>The words of a text that the search looks for.</summary>
    public static IReadOnlyList<string> Words(string q)
    {
        ArgumentNullException.ThrowIfNull(q);
        return [.. q.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries)
            .Where(word => word.Length >= MinWordLength)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(MaxWords)];
    }

    /// <summary>The <c>LIKE</c> pattern that matches the word anywhere in a text and nothing else.</summary>
    public static string Pattern(string word)
    {
        ArgumentNullException.ThrowIfNull(word);
        return "%" + word.Replace("\\", "\\\\", StringComparison.Ordinal).Replace("%", "\\%", StringComparison.Ordinal).Replace("_", "\\_", StringComparison.Ordinal) + "%";
    }

    public async Task<IReadOnlyList<ArticleResult>> SearchAsync(ArticleSearchRequest request, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(request);
        var words = Words(request.Q);
        if (words.Count == 0)
        {
            return [];
        }

        string?[] patterns = [.. words.Select(Pattern)];
        var rows = await source.ListAsync(
            $"""
            with w (p) as (select unnest({patterns}::text[])),
            hits as (
                select a.slug, a.title::text as title, a.excerpt::text as excerpt, a.body_markdown::text as body, a.published_at, a.published_date_text::text as published_date,
                       a.modified_date_text::text as modified_date, a.author::text as author, a.language::text as language, a.reading_minutes, a.legacy_id, a.categories, a.tags,
                       (select coalesce(sum(
                              (case when a.title::text ilike w.p then 2.0 else 0 end)
                            + (case when coalesce(a.excerpt::text, '') ilike w.p then 1.5 else 0 end)
                            + (case when a.body_markdown::text ilike w.p then 1.0 else 0 end)
                            + (case when array_to_string(a.tags, ' ') ilike w.p then 1.2 else 0 end)
                            + (case when array_to_string(a.categories, ' ') ilike w.p then 0.8 else 0 end)), 0) from w) as rank
                from content.v_published_articles a
                where ({request.Category}::text is null or {request.Category}::text = any (a.categories))
                  and not exists (
                      select 1 from w
                      where not (a.title::text ilike w.p or coalesce(a.excerpt::text, '') ilike w.p or a.body_markdown::text ilike w.p
                                 or array_to_string(a.tags, ' ') ilike w.p or array_to_string(a.categories, ' ') ilike w.p))
            )
            select slug as "Slug", title as "Title", excerpt as "Excerpt", body as "Body", published_date as "PublishedDate", modified_date as "ModifiedDate", author as "Author", language as "Language",
                   reading_minutes as "ReadingMinutes", legacy_id as "LegacyId", categories as "Categories", tags as "Tags", rank::numeric as "Rank", (max(rank) over ())::numeric as "Best"
            from hits
            order by rank desc, published_at desc, slug asc
            limit {request.Limit} offset {request.Offset}
            """,
            row => Read(row, words),
            ct);
        return rows;
    }

    private static ArticleResult Read(DbRow row, IReadOnlyList<string> words)
    {
        var best = row.Decimal("Best");
        var title = row.Text("Title");
        var excerpt = row.TextOrNull("Excerpt");
        return new ArticleResult(
            row.IntOrNull("LegacyId") ?? 0,
            row.Text("Slug"),
            title,
            excerpt,
            row.Text("PublishedDate"),
            row.TextOrNull("ModifiedDate"),
            row.Text("Author"),
            row.TextArray("Categories"),
            row.TextArray("Tags"),
            row.Text("Language"),
            row.Int("ReadingMinutes"),
            best > 0 ? (double)(row.Decimal("Rank") / best) : 0,
            ArticleHighlights.Build(words, title, excerpt, row.Text("Body")));
    }
}
