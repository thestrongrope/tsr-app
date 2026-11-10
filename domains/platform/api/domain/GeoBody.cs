using System.Text.Json;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// The top-level string fields of a geo request body, read the way PHP's api_body() does: an empty
/// body is an empty array, a JSON object or list is fine (a list has no fields), anything else is
/// "Invalid JSON body". A field that is not a JSON string is absent; when a key repeats the last value wins.
/// </summary>
internal sealed class GeoBody
{
    private const string InvalidJson = "Invalid JSON body";

    private readonly Dictionary<string, string?> fields;

    private GeoBody(Dictionary<string, string?> fields) => this.fields = fields;

    public static Result<GeoBody> Parse(ReadOnlySpan<byte> utf8)
    {
        if (utf8.IsEmpty)
        {
            return Result.Ok(new GeoBody([]));
        }

        try
        {
            using var document = PhpJson.Parse(utf8.ToArray());
            return document.RootElement.ValueKind switch
            {
                JsonValueKind.Object => Result.Ok(new GeoBody(ReadFields(document.RootElement))),
                JsonValueKind.Array => Result.Ok(new GeoBody([])),
                _ => Result.Fail<GeoBody>(InvalidJson),
            };
        }
        catch (Exception e) when (e is JsonException or InvalidOperationException)
        {
            // InvalidOperationException: a field's GetString on a lone surrogate escape (PhpJson.Parse already refuses those).
            return Result.Fail<GeoBody>(InvalidJson);
        }
    }

    /// <summary>The field's value untrimmed, or null when it is missing or not a string.</summary>
    public string? Text(string field) => fields.TryGetValue(field, out var value) ? value : null;

    private static Dictionary<string, string?> ReadFields(JsonElement root)
    {
        var fields = new Dictionary<string, string?>(StringComparer.Ordinal);
        foreach (var property in root.EnumerateObject())
        {
            fields[property.Name] = property.Value.ValueKind == JsonValueKind.String ? property.Value.GetString() : null;
        }

        return fields;
    }
}
