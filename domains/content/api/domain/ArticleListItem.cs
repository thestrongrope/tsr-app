using System.Text.Json;

namespace Tsr.Content.Api.Domain;

/// <summary>
/// One published article as a list shows it: tsr-web's <c>transformToListItem</c> (<c>web/src/app/api/lib/article-service.ts</c>).
/// Sent by the list, as each related article of one article, and as the first fields of the article itself.
/// tsr-web's <c>featuredImage</c> is not sent: no content file has one and no column stores it.
/// </summary>
internal sealed record ArticleListItem(
    string Slug,
    int? LegacyId,
    string Title,
    string? Excerpt,
    string PublishedDateText,
    string? ModifiedDateText,
    string Author,
    string[] Categories,
    string[] Tags,
    string Language)
{
    /// <summary>
    /// The reading time a list sends. A kept quirk of today's website: it computes the minutes from a body the list never loads, so every list item says 1;
    /// only the article route sends the real number.
    /// </summary>
    public const int ListReadingMinutes = 1;

    /// <summary>The item as one JSON object.</summary>
    public void Write(Utf8JsonWriter json)
    {
        json.WriteStartObject();
        WriteFields(json, ListReadingMinutes);
        json.WriteEndObject();
    }

    /// <summary>The fields in tsr-web's order, inside an object the caller has opened. A field the file does not have is left out.</summary>
    public void WriteFields(Utf8JsonWriter json, int readingMinutes)
    {
        json.WriteNumber("id", LegacyId ?? 0);
        json.WriteString("slug", Slug);
        json.WriteString("title", Title);
        if (Excerpt is not null)
        {
            json.WriteString("excerpt", Excerpt);
        }

        json.WriteString("publishedDate", PublishedDateText);
        if (ModifiedDateText is not null)
        {
            json.WriteString("modifiedDate", ModifiedDateText);
        }

        json.WriteString("author", Author);
        WriteTexts(json, "categories", Categories);
        WriteTexts(json, "tags", Tags);
        json.WriteString("language", Language);
        json.WriteNumber("readingTime", readingMinutes);
    }

    private static void WriteTexts(Utf8JsonWriter json, string name, string[] texts)
    {
        json.WriteStartArray(name);
        foreach (var text in texts)
        {
            json.WriteStringValue(text);
        }

        json.WriteEndArray();
    }
}
