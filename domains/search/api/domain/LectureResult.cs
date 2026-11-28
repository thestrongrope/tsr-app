using System.Globalization;
using System.Text.Json;

namespace Tsr.Search.Api.Domain;

/// <summary>A chapter that matched the text: the chapter as the index holds it, and the highlights of its title and summary (Elasticsearch's own <c>inner_hits</c> highlight), each kept as the text of a JSON array. A part that is absent is null.</summary>
internal sealed record MatchedChapter(string SourceJson, bool Highlighted, string? TitleHighlightJson, string? SummaryHighlightJson);

/// <summary>One page of an Elasticsearch lecture answer: the lectures in answer order and the hit total of the whole search (not of the page).</summary>
internal sealed record LecturePage(IReadOnlyList<LectureResult> Hits, long Total);

/// <summary>
/// One lecture of the answer of <c>GET /api/v1/lectures/search</c>, in the website's field order (tsr-web <c>toResult</c>, <c>lectures-search-service.ts</c>). A field that is absent is left out, as JavaScript leaves out <c>undefined</c>.
/// <see cref="ChaptersJson"/> and <see cref="HighlightsJson"/> are kept as the text Elasticsearch sent and written through as they came; <see cref="DurationSecJson"/> is the number as written.
/// </summary>
internal sealed record LectureResult(
    string Slug,
    string Title,
    string Url,
    string? Excerpt,
    IReadOnlyList<string> Tags,
    string Language,
    string? PublishedDate,
    string? DurationSecJson,
    string ChaptersJson,
    IReadOnlyList<MatchedChapter> MatchedChapters,
    IReadOnlyList<string> KeyPoints,
    double Score,
    string? HighlightsJson)
{
    /// <summary>Reads an answer to a search body. An answer that cannot be read is "the engine failed", never an empty page.</summary>
    /// <exception cref="SearchUnavailableException">The text is not an Elasticsearch search answer, or a hit has no slug, title or address.</exception>
    public static LecturePage ReadPage(string answer)
    {
        try
        {
            using var document = JsonDocument.Parse(answer);
            if (!document.RootElement.TryGetProperty("hits", out var outer) || !outer.TryGetProperty("hits", out var hits) || hits.ValueKind != JsonValueKind.Array)
            {
                throw new SearchUnavailableException("Elasticsearch answered without hits");
            }

            var results = hits.EnumerateArray().Select(Read).ToList();
            return new LecturePage(results, Total(outer, results.Count));
        }
        catch (Exception exception) when (exception is JsonException or InvalidOperationException or KeyNotFoundException)
        {
            throw new SearchUnavailableException("Elasticsearch answered with a body that is not a search answer");
        }
    }

    /// <summary>The browse form of a result (tsr-web <c>browseLectures</c>): score 0, no matched chapters and no highlights.</summary>
    public LectureResult ForBrowse() => this with { MatchedChapters = [], Score = 0, HighlightsJson = null };

    public void Write(Utf8JsonWriter json)
    {
        ArgumentNullException.ThrowIfNull(json);
        json.WriteStartObject();
        json.WriteString("slug", Slug);
        json.WriteString("title", Title);
        json.WriteString("url", Url);
        if (Excerpt is not null)
        {
            json.WriteString("excerpt", Excerpt);
        }

        WriteStrings(json, "tags", Tags);
        json.WriteString("language", Language);
        if (PublishedDate is not null)
        {
            json.WriteString("publishedDate", PublishedDate);
        }

        if (DurationSecJson is not null)
        {
            json.WritePropertyName("durationSec");
            json.WriteRawValue(DurationSecJson, skipInputValidation: true);
        }

        json.WritePropertyName("chapters");
        json.WriteRawValue(ChaptersJson, skipInputValidation: true);
        json.WriteStartArray("matchedChapters");
        foreach (var chapter in MatchedChapters)
        {
            WriteMatched(json, chapter);
        }

        json.WriteEndArray();
        WriteStrings(json, "key_points", KeyPoints);
        json.WriteString("thumbnail", "https://i.ytimg.com/vi/" + Slug + "/mqdefault.jpg");
        json.WriteNumber("score", Score);
        if (HighlightsJson is not null)
        {
            json.WritePropertyName("highlights");
            json.WriteRawValue(HighlightsJson, skipInputValidation: true);
        }

        json.WriteEndObject();
    }

    private static void WriteMatched(Utf8JsonWriter json, MatchedChapter chapter)
    {
        using var source = JsonDocument.Parse(chapter.SourceJson);
        json.WriteStartObject();
        foreach (var property in source.RootElement.EnumerateObject())
        {
            property.WriteTo(json);
        }

        if (chapter.Highlighted)
        {
            json.WriteStartObject("highlight");
            if (chapter.TitleHighlightJson is not null)
            {
                json.WritePropertyName("title");
                json.WriteRawValue(chapter.TitleHighlightJson, skipInputValidation: true);
            }

            if (chapter.SummaryHighlightJson is not null)
            {
                json.WritePropertyName("summary");
                json.WriteRawValue(chapter.SummaryHighlightJson, skipInputValidation: true);
            }

            json.WriteEndObject();
        }

        json.WriteEndObject();
    }

    private static void WriteStrings(Utf8JsonWriter json, string name, IReadOnlyList<string> values)
    {
        json.WriteStartArray(name);
        foreach (var value in values)
        {
            json.WriteStringValue(value);
        }

        json.WriteEndArray();
    }

    private static long Total(JsonElement outer, int fallback)
    {
        if (!outer.TryGetProperty("total", out var total))
        {
            return fallback;
        }

        return total.ValueKind switch
        {
            JsonValueKind.Number => total.GetInt64(),
            JsonValueKind.Object when total.TryGetProperty("value", out var value) && value.ValueKind == JsonValueKind.Number => value.GetInt64(),
            _ => fallback,
        };
    }

    private static LectureResult Read(JsonElement hit)
    {
        var source = hit.GetProperty("_source");
        var slug = Text(source, "slug") ?? throw new SearchUnavailableException("Elasticsearch listed a lecture without a slug");
        return new LectureResult(
            slug,
            Text(source, "title") ?? throw new SearchUnavailableException("Elasticsearch listed a lecture without a title"),
            Text(source, "url") ?? throw new SearchUnavailableException("Elasticsearch listed a lecture without an address"),
            Text(source, "excerpt"),
            Strings(source, "tags"),
            Text(source, "language") is { Length: > 0 } language ? language : "en",
            Text(source, "publishedDate"),
            source.TryGetProperty("durationSec", out var duration) && duration.ValueKind == JsonValueKind.Number ? duration.GetRawText() : null,
            source.TryGetProperty("chapters", out var chapters) && chapters.ValueKind == JsonValueKind.Array ? chapters.GetRawText() : "[]",
            ReadMatched(hit),
            Strings(source, "key_points"),
            hit.TryGetProperty("_score", out var score) && score.ValueKind == JsonValueKind.Number ? score.GetDouble() : 0,
            hit.TryGetProperty("highlight", out var highlight) && highlight.ValueKind == JsonValueKind.Object ? highlight.GetRawText() : null);
    }

    private static List<MatchedChapter> ReadMatched(JsonElement hit)
    {
        if (!hit.TryGetProperty("inner_hits", out var inner) || !inner.TryGetProperty("matched_chapters", out var matched)
            || !matched.TryGetProperty("hits", out var outer) || !outer.TryGetProperty("hits", out var hits) || hits.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return [.. hits.EnumerateArray().Select(ReadChapter)];
    }

    private static MatchedChapter ReadChapter(JsonElement hit)
    {
        var source = hit.GetProperty("_source").GetRawText();
        if (!hit.TryGetProperty("highlight", out var highlight) || highlight.ValueKind != JsonValueKind.Object)
        {
            return new MatchedChapter(source, false, null, null);
        }

        return new MatchedChapter(
            source,
            true,
            highlight.TryGetProperty("chapters.title", out var title) ? title.GetRawText() : null,
            highlight.TryGetProperty("chapters.summary", out var summary) ? summary.GetRawText() : null);
    }

    private static string? Text(JsonElement source, string name) =>
        source.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;

    private static List<string> Strings(JsonElement source, string name) =>
        source.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Array
            ? [.. value.EnumerateArray().Where(item => item.ValueKind == JsonValueKind.String).Select(item => item.GetString()!)]
            : [];
}
