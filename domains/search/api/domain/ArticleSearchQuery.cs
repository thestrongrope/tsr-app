using System.Buffers;
using System.Text.Encodings.Web;
using System.Text.Json;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The Elasticsearch request of article search and the reading of its answer: a port of <c>searchArticlesElasticsearch</c> (tsr-web <c>web/src/app/api/lib/search-service.ts</c>), clause for clause and in the same order.
/// The body is written with <see cref="Utf8JsonWriter"/>: the caller's text goes only into string values, never into query syntax (SRCH-Q3), and the answer is read with <see cref="JsonDocument"/>, so nothing here
/// depends on reflection (a native build reads a typed client answer as empty; issue 97 and 101). The index holds no article body (owner decision c, 27 Nov 2026), so the <c>content</c> clauses match nothing, as on the live site today.
/// The status filter is <c>publish</c>, which is what the feed writes for every published article.
/// </summary>
internal static class ArticleSearchQuery
{
    public const string IndexName = "tsr-articles";

    /// <summary>The longest text a search may carry. tsr-web has no cap (no file of its search route or <c>api-response.ts</c> limits <c>q</c>); this one keeps a request from building a body and a query of any size.</summary>
    public const int MaxQueryLength = 200;

    /// <summary>Elasticsearch's own <c>index.max_result_window</c>: a page that ends past it is refused by the engine, and would make the database fallback skip that many rows.</summary>
    public const int MaxResultWindow = 10000;

    /// <summary>The longest category the filter takes. A category is a slug the content files name; no charset is imposed (it may be in any script), but a megabyte of it is not one.</summary>
    public const int MaxCategoryLength = 100;

    public static string? ValidateCategory(string? category) =>
        category is null || category.Length <= MaxCategoryLength ? null : "Category too long: at most 100 characters";

    /// <summary>The reason a request must be refused with a 400, or null. Checked before any engine or database call.</summary>
    public static string? Validate(string q, int limit, int offset)
    {
        ArgumentNullException.ThrowIfNull(q);
        if (q.Length > MaxQueryLength)
        {
            return "Query too long: at most 200 characters";
        }

        return (long)offset + limit > MaxResultWindow ? "Result window too large: offset plus limit must not exceed 10000" : null;
    }

    private static readonly JsonWriterOptions Options = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    public static string Body(string q, string? category, int limit, int offset)
    {
        ArgumentNullException.ThrowIfNull(q);
        var buffer = new ArrayBufferWriter<byte>();
        using (var json = new Utf8JsonWriter(buffer, Options))
        {
            json.WriteStartObject();
            WriteQuery(json, q, category);
            json.WriteNumber("size", limit);
            json.WriteNumber("from", offset);
            json.WriteStartObject("_source");
            WriteStrings(json, "excludes", ["content_embedding", "title_embedding", "content"]);
            json.WriteEndObject();
            WriteHighlight(json);
            json.WriteEndObject();
        }

        return System.Text.Encoding.UTF8.GetString(buffer.WrittenSpan);
    }

    /// <summary>The hits of an answer, in order. An answer that cannot be read is "the engine failed", never an empty list.</summary>
    /// <exception cref="SearchUnavailableException">The text is not an Elasticsearch answer, or a hit has no slug or title.</exception>
    public static IReadOnlyList<ArticleResult> ReadHits(string answer)
    {
        try
        {
            using var document = JsonDocument.Parse(answer);
            if (!document.RootElement.TryGetProperty("hits", out var outer) || !outer.TryGetProperty("hits", out var hits) || hits.ValueKind != JsonValueKind.Array)
            {
                throw new SearchUnavailableException("Elasticsearch answered without hits");
            }

            return [.. hits.EnumerateArray().Select(ReadHit)];
        }
        catch (Exception exception) when (exception is JsonException or InvalidOperationException or KeyNotFoundException)
        {
            throw new SearchUnavailableException("Elasticsearch answered with a body that is not a search answer");
        }
    }

    private static ArticleResult ReadHit(JsonElement hit)
    {
        var source = hit.GetProperty("_source");
        var slug = Text(source, "slug") ?? throw new SearchUnavailableException("Elasticsearch listed an article without a slug");
        var title = Text(source, "title") ?? throw new SearchUnavailableException("Elasticsearch listed an article without a title");
        var score = hit.TryGetProperty("_score", out var s) && s.ValueKind == JsonValueKind.Number ? s.GetDouble() : 0;
        var highlight = hit.TryGetProperty("highlight", out var h) && h.ValueKind == JsonValueKind.Object ? h.GetRawText() : null;
        return new ArticleResult(
            0,
            slug,
            title,
            Text(source, "excerpt"),
            Text(source, "publishedDate") is { Length: > 0 } published ? published : string.Empty,
            Text(source, "modifiedDate"),
            Text(source, "author") is { Length: > 0 } author ? author : "admin",
            Strings(source, "categories"),
            Strings(source, "tags"),
            Text(source, "language") is { Length: > 0 } language ? language : "en",
            1,
            score,
            highlight);
    }

    private static string? Text(JsonElement source, string name) =>
        source.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;

    private static List<string> Strings(JsonElement source, string name) =>
        source.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Array
            ? [.. value.EnumerateArray().Where(item => item.ValueKind == JsonValueKind.String).Select(item => item.GetString()!)]
            : [];

    private static void WriteQuery(Utf8JsonWriter json, string q, string? category)
    {
        json.WriteStartObject("query");
        json.WriteStartObject("bool");
        json.WriteStartArray("should");
        WritePhrase(json, "title", q, 15);
        WritePhrase(json, "content", q, 5);
        WriteConcepts(json, q);
        WriteCrossFields(json, q);
        WriteExpanded(json, q);
        json.WriteEndArray();
        json.WriteNumber("minimum_should_match", 1);
        WriteFilter(json, category);
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

    // Every concept must match; with no concept left (a text of stopwords) the list is empty and the clause matches every article, as on the website.
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
            WriteStrings(json, "fields", ["title^3", "excerpt"]);
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
        WriteStrings(json, "fields", ["title^4", "excerpt^2", "content", "tags^1.5"]);
        json.WriteString("type", "cross_fields");
        json.WriteString("operator", "or");
        json.WriteEndObject();
        json.WriteEndObject();
    }

    private static void WriteExpanded(Utf8JsonWriter json, string q)
    {
        json.WriteStartObject();
        json.WriteStartObject("multi_match");
        json.WriteString("query", QueryExpansion.Expand(q));
        WriteStrings(json, "fields", ["title^2", "excerpt^1.5", "content", "tags"]);
        json.WriteString("type", "best_fields");
        json.WriteString("fuzziness", "AUTO");
        json.WriteEndObject();
        json.WriteEndObject();
    }

    private static void WriteFilter(Utf8JsonWriter json, string? category)
    {
        json.WriteStartArray("filter");
        json.WriteStartObject();
        json.WriteStartObject("term");
        json.WriteString("status", "publish");
        json.WriteEndObject();
        json.WriteEndObject();
        if (!string.IsNullOrEmpty(category))
        {
            json.WriteStartObject();
            json.WriteStartObject("terms");
            WriteStrings(json, "categories", [category]);
            json.WriteEndObject();
            json.WriteEndObject();
        }

        json.WriteEndArray();
    }

    private static void WriteHighlight(Utf8JsonWriter json)
    {
        json.WriteStartObject("highlight");
        WriteStrings(json, "pre_tags", ["<em>"]);
        WriteStrings(json, "post_tags", ["</em>"]);
        json.WriteString("encoder", "html");
        json.WriteStartObject("fields");
        json.WriteStartObject("title");
        json.WriteNumber("number_of_fragments", 0);
        json.WriteEndObject();
        json.WriteStartObject("excerpt");
        json.WriteNumber("number_of_fragments", 1);
        json.WriteNumber("fragment_size", 200);
        json.WriteEndObject();
        json.WriteStartObject("content");
        json.WriteNumber("number_of_fragments", 3);
        json.WriteNumber("fragment_size", 150);
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
