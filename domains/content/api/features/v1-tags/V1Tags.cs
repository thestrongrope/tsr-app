using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Content.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Content.Api.Features.V1Tags;

// Slice: GET /api/v1/taxonomies/tags -> every tag of the published articles with its count, most used first, in the answer shape supported app builds read from today's website (domain/V1.cs).
// Public: no caller, no permission. It reads content.published_articles, which holds published articles only (a draft is never copied there).
// A port of tsr-web web/src/app/api/v1/taxonomies/tags/route.ts and getAllTags (api/lib/article-service.ts); that code is the rule, quirks kept:
//   - a tag is its exact name, case and all; a name written twice on one article counts twice.
//   - equal counts keep the order in which each tag is first met, walking the articles newest first (equal dates by slug) and each article's tags in file order:
//     tsr-web counts into a Map in that walk and its sort is stable.
//   - the slug is made from the name on every answer (Slug below); two names can have the same slug, and a name in another script an empty one.
//   - no options, no paging: every tag is sent. The table holds one refresh's articles, each with at most 50 tags (bounded there, and by MaxTags here).
// Contract: spec/api.yaml. Behaviour: spec/tests/v1-tags.hurl.

internal static partial class V1TagsSlice
{
    private const int MaxAgeSeconds = 3600;

    private const int StaleWhileRevalidateSeconds = 86400;

    /// <summary>More tags than one article may carry (the refresh allows 50): an article's place times this, plus a tag's place in it, orders the walk.</summary>
    private const int PlacesAnArticle = 1000;

    /// <summary>Bound on one answer (MUST 2): the most distinct tags one refresh can store (its most files, each with its most tags), so no tag is ever cut off.</summary>
    private const int MaxTags = ContentFiles.MaxFiles * ContentFiles.MaxLabels;

    /// <summary>One tag, in the order of the answer.</summary>
    internal sealed record Row(string Name, int ArticleCount);

    public static IEndpointRouteBuilder MapV1Tags(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/api/v1/taxonomies/tags", HandleAsync).WithV1Failures();
        return routes;
    }

    private static async Task<IResult> HandleAsync(NpgsqlDataSource source, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"""
                select tag.name as "Name", count(*)::int as "ArticleCount"
                from (
                    select tags, row_number() over (order by published_at desc, slug asc) as place
                    from content.published_articles
                ) as article
                cross join lateral unnest(article.tags) with ordinality as tag (name, place)
                group by tag.name
                order by count(*) desc, min(article.place * {PlacesAnArticle} + tag.place)
                limit {MaxTags}
                """,
            Read,
            ct);

        return V1.Ok(json => Write(json, rows), MaxAgeSeconds, StaleWhileRevalidateSeconds);
    }

    private static Row Read(DbRow row) => new(row.Text("Name"), row.Int("ArticleCount"));

    /// <summary>
    /// tsr-web: <c>name.toLowerCase().replace(/\s+/g, '-').replace(/[^\w-]/g, '')</c>. Each run of white space becomes one "-", then every character
    /// that is not a Latin letter, a digit, "_" or "-" is dropped: JavaScript's <c>\w</c> knows no other script, so a name in one keeps only its "-".
    /// </summary>
    internal static string Slug(string name) => NotWordOrDash().Replace(JavaScriptWhiteSpace().Replace(name.ToLowerInvariant(), "-"), string.Empty);

    private static void Write(Utf8JsonWriter json, List<Row> rows)
    {
        json.WriteStartArray();
        foreach (var row in rows)
        {
            json.WriteStartObject();
            json.WriteString("name", row.Name);
            json.WriteString("slug", Slug(row.Name));
            json.WriteNumber("articleCount", row.ArticleCount);
            json.WriteEndObject();
        }

        json.WriteEndArray();
    }

    // JavaScript's \s, spelled out: .NET's differs by two characters (it has U+0085 and lacks U+FEFF).
    [GeneratedRegex(@"[\t\n\v\f\r    -     　﻿]+")]
    private static partial Regex JavaScriptWhiteSpace();

    [GeneratedRegex("[^A-Za-z0-9_-]")]
    private static partial Regex NotWordOrDash();
}
