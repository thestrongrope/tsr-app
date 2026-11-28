using System.Buffers;
using System.Text.Encodings.Web;
using System.Text.Json;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The Elasticsearch requests of lecture search, ported from tsr-web <c>web/src/app/api/lib/lectures-search-service.ts</c>, clause for clause and in the same key order: the keyword body (strict, and the fuzzy retry), the browse body and the kNN body.
/// Written with <see cref="Utf8JsonWriter"/>, so the caller's text (the search text and the language) goes only into JSON string values (SRCH-Q3), and nothing here uses reflection (plan 3.2).
/// The helpers of <see cref="QueryExpansion"/> are the same as the article search's (tsr-web keeps a copy of them in this file). One deliberate difference (plan 3.10): every highlight asks for HTML-encoded text (<c>"encoder":"html"</c>), as article search does.
/// </summary>
internal static class LectureSearchQuery
{
    public const string IndexName = "tsr-lectures";

    /// <summary>The language filter: the data holds codes such as hi, en and ar, so 10 letters and hyphens at most; anything else is refused with a 400 before any engine call.</summary>
    public static string? ValidateLanguage(string? language) =>
        string.IsNullOrEmpty(language) || (language.Length <= 10 && language.All(c => char.IsAsciiLetter(c) || c == '-'))
            ? null
            : "Invalid language: at most 10 letters and hyphens";

    /// <summary>The candidate pool of the meaning layer: the keyword search asks for this many from the start, and the kNN search returns this many (tsr-web <c>CANDIDATE_POOL</c>).</summary>
    public const int CandidatePool = 50;

    private const int NumCandidates = 200;

    private static readonly JsonWriterOptions Options = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    /// <summary>The keyword search. <paramref name="semantic"/>: the meaning layer is on, so the page is cut from a pool of 50 after fusion. <paramref name="fuzzy"/>: the second stage, for a text the strict stage found fewer than 3 lectures for.</summary>
    public static string Keyword(string q, string? language, int limit, int offset, bool semantic, bool fuzzy)
    {
        ArgumentNullException.ThrowIfNull(q);
        return Write(json =>
        {
            json.WriteStartObject();
            json.WriteNumber("size", semantic ? CandidatePool : limit);
            json.WriteNumber("from", semantic ? 0 : offset);
            json.WriteBoolean("track_total_hits", value: true);
            WriteSourceExcludes(json);
            WriteHighlight(json);
            WriteQuery(json, q, language, fuzzy);
            json.WriteEndObject();
        });
    }

    /// <summary>No text: every lecture, newest first (those without a date last), a page of it.</summary>
    public static string Browse(string? language, int limit, int offset) =>
        Write(json =>
        {
            json.WriteStartObject();
            json.WriteStartObject("query");
            json.WriteStartObject("bool");
            json.WriteStartArray("must");
            json.WriteStartObject();
            json.WriteStartObject("match_all");
            json.WriteEndObject();
            json.WriteEndObject();
            json.WriteEndArray();
            WriteFilter(json, language);
            json.WriteEndObject();
            json.WriteEndObject();
            json.WriteStartArray("sort");
            json.WriteStartObject();
            json.WriteStartObject("publishedDate");
            json.WriteString("order", "desc");
            json.WriteString("missing", "_last");
            json.WriteEndObject();
            json.WriteEndObject();
            json.WriteEndArray();
            json.WriteNumber("size", limit);
            json.WriteNumber("from", offset);
            json.WriteBoolean("track_total_hits", value: true);
            WriteSourceExcludes(json);
            json.WriteEndObject();
        });

    /// <summary>The meaning half: the 50 nearest lectures to the query vector, with the same language filter as the keyword half (without it the filter would quietly be ignored here).</summary>
    public static string Knn(float[] vector, string? language)
    {
        ArgumentNullException.ThrowIfNull(vector);
        return Write(json =>
        {
            json.WriteStartObject();
            json.WriteStartObject("knn");
            json.WriteString("field", "embedding");
            json.WriteStartArray("query_vector");
            foreach (var value in vector)
            {
                json.WriteNumberValue(value);
            }

            json.WriteEndArray();
            json.WriteNumber("k", CandidatePool);
            json.WriteNumber("num_candidates", NumCandidates);
            if (!string.IsNullOrEmpty(language))
            {
                WriteFilter(json, language);
            }

            json.WriteEndObject();
            json.WriteNumber("size", CandidatePool);
            WriteSourceExcludes(json);
            json.WriteEndObject();
        });
    }

    private static string Write(Action<Utf8JsonWriter> write)
    {
        var buffer = new ArrayBufferWriter<byte>();
        using (var json = new Utf8JsonWriter(buffer, Options))
        {
            write(json);
        }

        return System.Text.Encoding.UTF8.GetString(buffer.WrittenSpan);
    }

    private static void WriteSourceExcludes(Utf8JsonWriter json)
    {
        json.WriteStartObject("_source");
        WriteStrings(json, "excludes", ["content", "embedding"]);
        json.WriteEndObject();
    }

    private static void WriteFilter(Utf8JsonWriter json, string? language)
    {
        json.WriteStartArray("filter");
        if (!string.IsNullOrEmpty(language))
        {
            json.WriteStartObject();
            json.WriteStartObject("term");
            json.WriteString("language", language);
            json.WriteEndObject();
            json.WriteEndObject();
        }

        json.WriteEndArray();
    }

    private static void WriteHighlight(Utf8JsonWriter json)
    {
        json.WriteStartObject("highlight");
        WriteTags(json);
        json.WriteStartObject("fields");
        WriteField(json, "title", 0, null);
        WriteField(json, "excerpt", 1, 200);
        WriteField(json, "content", 2, 150);
        WriteField(json, "search_phrases", 2, 120);
        WriteField(json, "key_points", 2, 150);
        json.WriteEndObject();
        json.WriteEndObject();
    }

    private static void WriteTags(Utf8JsonWriter json)
    {
        WriteStrings(json, "pre_tags", ["<em>"]);
        WriteStrings(json, "post_tags", ["</em>"]);
        json.WriteString("encoder", "html");
    }

    private static void WriteField(Utf8JsonWriter json, string name, int fragments, int? size)
    {
        json.WriteStartObject(name);
        json.WriteNumber("number_of_fragments", fragments);
        if (size is { } fragmentSize)
        {
            json.WriteNumber("fragment_size", fragmentSize);
        }

        json.WriteEndObject();
    }

    private static void WriteQuery(Utf8JsonWriter json, string q, string? language, bool fuzzy)
    {
        var expanded = QueryExpansion.Expand(q);
        json.WriteStartObject("query");
        json.WriteStartObject("bool");
        json.WriteStartArray("should");
        WritePhrase(json, "title", q, 15);
        WritePhrase(json, "content", q, 5);
        WriteConcepts(json, q);
        WriteCrossFields(json, q);
        WriteExpanded(json, expanded, fuzzy);
        WriteChapters(json, expanded, fuzzy);
        json.WriteEndArray();
        json.WriteNumber("minimum_should_match", 1);
        WriteFilter(json, language);
        json.WriteEndObject();
        json.WriteEndObject();
    }

    private static void WritePhrase(Utf8JsonWriter json, string field, string q, int boost)
    {
        json.WriteStartObject();
        json.WriteStartObject("match_phrase");
        json.WriteStartObject(field);
        json.WriteString("query", q);
        json.WriteNumber("boost", boost);
        json.WriteNumber("slop", 3);
        json.WriteEndObject();
        json.WriteEndObject();
        json.WriteEndObject();
    }

    // Every concept must match; with none left (a text of stopwords) the list is empty and the clause matches every lecture, as on the website.
    private static void WriteConcepts(Utf8JsonWriter json, string q)
    {
        json.WriteStartObject();
        json.WriteStartObject("bool");
        json.WriteStartArray("must");
        foreach (var term in QueryExpansion.ExtractTerms(q))
        {
            json.WriteStartObject();
            json.WriteStartObject("multi_match");
            json.WriteString("query", QueryExpansion.TermQuery(term));
            WriteStrings(json, "fields", ["title^3", "excerpt", "search_phrases^2"]);
            json.WriteString("type", "best_fields");
            json.WriteEndObject();
            json.WriteEndObject();
        }

        json.WriteEndArray();
        json.WriteNumber("boost", 30);
        json.WriteEndObject();
        json.WriteEndObject();
    }

    private static void WriteCrossFields(Utf8JsonWriter json, string q)
    {
        json.WriteStartObject();
        json.WriteStartObject("multi_match");
        json.WriteString("query", q);
        WriteStrings(json, "fields", ["title^4", "excerpt^2", "search_phrases^3", "key_points^1.5", "content", "tags^1.5"]);
        json.WriteString("type", "cross_fields");
        json.WriteString("operator", "or");
        json.WriteEndObject();
        json.WriteEndObject();
    }

    // The fuzzy stage is confined to content, whose length keeps a fuzzy hit from being score-inflated the way short fields are (tsr-web's comment).
    private static void WriteExpanded(Utf8JsonWriter json, string expanded, bool fuzzy)
    {
        json.WriteStartObject();
        json.WriteStartObject("multi_match");
        json.WriteString("query", expanded);
        WriteStrings(json, "fields", fuzzy ? ["content"] : ["title^2", "excerpt^1.5", "search_phrases^2", "content", "tags"]);
        json.WriteString("type", "best_fields");
        if (fuzzy)
        {
            json.WriteString("fuzziness", "AUTO");
        }

        json.WriteEndObject();
        json.WriteEndObject();
    }

    // The video scores by its best chapter (score_mode max); the matching chapters come back through inner_hits.
    private static void WriteChapters(Utf8JsonWriter json, string expanded, bool fuzzy)
    {
        json.WriteStartObject();
        json.WriteStartObject("nested");
        json.WriteString("path", "chapters");
        json.WriteStartObject("query");
        json.WriteStartObject("multi_match");
        json.WriteString("query", expanded);
        WriteStrings(json, "fields", ["chapters.title^2", "chapters.summary"]);
        json.WriteString("type", "best_fields");
        if (fuzzy)
        {
            json.WriteString("fuzziness", "AUTO");
        }

        json.WriteEndObject();
        json.WriteEndObject();
        json.WriteString("score_mode", "max");
        json.WriteNumber("boost", 8);
        json.WriteStartObject("inner_hits");
        json.WriteString("name", "matched_chapters");
        json.WriteNumber("size", 3);
        WriteStrings(json, "_source", ["chapters.start_sec", "chapters.title", "chapters.summary", "chapters.url"]);
        json.WriteStartObject("highlight");
        WriteTags(json);
        json.WriteStartObject("fields");
        WriteField(json, "chapters.title", 0, null);
        WriteField(json, "chapters.summary", 1, 160);
        json.WriteEndObject();
        json.WriteEndObject();
        json.WriteEndObject();
        json.WriteEndObject();
        json.WriteEndObject();
    }

    private static void WriteStrings(Utf8JsonWriter json, string name, string[] values)
    {
        json.WriteStartArray(name);
        foreach (var value in values)
        {
            json.WriteStringValue(value);
        }

        json.WriteEndArray();
    }
}
