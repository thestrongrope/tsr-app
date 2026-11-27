using System.Buffers;
using System.Text.Encodings.Web;
using System.Text.Json;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The highlights of a database fallback result, by the website's own rule for its fallback (tsr-web <c>extractHighlights</c>, <c>search-service.ts</c>): for each of the title, the excerpt and the body (sent as <c>content</c>), at most
/// 3 matches, each with 30 characters of context before it and 29 after it, "..." where the text is cut, and the match wrapped in <c>&lt;em&gt;</c>. A match is a word of the search, found without regard to case.
/// Differences from the website: the match is found by position, not as the first equal text of the snippet; Fuse's fuzzy matches are not found.
/// </summary>
internal static class ArticleHighlights
{
    private const int MaxSnippets = 3;

    private const int Context = 30;

    private static readonly JsonWriterOptions Options = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    /// <summary>The <c>highlights</c> object as JSON text, or null when no field has a match.</summary>
    public static string? Build(IReadOnlyList<string> words, string title, string? excerpt, string body)
    {
        ArgumentNullException.ThrowIfNull(words);
        var fields = new (string Name, List<string> Snippets)[]
        {
            ("title", Snippets(words, title)),
            ("excerpt", Snippets(words, excerpt ?? string.Empty)),
            ("content", Snippets(words, body)),
        };
        if (fields.All(field => field.Snippets.Count == 0))
        {
            return null;
        }

        var buffer = new ArrayBufferWriter<byte>();
        using (var json = new Utf8JsonWriter(buffer, Options))
        {
            json.WriteStartObject();
            foreach (var (name, snippets) in fields.Where(field => field.Snippets.Count > 0))
            {
                json.WriteStartArray(name);
                foreach (var snippet in snippets)
                {
                    json.WriteStringValue(snippet);
                }

                json.WriteEndArray();
            }

            json.WriteEndObject();
        }

        return System.Text.Encoding.UTF8.GetString(buffer.WrittenSpan);
    }

    private static List<string> Snippets(IReadOnlyList<string> words, string text)
    {
        var matches = new List<(int Start, int Length)>();
        foreach (var word in words)
        {
            for (var at = text.IndexOf(word, StringComparison.OrdinalIgnoreCase); at >= 0; at = text.IndexOf(word, at + word.Length, StringComparison.OrdinalIgnoreCase))
            {
                matches.Add((at, word.Length));            }
        }

        var snippets = new List<string>(MaxSnippets);
        var lastEnd = -1;
        foreach (var (start, length) in matches.OrderBy(m => m.Start).ThenByDescending(m => m.Length))
        {
            if (start < lastEnd)
            {
                continue;
            }

            lastEnd = start + length;
            snippets.Add(Snippet(text, start, length));
            if (snippets.Count == MaxSnippets)
            {
                break;
            }
        }

        return snippets;
    }

    private static string Snippet(string text, int start, int length)
    {
        var end = start + length;
        var from = Math.Max(0, start - Context);
        var to = Math.Min(text.Length, end + Context - 1);
        return (from > 0 ? "..." : string.Empty) + text[from..start] + "<em>" + text[start..end] + "</em>" + text[end..to] + (to < text.Length ? "..." : string.Empty);
    }
}
