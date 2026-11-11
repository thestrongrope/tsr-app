using System.Text.Json;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP <c>SessionsModel::getSyllabusTopics</c>: the topic catalogue (data/syllabus_topics.json, embedded: lesson names only, no member data), keyed by upper-case level name; only MIQDAD has one.
/// A level never gets another level's catalogue.
/// </summary>
internal static class SyllabusCatalogue
{
    private static readonly Lazy<JsonElement> Catalogue = new(Load);

    /// <summary>The catalogue of the level (the name trimmed and upper-cased as PHP does), or null when the level has none.</summary>
    public static JsonElement? For(string levelName)
    {
        var key = PhpText.ToUpperAscii(PhpText.Trim(levelName));
        return Catalogue.Value.TryGetProperty(key, out var topics) ? topics : null;
    }

    private static JsonElement Load()
    {
        using var stream = typeof(SyllabusCatalogue).Assembly.GetManifestResourceStream("syllabus_topics.json")
            ?? throw new InvalidOperationException("The embedded syllabus_topics.json is missing");
        return JsonDocument.Parse(stream).RootElement.Clone();
    }
}
