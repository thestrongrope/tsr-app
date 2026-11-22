using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Content.Api.Domain;

namespace Tsr.Content.Api.Features.V1Article;

// Slice: GET /api/v1/articles/{slug} -> one published article with its HTML and five related articles (the Markdown is not sent), in the answer shape supported app builds read from today's website (domain/V1.cs).
// Public: no caller, no permission. It reads content.published_articles, which holds published articles only, so a draft's slug is an unknown slug.
// A port of tsr-web web/src/app/api/v1/articles/[slug]/route.ts, getArticleBySlug (api/lib/article-service.ts) and getRelatedPosts (lib/markdown.ts); that code is the rule, quirks kept:
//   - related: every OTHER article scores 2 for each of this article's categories it shares and 1 for each tag; the five highest, equal scores newest first (then by slug).
//     A score of 0 is still a score: an article sharing nothing fills the five. Each is a list item (domain/ArticleListItem.cs), readingTime 1.
//   - readingTime is the real one here (stored by the refresh from the Markdown); Last-Modified is the article's modified date, else its published date.
//   - the 404 names the slug asked and nothing else.
// The path value arrives percent-decoded and is matched, case and all, against slug_decoded; the answer's slug is the file's own text.
// Any text is only a value of the one query parameter. A NUL, which PostgreSQL would refuse, never arrives: the server (and the gateway) answer 400 to a path holding one.
// One statement reads the article and its related ones, so a refresh between two reads cannot mix two sets.
// tsr-web's featuredImage and videoUrl are not sent: no content file has either and no column stores them.
// Contract: spec/api.yaml. Behaviour: spec/tests/v1-article.hurl.

internal static class V1ArticleSlice
{
    /// <summary>Bound on the related articles of one answer (MUST 2); tsr-web asks for 5.</summary>
    public const int RelatedLimit = 5;

    private const int MaxAgeSeconds = 3600;

    private const int StaleWhileRevalidateSeconds = 86400;

    /// <summary>The article itself at <see cref="Position"/> 0, with its body; then its related articles from 1, without one.</summary>
    internal sealed record Row(
        int Position,
        string Slug,
        int? LegacyId,
        string Title,
        string? Excerpt,
        string PublishedDateText,
        string? ModifiedDateText,
        string Author,
        string[] Categories,
        string[] Tags,
        string Language,
        int ReadingMinutes,
        string? Content,
        DateTimeOffset? LastModified);

    public static IEndpointRouteBuilder MapV1Article(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/api/v1/articles/{slug}", HandleAsync).WithV1Failures();
        return routes;
    }

    private static async Task<IResult> HandleAsync(string slug, ContentContext db, CancellationToken ct)
    {
        var rows = await ReadAsync(db, slug, ct);
        if (rows.Count == 0)
        {
            return V1.Error(StatusCodes.Status404NotFound, V1.NotFound, "Article not found: " + slug);
        }

        var article = rows[0];
        var related = rows.Skip(1).ToList();
        return V1.Ok(json => Write(json, article, related), MaxAgeSeconds, StaleWhileRevalidateSeconds, lastModified: article.LastModified);
    }

    private static Task<List<Row>> ReadAsync(ContentContext db, string slug, CancellationToken ct) =>
        db.Database
            .SqlQuery<Row>($"""
                with asked as (
                    select * from content.published_articles where slug_decoded = {slug}::text
                ),
                related as (
                    select other.*, row_number() over (
                        order by 2 * (select count(*) from unnest(asked.categories) as mine where mine = any (other.categories))
                                 + (select count(*) from unnest(asked.tags) as mine where mine = any (other.tags)) desc,
                                 other.published_at desc,
                                 other.slug asc) as position
                    from asked
                    join content.published_articles as other on other.slug <> asked.slug
                    order by position
                    limit {RelatedLimit}
                )
                select 0 as "Position", slug as "Slug", legacy_id as "LegacyId", title::text as "Title", excerpt::text as "Excerpt",
                       published_date_text::text as "PublishedDateText", modified_date_text::text as "ModifiedDateText", author::text as "Author",
                       categories as "Categories", tags as "Tags", language::text as "Language", reading_minutes as "ReadingMinutes",
                       body_html as "Content", coalesce(modified_at, published_at) as "LastModified"
                from asked
                union all
                select position::int, slug, legacy_id, title::text, excerpt::text,
                       published_date_text::text, modified_date_text::text, author::text,
                       categories, tags, language::text, reading_minutes,
                       null, null
                from related
                order by "Position"
                """)
            .ToListAsync(ct);

    /// <summary>tsr-web <c>getArticleBySlug</c>, in its field order.</summary>
    private static void Write(Utf8JsonWriter json, Row article, List<Row> related)
    {
        json.WriteStartObject();
        ListItem(article).WriteFields(json, article.ReadingMinutes);
        json.WriteString("content", article.Content);
        json.WriteStartArray("relatedArticles");
        foreach (var other in related)
        {
            ListItem(other).Write(json);
        }

        json.WriteEndArray();
        json.WriteEndObject();
    }

    private static ArticleListItem ListItem(Row row) => new(
        row.Slug,
        row.LegacyId,
        row.Title,
        row.Excerpt,
        row.PublishedDateText,
        row.ModifiedDateText,
        row.Author,
        row.Categories,
        row.Tags,
        row.Language);
}
