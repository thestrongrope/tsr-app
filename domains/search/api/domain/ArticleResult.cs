using System.Text.Json;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// One article of the answer of <c>GET /api/v1/search</c>, in the website's field order (tsr-web <c>SearchResult</c>, <c>search-service.ts</c>). A field that is absent is left out, as JavaScript leaves out <c>undefined</c>.
/// <see cref="HighlightsJson"/> is Elasticsearch's own <c>highlight</c> object, kept as text and written through as it came.
/// </summary>
internal sealed record ArticleResult(
    long Id,
    string Slug,
    string Title,
    string? Excerpt,
    string PublishedDate,
    string? ModifiedDate,
    string Author,
    IReadOnlyList<string> Categories,
    IReadOnlyList<string> Tags,
    string Language,
    int ReadingTime,
    double Score,
    string? HighlightsJson)
{
    public void Write(Utf8JsonWriter json)
    {
        ArgumentNullException.ThrowIfNull(json);
        json.WriteStartObject();
        json.WriteNumber("id", Id);
        json.WriteString("slug", Slug);
        json.WriteString("title", Title);
        if (Excerpt is not null)
        {
            json.WriteString("excerpt", Excerpt);
        }

        json.WriteString("publishedDate", PublishedDate);
        if (ModifiedDate is not null)
        {
            json.WriteString("modifiedDate", ModifiedDate);
        }

        json.WriteString("author", Author);
        WriteList(json, "categories", Categories);
        WriteList(json, "tags", Tags);
        json.WriteString("language", Language);
        json.WriteNumber("readingTime", ReadingTime);
        json.WriteNumber("score", Score);
        if (HighlightsJson is not null)
        {
            json.WritePropertyName("highlights");
            json.WriteRawValue(HighlightsJson, skipInputValidation: true);
        }

        json.WriteEndObject();
    }

    private static void WriteList(Utf8JsonWriter json, string name, IReadOnlyList<string> values)
    {
        json.WriteStartArray(name);
        foreach (var value in values)
        {
            json.WriteStringValue(value);
        }

        json.WriteEndArray();
    }
}
