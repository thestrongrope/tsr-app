using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Content.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Content.Api.Features.V1Articles;

// Slice: GET /api/v1/articles -> one page of the published articles, in the answer shape supported app builds read from today's website (shared/api/WebsiteV1.cs).
// Public: no caller, no permission. It reads content.published_articles, which holds published articles only (a draft is never copied there).
// A port of tsr-web web/src/app/api/v1/articles/route.ts and queryArticles (api/lib/article-service.ts); that code is the rule, quirks kept:
//   - limit and offset are clamped, never refused; only an unknown sort is refused; an empty option is no option; unknown options are ignored.
//   - category, tag and locale match one whole value exactly, case and all; q is a substring of the title, the excerpt or one tag, whatever its case.
//   - a category, tag, locale or q holding a NUL matches nothing (tsr-web compares in memory; PostgreSQL would refuse the value, so it is never sent).
//   - every item's readingTime is 1 (domain/ArticleListItem.cs).
//   - ties keep tsr-web's base order, newest first (its sort is stable over that list), in both directions of the title order; equal dates go by slug.
// Title order is ICU's ("en-x-icu"), the collation behind JavaScript's localeCompare. The fields of an item: domain/ArticleListItem.cs.
// Contract: spec/api.yaml. Behaviour: spec/tests/v1-articles.hurl.

internal static class V1ArticlesSlice
{
    public const int DefaultLimit = 20;

    /// <summary>Bound on one answer (MUST 2).</summary>
    public const int MaxLimit = 100;

    private const int MaxAgeSeconds = 300;

    private const int StaleWhileRevalidateSeconds = 600;

    private const string DefaultSort = "publishedDate:desc";

    private static readonly string[] ValidSorts = ["publishedDate:asc", "publishedDate:desc", "title:asc", "title:desc"];

    /// <summary>
    /// One row a page item, in page order. The count of every match and the newest change of ALL published articles ride on each row, read in the same statement as the page.
    /// A page past the end still gives one row, with no <see cref="Slug"/>.
    /// </summary>
    internal sealed record Row(
        int Total,
        DateTimeOffset? LastModified,
        string? Slug,
        int? LegacyId,
        string? Title,
        string? Excerpt,
        string? PublishedDateText,
        string? ModifiedDateText,
        string? Author,
        string[]? Categories,
        string[]? Tags,
        string? Language);

    public static IEndpointRouteBuilder MapV1Articles(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/api/v1/articles", HandleAsync).WithV1Failures();
        return routes;
    }

    /// <summary>What one request asks, read from its query. A filter that is null is not asked.</summary>
    private sealed record Request(int Limit, int Offset, string Sort, string? Category, string? Tag, string? Locale, string? Q)
    {
        /// <summary>PostgreSQL text cannot hold a NUL, so a filter value with one matches no article; such a value is never sent to the database.</summary>
        public bool MatchesNothing => HasNul(Category) || HasNul(Tag) || HasNul(Locale) || HasNul(Q);

        private static bool HasNul(string? value) => value is not null && value.Contains('\0');
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, TimeProvider clock, CancellationToken ct)
    {
        var request = Parse(context.Request.Query);
        if (!ValidSorts.Contains(request.Sort, StringComparer.Ordinal))
        {
            return WebsiteV1.Error(StatusCodes.Status400BadRequest, WebsiteV1.ValidationError, "Invalid sort parameter. Valid options: " + string.Join(", ", ValidSorts));
        }

        var rows = await QueryAsync(source, request, ct);
        return Answer(rows, request, clock);
    }

    private static Request Parse(IQueryCollection query) => new(
        Limit: WebsiteV1.IntParam(First(query, "limit"), DefaultLimit, 1, MaxLimit),
        Offset: WebsiteV1.IntParam(First(query, "offset"), 0, 0),
        Sort: First(query, "sort") ?? DefaultSort,
        Category: First(query, "category"),
        Tag: First(query, "tag"),
        Locale: First(query, "locale"),
        Q: First(query, "q"));

    /// <summary>The page and what rides on it (<see cref="Row"/>): always at least one row. With a filter that matches nothing no filter value is sent, and no article is read as matched.</summary>
    private static Task<List<Row>> QueryAsync(NpgsqlDataSource source, Request request, CancellationToken ct)
    {
        var nothing = request.MatchesNothing;
        var category = nothing ? null : request.Category;
        var tag = nothing ? null : request.Tag;
        var locale = nothing ? null : request.Locale;
        var q = nothing ? null : request.Q;
        var sort = request.Sort;
        var limit = request.Limit;
        var offset = request.Offset;
        return source.ListAsync(
            $"""
                with matched as (
                    select slug, legacy_id, title::text as title, excerpt::text as excerpt, published_at, published_date_text::text as published_date_text,
                           modified_date_text::text as modified_date_text, author::text as author, categories, tags, language::text as language
                    from content.published_articles
                    where not {nothing}
                      and ({category}::text is null or categories @> array[{category}::text])
                      and ({tag}::text is null or tags @> array[{tag}::text])
                      and ({locale}::text is null or language::text = {locale}::text)
                      and ({q}::text is null
                           or strpos(lower(title::text), lower({q}::text)) > 0
                           or strpos(lower(coalesce(excerpt::text, '')), lower({q}::text)) > 0
                           or exists (select 1 from unnest(tags) as one_tag where strpos(lower(one_tag), lower({q}::text)) > 0))
                ),
                page as (
                    select matched.*, row_number() over (
                        order by case when {sort}::text = 'publishedDate:asc' then published_at end asc,
                                 case when {sort}::text = 'title:asc' then title collate "en-x-icu" end asc,
                                 case when {sort}::text = 'title:desc' then title collate "en-x-icu" end desc,
                                 published_at desc,
                                 slug asc) as position
                    from matched
                    order by position
                    limit {limit} offset {offset}
                )
                select (select count(*) from matched)::int as "Total",
                       (select max(coalesce(modified_at, published_at)) from content.published_articles) as "LastModified",
                       page.slug as "Slug", page.legacy_id as "LegacyId", page.title as "Title", page.excerpt as "Excerpt",
                       page.published_date_text as "PublishedDateText", page.modified_date_text as "ModifiedDateText", page.author as "Author",
                       page.categories as "Categories", page.tags as "Tags", page.language as "Language"
                from (select 1) as always
                left join page on true
                order by page.position
                """,
            Read,
            ct);
    }

    private static Row Read(DbRow row) => new(
        row.Int("Total"),
        row.InstantOrNull("LastModified"),
        row.TextOrNull("Slug"),
        row.IntOrNull("LegacyId"),
        row.TextOrNull("Title"),
        row.TextOrNull("Excerpt"),
        row.TextOrNull("PublishedDateText"),
        row.TextOrNull("ModifiedDateText"),
        row.TextOrNull("Author"),
        row.TextArrayOrNull("Categories"),
        row.TextArrayOrNull("Tags"),
        row.TextOrNull("Language"));

    private static IResult Answer(List<Row> rows, Request request, TimeProvider clock)
    {
        var total = rows[0].Total;
        var items = rows.Where(row => row.Slug is not null).ToList();
        return WebsiteV1.Ok(
            json => WriteItems(json, items),
            MaxAgeSeconds,
            StaleWhileRevalidateSeconds,
            new WebsiteV1.Pagination(total, request.Limit, request.Offset, HasMore: (long)request.Offset + request.Limit < total),
            // tsr-web getLastModifiedDate: with no article at all, now.
            rows[0].LastModified ?? clock.GetUtcNow());
    }

    /// <summary>URLSearchParams.get with tsr-web's <c>|| undefined</c>: the first value of the name; an empty one is no value.</summary>
    private static string? First(IQueryCollection query, string name) =>
        query.TryGetValue(name, out var values) && values.Count > 0 && !string.IsNullOrEmpty(values[0]) ? values[0] : null;

    private static void WriteItems(Utf8JsonWriter json, List<Row> items)
    {
        json.WriteStartArray();
        foreach (var item in items)
        {
            ListItem(item).Write(json);
        }

        json.WriteEndArray();
    }

    /// <summary>A row of the page (never the empty row of a page past the end, so its columns are filled).</summary>
    private static ArticleListItem ListItem(Row row) => new(
        row.Slug!,
        row.LegacyId,
        row.Title!,
        row.Excerpt,
        row.PublishedDateText!,
        row.ModifiedDateText,
        row.Author!,
        row.Categories ?? [],
        row.Tags ?? [],
        row.Language!);
}
