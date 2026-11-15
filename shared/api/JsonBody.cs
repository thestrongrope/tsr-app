using System.Text.Json;

namespace Tsr.Shared.Api;

/// <summary>
/// A request body as PHP's <c>api_body()</c> reads it: an empty body is an empty array, a JSON object is its fields, a list has
/// no named fields, anything else is "Invalid JSON body". Presence is <c>array_key_exists</c> (an explicit null counts); a repeated
/// key keeps its first position and its last value; a lone surrogate escape anywhere makes PHP refuse the whole document.
/// </summary>
public sealed class JsonBody
{
    private const string InvalidJson = "Invalid JSON body";

    private static readonly JsonDocumentOptions Options = new() { MaxDepth = 512, AllowDuplicateProperties = true };

    private readonly Dictionary<string, JsonElement> _fields;

    private JsonBody(Dictionary<string, JsonElement> fields) => _fields = fields;

    public static Result<JsonBody> Parse(ReadOnlySpan<byte> utf8)
    {
        if (utf8.IsEmpty)
        {
            return Result.Ok(new JsonBody([]));
        }

        try
        {
            using var document = JsonDocument.Parse(utf8.ToArray(), Options);
            RequireValidStrings(utf8);
            return document.RootElement.ValueKind switch
            {
                JsonValueKind.Object => Result.Ok(new JsonBody(Entries(document.RootElement).ToDictionary(e => e.Key, e => e.Value.Clone(), StringComparer.Ordinal))),
                JsonValueKind.Array => Result.Ok(new JsonBody([])),
                _ => Result.Fail<JsonBody>(InvalidJson),
            };
        }
        catch (Exception e) when (e is JsonException or InvalidOperationException or ArgumentException)
        {
            return Result.Fail<JsonBody>(InvalidJson);
        }
    }

    /// <summary>array_key_exists: true for an explicit null too.</summary>
    public bool Has(string field) => _fields.ContainsKey(field);

    /// <summary>The field's value; <c>default</c> (kind Undefined) when it is missing.</summary>
    public JsonElement Get(string field) => _fields.TryGetValue(field, out var value) ? value : default;

    /// <summary>The key and value pairs of a decoded array or object as PHP iterates them; a scalar has none.</summary>
    public static IReadOnlyList<KeyValuePair<string, JsonElement>> Entries(JsonElement container)
    {
        var entries = new List<KeyValuePair<string, JsonElement>>();
        if (container.ValueKind == JsonValueKind.Array)
        {
            var position = 0;
            foreach (var item in container.EnumerateArray())
            {
                entries.Add(new(position.ToString(System.Globalization.CultureInfo.InvariantCulture), item));
                position++;
            }

            return entries;
        }

        if (container.ValueKind != JsonValueKind.Object)
        {
            return entries;
        }

        var index = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var property in container.EnumerateObject())
        {
            if (index.TryGetValue(property.Name, out var at))
            {
                entries[at] = new(property.Name, property.Value);
                continue;
            }

            index[property.Name] = entries.Count;
            entries.Add(new(property.Name, property.Value));
        }

        return entries;
    }

    // .NET parses a lone surrogate escape and only throws when the string is read; PHP's decoder refuses the document.
    private static void RequireValidStrings(ReadOnlySpan<byte> utf8)
    {
        var reader = new Utf8JsonReader(utf8, new JsonReaderOptions { MaxDepth = Options.MaxDepth });
        while (reader.Read())
        {
            if (reader.TokenType is JsonTokenType.String or JsonTokenType.PropertyName)
            {
                _ = reader.GetString();
            }
        }
    }
}
