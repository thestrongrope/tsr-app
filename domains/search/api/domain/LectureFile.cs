using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The lecture data file of the feed (<c>TSR_LECTURES_FILE</c>, tsr-web's <c>lectures.ndjson</c>): one JSON object a line, its <c>slug</c> the document id, the line indexed as it is: never parsed and printed again, so a vector is written as the file has it (a float must not round).
/// A file that is not set, is missing, is over <see cref="MaxBytes"/> or <see cref="MaxLectures"/>, or holds a line that is not a lecture (not an object, no slug, a slug twice) is an EMPTY source: the feed then keeps the index as it is and creates an empty one when there is none,
/// so a server without the file answers lecture search with no lectures, not an error. The warning holds counts and the line number, never a path or text.
/// </summary>
internal static partial class LectureFile
{
    /// <summary>The real file is about 23 MB; this stops a file that is not the lecture data.</summary>
    public const long MaxBytes = 64L * 1024 * 1024;

    public const int MaxLectures = 5000;

    public static async Task<IReadOnlyList<LibraryDocument>> ReadAsync(string? path, ILogger log, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(log);
        if (string.IsNullOrEmpty(path))
        {
            LogNotSet(log);
            return [];
        }

        var info = new FileInfo(path);
        if (!info.Exists)
        {
            LogMissing(log);
            return [];
        }

        if (info.Length > MaxBytes)
        {
            LogTooBig(log, info.Length, MaxBytes);
            return [];
        }

        var documents = new List<LibraryDocument>();
        var seen = new HashSet<string>(StringComparer.Ordinal);
        var number = 0;
        using var reader = new StreamReader(path);
        while (await reader.ReadLineAsync(ct) is { } raw)
        {
            number++;
            var line = raw.Trim();
            if (line.Length == 0)
            {
                continue;
            }

            if (documents.Count >= MaxLectures || Slug(line) is not { } slug || !seen.Add(slug))
            {
                LogBadLine(log, number, documents.Count);
                return [];
            }

            documents.Add(new LibraryDocument(slug, line));
        }

        return documents;
    }

    private static string? Slug(string line)
    {
        try
        {
            using var document = JsonDocument.Parse(line);
            return document.RootElement.ValueKind == JsonValueKind.Object
                && document.RootElement.TryGetProperty("slug", out var slug) && slug.ValueKind == JsonValueKind.String && slug.GetString() is { Length: > 0 } value
                ? value
                : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    [LoggerMessage(Level = LogLevel.Information, Message = "Library feed: TSR_LECTURES_FILE is not set; the lecture index is created empty and left as it is")]
    private static partial void LogNotSet(ILogger logger);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Library feed: the lecture file is missing; the lecture index is kept as it is")]
    private static partial void LogMissing(ILogger logger);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Library feed: the lecture file is {Size} bytes, over the limit of {Limit}; the lecture index is kept as it is")]
    private static partial void LogTooBig(ILogger logger, long size, long limit);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Library feed: the lecture file has a line that is not a lecture (line {Line}, after {Read} good lectures) or more lectures than allowed; the lecture index is kept as it is")]
    private static partial void LogBadLine(ILogger logger, int line, int read);
}
