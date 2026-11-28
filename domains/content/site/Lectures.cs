using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using Tsr.Shared.Site;

namespace Tsr.Content.Site;

/// <summary>One chapter of a lecture: where it starts, in seconds, and its title.</summary>
public sealed record LectureChapter(int StartSec, string Title);

/// <summary>One lecture of the library: the eight fields of content/lectures/lectures.ndjson the page shows (the file holds five more keys the page ignores).</summary>
public sealed record Lecture(
    string Slug,
    string Title,
    string Excerpt,
    IReadOnlyList<string> Tags,
    string Language,
    DateTimeOffset PublishedDate,
    int DurationSec,
    IReadOnlyList<LectureChapter> Chapters);

/// <summary>
/// The lecture library: public data only the site shows (capabilities/lectures.md, LEC-D1), read at build time from
/// <c>content/lectures/lectures.ndjson</c> of the repository (copied beside the program as <c>content-lectures/</c>,
/// hosts/site/Tsr.Host.Site.csproj) and shown at <c>/lectures/</c>. One JSON object per line; the other keys of the file are
/// ignored here (the content guard checks the file). Any fault in the file stops the build (LEC-R7).
/// </summary>
public static partial class Lectures
{
    public const int PageSize = 24;

    public const int TagsShown = 4;

    /// <summary>Bounds (MUST 2): the file holds 917 lectures in 22.7 MB (the transcripts and vectors too; the page reads eight keys); the same limit as the search feed's.</summary>
    private const int MaxLectures = 5_000;

    private const long MaxFileBytes = 64_000_000;

    private const string DateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'";

    public static string DefaultFile => Path.Combine(AppContext.BaseDirectory, "content-lectures", "lectures.ndjson");

    [GeneratedRegex("^[A-Za-z0-9_-]{11}$")]
    private static partial Regex VideoId();

    /// <summary>The lectures, newest first: the date descending, then the slug in ordinal order.</summary>
    public static IReadOnlyList<Lecture> Read(string file)
    {
        ArgumentNullException.ThrowIfNull(file);
        if (!File.Exists(file))
        {
            throw new SiteBuildException($"The lecture file {file} is missing; the site is not built.");
        }

        if (new FileInfo(file).Length > MaxFileBytes)
        {
            throw new SiteBuildException($"The lecture file {file} is larger than {MaxFileBytes} bytes; the site is not built.");
        }

        var lectures = new List<Lecture>();
        var slugs = new HashSet<string>(StringComparer.Ordinal);
        var number = 0;
        foreach (var line in File.ReadLines(file))
        {
            number++;
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            if (lectures.Count == MaxLectures)
            {
                throw new SiteBuildException($"The lecture file {file} holds more than {MaxLectures} lectures; the site is not built.");
            }

            var lecture = ParseLine(number, line);
            if (!slugs.Add(lecture.Slug))
            {
                throw new SiteBuildException($"The lecture file has the slug {lecture.Slug} twice (line {number}); the site is not built.");
            }

            lectures.Add(lecture);
        }

        if (lectures.Count == 0)
        {
            throw new SiteBuildException($"The lecture file {file} has no lecture; the site is not built.");
        }

        return [.. lectures.OrderByDescending(lecture => lecture.PublishedDate).ThenBy(lecture => lecture.Slug, StringComparer.Ordinal)];
    }

    /// <summary>The Lectures page, with the title and description of the present website's app/lectures/page.tsx (its search words left out).</summary>
    public static SitePage Page(string file) =>
        new("/lectures/", "Lectures — The Strong Rope", typeof(LecturesPage),
            new Dictionary<string, object?> { ["Lectures"] = Read(file) },
            Description: "Browse the TSR lecture library. Jump straight to the relevant chapter on YouTube.");

    /// <summary>"1:18" for 78 seconds, "1:08:01" for 4081: the present website's formatTimestamp.</summary>
    public static string Timestamp(int seconds)
    {
        var hours = seconds / 3600;
        var minutes = seconds % 3600 / 60;
        var rest = seconds % 60;
        return hours > 0
            ? string.Create(CultureInfo.InvariantCulture, $"{hours}:{minutes:D2}:{rest:D2}")
            : string.Create(CultureInfo.InvariantCulture, $"{minutes}:{rest:D2}");
    }

    /// <summary>The filter group of a language: Urdu and Hindi share one (LEC-D3); a language the filter does not know is in none, so only "All" shows it.</summary>
    public static string LanguageGroup(string language) => language switch
    {
        "en" => "en",
        "hi" or "ur" => "ur-hi",
        "ar" => "ar",
        _ => string.Empty,
    };

    public static string VideoUrl(string slug) => $"https://www.youtube.com/watch?v={slug}";

    public static string ChapterUrl(string slug, int startSec) =>
        string.Create(CultureInfo.InvariantCulture, $"https://www.youtube.com/watch?v={slug}&t={startSec}s");

    public static string Thumbnail(string slug) => $"https://i.ytimg.com/vi/{slug}/mqdefault.jpg";

    private static SiteBuildException Fault(int number, string key, string problem) =>
        new($"The lecture file, line {number}, key {key} {problem}; the site is not built.");

    private static Lecture ParseLine(int number, string line)
    {
        JsonDocument document;
        try
        {
            document = JsonDocument.Parse(line);
        }
        catch (JsonException)
        {
            throw new SiteBuildException($"The lecture file, line {number}, is not a JSON object; the site is not built.");
        }

        using (document)
        {
            if (document.RootElement.ValueKind != JsonValueKind.Object)
            {
                throw new SiteBuildException($"The lecture file, line {number}, is not a JSON object; the site is not built.");
            }

            return ToLecture(number, document.RootElement);
        }
    }

    private static Lecture ToLecture(int number, JsonElement root)
    {
        var slug = Text(root, number, "slug", mayBeEmpty: false);
        if (!VideoId().IsMatch(slug))
        {
            throw Fault(number, "slug", "is not an 11 character video id");
        }

        return new Lecture(
            slug,
            Text(root, number, "title", mayBeEmpty: false),
            Text(root, number, "excerpt", mayBeEmpty: true),
            Tags(root, number),
            Text(root, number, "language", mayBeEmpty: true),
            Date(root, number),
            Count(root, number, "durationSec"),
            Chapters(root, number));
    }

    private static JsonElement Property(JsonElement owner, int number, string key, JsonValueKind kind)
    {
        if (!owner.TryGetProperty(key, out var value) || value.ValueKind != kind)
        {
            throw Fault(number, key, $"is missing or is not a JSON {kind.ToString().ToLowerInvariant()}");
        }

        return value;
    }

    private static string Text(JsonElement owner, int number, string key, bool mayBeEmpty)
    {
        var text = Property(owner, number, key, JsonValueKind.String).GetString()!;
        if (!mayBeEmpty && string.IsNullOrWhiteSpace(text))
        {
            throw Fault(number, key, "is blank");
        }

        return text;
    }

    private static int Count(JsonElement owner, int number, string key)
    {
        var value = Property(owner, number, key, JsonValueKind.Number);
        if (!value.TryGetInt32(out var count) || count < 0)
        {
            throw Fault(number, key, "is not an integer of 0 or more");
        }

        return count;
    }

    private static DateTimeOffset Date(JsonElement owner, int number)
    {
        var text = Text(owner, number, "publishedDate", mayBeEmpty: false);
        if (!DateTimeOffset.TryParseExact(text, DateFormat, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var date))
        {
            throw Fault(number, "publishedDate", $"is not a date written {DateFormat}");
        }

        return date;
    }

    private static List<string> Tags(JsonElement owner, int number)
    {
        var tags = new List<string>();
        foreach (var tag in Property(owner, number, "tags", JsonValueKind.Array).EnumerateArray())
        {
            if (tag.ValueKind != JsonValueKind.String)
            {
                throw Fault(number, "tags", "holds an item that is not a string");
            }

            var text = tag.GetString()!;
            if (!string.IsNullOrWhiteSpace(text))
            {
                tags.Add(text);
            }
        }

        return tags;
    }

    private static List<LectureChapter> Chapters(JsonElement owner, int number)
    {
        var chapters = new List<LectureChapter>();
        foreach (var chapter in Property(owner, number, "chapters", JsonValueKind.Array).EnumerateArray())
        {
            if (chapter.ValueKind != JsonValueKind.Object)
            {
                throw Fault(number, "chapters", "holds an item that is not an object");
            }

            chapters.Add(new LectureChapter(Count(chapter, number, "start_sec"), Text(chapter, number, "title", mayBeEmpty: false)));
        }

        return chapters;
    }
}
