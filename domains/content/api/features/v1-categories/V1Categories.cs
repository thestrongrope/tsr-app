using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Content.Api.Domain;

namespace Tsr.Content.Api.Features.V1Categories;

// Slice: GET /api/v1/taxonomies/categories -> the categories with each one's count of published articles, in the answer shape supported app builds read from today's website (domain/V1.cs).
// Public: no caller, no permission. The counts are over content.published_articles, which holds published articles only (a draft is never copied there).
// A port of tsr-web web/src/app/api/v1/taxonomies/categories/route.ts, getCategoriesWithCounts (api/lib/article-service.ts) and getCategoryWithArticleCount (lib/markdown.ts);
// that code is the rule, quirks kept:
//   - an option is off only when its first value is exactly "false"; any other value, an empty one too, leaves it on. Unknown options are ignored.
//   - a count is of the articles filed under that category's own slug: a parent's count does not include its children's.
//   - the tree is one level: the categories without a parent, each with the categories that name it. A child of a child, or of a slug that is no category, is only in the flat list.
//   - flat: every category, a child naming its parent, none with subcategories.
//   - without counts every articleCount is 0 and still sent.
//   - order: the category's order (999 for a file with none or with 0, stored so by the refresh), equal orders by slug.
// Every category is sent: there is no paging, and the table holds only the category files of one refresh (bounded there, and by MaxCategories here).
// Contract: spec/api.yaml. Behaviour: spec/tests/v1-categories.hurl.

internal static class V1CategoriesSlice
{
    private const int MaxAgeSeconds = 3600;

    private const int StaleWhileRevalidateSeconds = 86400;

    private const string Off = "false";

    /// <summary>Bound on one answer (MUST 2): the most files one refresh reads, and a category is one file, so no category is ever cut off.</summary>
    private const int MaxCategories = ContentFiles.MaxFiles;

    /// <summary>One category, in the order of the answer.</summary>
    internal sealed record Row(string Slug, string Title, string? Description, int Order, string? Parent, int ArticleCount);

    public static IEndpointRouteBuilder MapV1Categories(this IEndpointRouteBuilder routes)
    {
        V1.MapGet(routes, "/api/v1/taxonomies/categories", HandleAsync);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ContentContext db, CancellationToken ct)
    {
        var hierarchical = IsOn(context.Request.Query, "hierarchical");
        var withCounts = IsOn(context.Request.Query, "includeArticleCounts");
        var rows = await db.Database
            .SqlQuery<Row>($"""
                select category.slug as "Slug", category.title::text as "Title", category.description::text as "Description",
                       category.sort_order as "Order", category.parent_slug as "Parent",
                       case when {withCounts} then
                           (select count(*) from content.published_articles as article where article.categories @> array[category.slug])::int
                       else 0 end as "ArticleCount"
                from content.categories as category
                order by category.sort_order, category.slug
                limit {MaxCategories}
                """)
            .ToListAsync(ct);

        return V1.Ok(json => Write(json, rows, hierarchical), MaxAgeSeconds, StaleWhileRevalidateSeconds);
    }

    /// <summary>tsr-web's <c>searchParams.get(name) !== 'false'</c>.</summary>
    private static bool IsOn(IQueryCollection query, string name) =>
        !(query.TryGetValue(name, out var values) && values.Count > 0 && string.Equals(values[0], Off, StringComparison.Ordinal));

    private static void Write(Utf8JsonWriter json, List<Row> rows, bool hierarchical)
    {
        json.WriteStartArray();
        // tsr-web's "!cat.parent": no parent, or an empty one.
        foreach (var row in rows.Where(row => !hierarchical || string.IsNullOrEmpty(row.Parent)))
        {
            json.WriteStartObject();
            WriteFields(json, row);
            if (hierarchical)
            {
                WriteChildren(json, rows.Where(child => child.Parent == row.Slug).ToList());
            }

            json.WriteEndObject();
        }

        json.WriteEndArray();
    }

    /// <summary>A category without children has no <c>subcategories</c> field, as tsr-web leaves it out.</summary>
    private static void WriteChildren(Utf8JsonWriter json, List<Row> children)
    {
        if (children.Count == 0)
        {
            return;
        }

        json.WriteStartArray("subcategories");
        foreach (var child in children)
        {
            json.WriteStartObject();
            WriteFields(json, child);
            json.WriteEndObject();
        }

        json.WriteEndArray();
    }

    /// <summary>tsr-web's field order. A description or a parent the file does not have is left out.</summary>
    private static void WriteFields(Utf8JsonWriter json, Row row)
    {
        json.WriteString("slug", row.Slug);
        json.WriteString("title", row.Title);
        if (row.Description is not null)
        {
            json.WriteString("description", row.Description);
        }

        json.WriteNumber("order", row.Order);
        if (row.Parent is not null)
        {
            json.WriteString("parent", row.Parent);
        }

        json.WriteNumber("articleCount", row.ArticleCount);
    }
}
