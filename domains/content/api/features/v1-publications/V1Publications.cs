using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Content.Api.Domain;

namespace Tsr.Content.Api.Features.V1Publications;

// Slice: GET /api/v1/publications -> the publications of the publications page, in file order, in the answer shape supported app builds read from today's website (domain/V1.cs).
// Public: no caller, no permission. It reads content.publications, which the refresh fills from pages/tsr-publications.md (an entry with neither link is never copied there).
// A port of tsr-web web/src/app/api/v1/publications/route.ts; that code is the rule, quirks kept:
//   - "file" and "readOnlineUrl" are sent as the file has them (site-relative; the app joins them to its website address). No PDF is read or served here.
//   - a field the file lacks (or has empty) is left out, never null; "downloadOnly" is always sent.
//   - "language" keeps the publications of that whole language, in any case; an empty value is no filter. Nothing else is read from the query.
//   - no paging: every publication is sent, and "pagination" says so (its limit is the total).
// Every value is text of the file sent as JSON text; nothing here is HTML or Markdown.
// Contract: spec/api.yaml. Behaviour: spec/tests/v1-publications.hurl.

internal static class V1PublicationsSlice
{
    private const int MaxAgeSeconds = 3600;

    private const int StaleWhileRevalidateSeconds = 86400;

    /// <summary>Bound on one answer (MUST 2): every entry is in one front matter, which the refresh caps at this many bytes, so no publication is ever cut off.</summary>
    private const int MaxPublications = ContentFiles.MaxFrontMatterBytes;

    /// <summary>One publication, in the order of the answer.</summary>
    internal sealed record Row(string Title, string? Summary, string? Type, string? Size, string? Updated, string? Language, string? File, string? ReadOnlineUrl, bool DownloadOnly);

    public static IEndpointRouteBuilder MapV1Publications(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/api/v1/publications", HandleAsync).WithV1Failures();
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ContentContext db, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<Row>($"""
                select title::text as "Title", summary::text as "Summary", type::text as "Type", size::text as "Size", updated::text as "Updated",
                       language::text as "Language", file::text as "File", read_online_url::text as "ReadOnlineUrl", download_only as "DownloadOnly"
                from content.publications
                order by position
                limit {MaxPublications}
                """)
            .ToListAsync(ct);

        var kept = InLanguage(rows, context.Request.Query["language"].FirstOrDefault());
        return V1.Ok(json => Write(json, kept), MaxAgeSeconds, StaleWhileRevalidateSeconds, new V1.Pagination(kept.Count, kept.Count, Offset: 0, HasMore: false));
    }

    /// <summary>tsr-web: <c>p.language?.toLowerCase() === languageFilter.toLowerCase()</c>, and no filter for an empty value. Compared here, not in SQL, so the case rule is this line's and not a collation's.</summary>
    private static List<Row> InLanguage(List<Row> rows, string? language)
    {
        if (string.IsNullOrEmpty(language))
        {
            return rows;
        }

        return [.. rows.Where(row => string.Equals(row.Language, language, StringComparison.OrdinalIgnoreCase))];
    }

    private static void Write(Utf8JsonWriter json, List<Row> rows)
    {
        json.WriteStartArray();
        foreach (var row in rows)
        {
            json.WriteStartObject();
            json.WriteString("title", row.Title);
            WriteFilled(json, "summary", row.Summary);
            WriteFilled(json, "type", row.Type);
            WriteFilled(json, "size", row.Size);
            WriteFilled(json, "updated", row.Updated);
            WriteFilled(json, "language", row.Language);
            WriteFilled(json, "file", row.File);
            WriteFilled(json, "readOnlineUrl", row.ReadOnlineUrl);
            json.WriteBoolean("downloadOnly", row.DownloadOnly);
            json.WriteEndObject();
        }

        json.WriteEndArray();
    }

    /// <summary>tsr-web's <c>item.x ? String(item.x) : undefined</c>: an absent or empty value is not written.</summary>
    private static void WriteFilled(Utf8JsonWriter json, string name, string? value)
    {
        if (!string.IsNullOrEmpty(value))
        {
            json.WriteString(name, value);
        }
    }
}
