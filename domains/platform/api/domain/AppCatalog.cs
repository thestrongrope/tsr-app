using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// The app-version catalog, read the way tsr-account's routes/app_version.php reads it: every
/// problem is logged and answered with something permissive, never an error, so a lost or
/// half-edited file cannot lock the app's users out. Shared by GET /app-version and GET /release-notes.
/// PHP's is_array is true for a JSON object and a JSON list, so both count as a "container" here;
/// is_int is true only for a JSON integer that fits 64 bits (a quoted "12", 12.0 and 1e2 are not).
/// </summary>
internal static partial class AppCatalog
{
    private static readonly string[] Platforms = ["android", "ios"];

    /// <summary>Parses the file's bytes, or null (logged) when they are not a JSON object or list.</summary>
    public static JsonDocument? Decode(ReadOnlySpan<byte> utf8, ILogger logger)
    {
        JsonDocument document;
        try
        {
            document = PhpJson.Parse(utf8.ToArray());
        }
        catch (JsonException e)
        {
            LogNotJson(logger, e.Message);
            return null;
        }

        if (!IsContainer(document.RootElement))
        {
            LogNotObject(logger);
            document.Dispose();
            return null;
        }

        return document;
    }

    /// <summary>GET /app-version: always an object; <c>latest</c> and <c>announcement</c> are absent, never null.</summary>
    public static JsonObject VersionPayload(JsonDocument? catalog, ILogger logger)
    {
        if (catalog is null)
        {
            return FallbackPayload();
        }

        var root = catalog.RootElement;
        var releases = ReadReleases(root, logger);
        var payload = new JsonObject();
        foreach (var platform in Platforms)
        {
            payload[platform] = PlatformBlock(platform, Member(root, platform), releases, logger);
        }

        var announcement = ReadAnnouncement(root, logger);
        if (announcement is not null)
        {
            payload["announcement"] = announcement;
        }

        return payload;
    }

    /// <summary>GET /release-notes: the valid releases in file order; empty when the catalog is unusable.</summary>
    public static JsonArray Releases(JsonDocument? catalog, ILogger logger)
    {
        var array = new JsonArray();
        if (catalog is null)
        {
            return array;
        }

        foreach (var release in ReadReleases(catalog.RootElement, logger))
        {
            array.Add((JsonNode?)release.ToJson());
        }

        return array;
    }

    private static JsonObject FallbackPayload()
    {
        var payload = new JsonObject();
        foreach (var platform in Platforms)
        {
            payload[platform] = FallbackBlock(platform);
        }

        return payload;
    }

    private static JsonObject FallbackBlock(string platform) => new()
    {
        ["minimumBuild"] = 1,
        ["recommendedBuild"] = 1,
        ["storeUrl"] = FallbackUrl(platform),
    };

    private static string FallbackUrl(string platform) => platform == "android"
        ? "https://play.google.com/store/apps/details?id=com.thestrongrope"
        : "https://apps.apple.com/app/id6807232453";

    private static JsonObject PlatformBlock(string platform, JsonElement? entry, List<Release> releases, ILogger logger)
    {
        if (entry is null || !IsContainer(entry.Value) || AsInt(Member(entry.Value, "minimumBuild")) is not long minimum)
        {
            LogPlatformFallback(logger, platform);
            return FallbackBlock(platform);
        }

        var recommended = AsInt(Member(entry.Value, "recommendedBuild")) ?? minimum;
        var url = AsNonEmptyString(Member(entry.Value, "storeUrl")) ?? FallbackUrl(platform);
        var block = new JsonObject
        {
            ["minimumBuild"] = minimum,
            ["recommendedBuild"] = recommended,
            ["storeUrl"] = url,
        };

        // The notes the alert carries are those of the build this platform recommends.
        var latest = releases.FirstOrDefault(r => r.BuildFor(platform) == recommended);
        if (latest is not null)
        {
            block["latest"] = new JsonObject { ["version"] = latest.Version, ["notes"] = NotesJson(latest.Notes) };
        }

        return block;
    }

    private static List<Release> ReadReleases(JsonElement root, ILogger logger)
    {
        var releases = new List<Release>();
        var entries = Member(root, "releases");
        if (entries is null)
        {
            return releases;
        }

        if (!IsContainer(entries.Value))
        {
            LogReleasesNotList(logger);
            return releases;
        }

        var index = 0;
        foreach (var entry in Values(entries.Value))
        {
            var release = ReadRelease(entry);
            if (release is null)
            {
                LogReleaseMalformed(logger, index);
            }
            else
            {
                releases.Add(release);
            }

            index++;
        }

        return releases;
    }

    private static Release? ReadRelease(JsonElement entry)
    {
        if (!IsContainer(entry))
        {
            return null;
        }

        var version = AsNonEmptyString(Member(entry, "version"));
        var date = Member(entry, "date") is { ValueKind: JsonValueKind.String } d ? d.GetString() : null;
        var builds = Member(entry, "builds");
        if (version is null || date is null || !DateShape().IsMatch(date) || builds is null || !IsContainer(builds.Value))
        {
            return null;
        }

        var notes = new List<string>();
        if (Member(entry, "notes") is { } rawNotes && IsContainer(rawNotes))
        {
            notes.AddRange(Values(rawNotes).Select(n => AsNonEmptyString(n)).OfType<string>());
        }

        return new Release(version, date, notes, AsInt(Member(builds.Value, "android")), AsInt(Member(builds.Value, "ios")));
    }

    private static JsonObject? ReadAnnouncement(JsonElement root, ILogger logger)
    {
        var entry = Member(root, "announcement");
        if (entry is null || entry.Value.ValueKind == JsonValueKind.Null)
        {
            return null;
        }

        var id = IsContainer(entry.Value) ? AsNonEmptyString(Member(entry.Value, "id")) : null;
        var title = IsContainer(entry.Value) ? AsNonEmptyString(Member(entry.Value, "title")) : null;
        if (id is null || title is null)
        {
            LogAnnouncementMalformed(logger);
            return null;
        }

        var body = Member(entry.Value, "body") is { ValueKind: JsonValueKind.String } b ? b.GetString() : string.Empty;
        return new JsonObject { ["id"] = id, ["title"] = title, ["body"] = body };
    }

    /// <summary>The value under a key (the last one when the key repeats, as PHP). Lists have no string keys.</summary>
    private static JsonElement? Member(JsonElement container, string key)
    {
        if (container.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        JsonElement? found = null;
        foreach (var property in container.EnumerateObject())
        {
            if (property.NameEquals(key))
            {
                found = property.Value;
            }
        }

        return found;
    }

    /// <summary>The values of an object or list, in file order (PHP's foreach).</summary>
    private static IEnumerable<JsonElement> Values(JsonElement container) => container.ValueKind == JsonValueKind.Object
        ? container.EnumerateObject().Select(p => p.Value)
        : container.EnumerateArray();

    private static bool IsContainer(JsonElement element) => element.ValueKind is JsonValueKind.Object or JsonValueKind.Array;

    private static bool IsContainer(JsonElement? element) => element is { } e && IsContainer(e);

    private static string? AsNonEmptyString(JsonElement? element) =>
        element is { ValueKind: JsonValueKind.String } e && e.GetString() is { Length: > 0 } s ? s : null;

    /// <summary>PHP is_int: a JSON number written without fraction or exponent that fits 64 bits.</summary>
    private static long? AsInt(JsonElement? element)
    {
        if (element is not { ValueKind: JsonValueKind.Number } number)
        {
            return null;
        }

        var raw = number.GetRawText();
        if (raw.AsSpan().IndexOfAny('.', 'e', 'E') >= 0)
        {
            return null;
        }

        return long.TryParse(raw, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var value) ? value : null;
    }

    private static JsonArray NotesJson(IReadOnlyList<string> notes)
    {
        var array = new JsonArray();
        foreach (var note in notes)
        {
            array.Add((JsonNode?)JsonValue.Create(note));
        }

        return array;
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "app-version catalog is not valid JSON, serving the permissive fallback: {Reason}")]
    private static partial void LogNotJson(ILogger logger, string reason);

    [LoggerMessage(Level = LogLevel.Warning, Message = "app-version catalog is not a JSON object, serving the permissive fallback")]
    private static partial void LogNotObject(ILogger logger);

    [LoggerMessage(Level = LogLevel.Warning, Message = "app-version catalog has no integer minimumBuild for {Platform}, falling back to 1 for that platform")]
    private static partial void LogPlatformFallback(ILogger logger, string platform);

    [LoggerMessage(Level = LogLevel.Warning, Message = "app-version catalog \"releases\" is not a list, ignoring it")]
    private static partial void LogReleasesNotList(ILogger logger);

    [LoggerMessage(Level = LogLevel.Warning, Message = "app-version catalog release #{Index} is malformed, dropping it")]
    private static partial void LogReleaseMalformed(ILogger logger, int index);

    [LoggerMessage(Level = LogLevel.Warning, Message = "app-version catalog announcement is malformed, ignoring it")]
    private static partial void LogAnnouncementMalformed(ILogger logger);

    // PHP's /^\d{4}-\d{2}-\d{2}$/ without /u or /D: ASCII digits, and "$" also matches before one final newline, as in .NET.
    [GeneratedRegex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", RegexOptions.None, 1000)]
    private static partial Regex DateShape();

    private sealed record Release(string Version, string Date, IReadOnlyList<string> Notes, long? Android, long? Ios)
    {
        public long? BuildFor(string platform) => platform == "android" ? Android : Ios;

        /// <summary>An empty builds object is written as [] (PHP's empty array), a populated one as an object.</summary>
        public JsonObject ToJson()
        {
            JsonNode builds = new JsonArray();
            if (Android is not null || Ios is not null)
            {
                var object_ = new JsonObject();
                if (Android is long a)
                {
                    object_["android"] = a;
                }

                if (Ios is long i)
                {
                    object_["ios"] = i;
                }

                builds = object_;
            }

            return new JsonObject { ["version"] = Version, ["date"] = Date, ["notes"] = NotesJson(Notes), ["builds"] = builds };
        }
    }
}
