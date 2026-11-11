using System.Globalization;
using System.Text.Json;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// The rules of teacher training, as PHP's TeachersModel states them, apart from any database: the five levels and their codes, one requested change, the history comment of a batch, the flags of an imported
/// teacher and the batch id. Shared by the training and the import routes (domain/TeacherWriter.cs writes).
/// </summary>
internal static class TeacherTraining
{
    /// <summary>The levels a teacher can be trained for, with the codes the web shows, in the order the app lists them.</summary>
    public static readonly IReadOnlyList<(string Key, string Code)> Levels = [("salman", "SM"), ("abuzar", "AG"), ("miqdad", "MK"), ("ammar", "AY"), ("bilal", "BL")];

    internal sealed record Change(int Token, string Level, bool Added);

    internal sealed record Flags(int Salman, int Abuzar, int Miqdad, int Ammar, int Bilal)
    {
        public static Flags None { get; } = new(0, 0, 0, 0, 0);

        public int Of(string level) => level switch
        {
            "salman" => Salman,
            "abuzar" => Abuzar,
            "miqdad" => Miqdad,
            "ammar" => Ammar,
            _ => Bilal,
        };

        public Flags With(string level, int value) => level switch
        {
            "salman" => this with { Salman = value },
            "abuzar" => this with { Abuzar = value },
            "miqdad" => this with { Miqdad = value },
            "ammar" => this with { Ammar = value },
            _ => this with { Bilal = value },
        };
    }

    /// <summary>
    /// One entry of the request's <c>changes</c>: an object with a numeric <c>token</c> (cast to an integer), a <c>level</c> that is one of the five keys and an <c>action</c> of <c>added</c> or <c>removed</c>, all
    /// present and not null; anything else is null (PHP: "Each change needs a teacher, a level and added or removed"). A token beyond 32 bits cannot be a member and reads as 0.
    /// </summary>
    public static Change? ReadChange(JsonElement item)
    {
        if (item.ValueKind != JsonValueKind.Object
            || !item.TryGetProperty("token", out var token) || !IsNumeric(token)
            || !item.TryGetProperty("level", out var level) || level.ValueKind != JsonValueKind.String || !Levels.Any(l => l.Key == level.GetString())
            || !item.TryGetProperty("action", out var action) || action.ValueKind != JsonValueKind.String || action.GetString() is not ("added" or "removed"))
        {
            return null;
        }

        var number = PhpValue.ToInteger(token);
        return new Change(number is >= int.MinValue and <= int.MaxValue ? (int)number : 0, level.GetString()!, action.GetString() == "added");
    }

    /// <summary>
    /// PHP writeBatch's history comment: "UPDATE: note - Batch ID: id - +SM, -AG" for a teacher who had a record (only the levels that flipped, in order, an empty list when none did) or "ADD: note - Batch ID: id - +SM..."
    /// for a new one (every level switched on).
    /// </summary>
    public static string Comment(Flags? existing, Flags after, string note, string batchId)
    {
        ArgumentNullException.ThrowIfNull(after);
        var changes = new List<string>();
        foreach (var (key, code) in Levels)
        {
            var now = after.Of(key) != 0;
            var was = existing is not null && existing.Of(key) != 0;
            if (existing is null ? now : now != was)
            {
                changes.Add((now ? "+" : "-") + code);
            }
        }

        var action = existing is null ? "ADD" : "UPDATE";
        return $"{action}: {note} - Batch ID: {batchId} - {string.Join(", ", changes)}";
    }

    /// <summary>PHP importActiveTeachers: salman only for level 1 (<c>==</c>), every other level for its own and the levels above it (<c>&lt;=</c>).</summary>
    public static Flags ImportedFlags(int lowestLevel) => new(
        lowestLevel == 1 ? 1 : 0,
        lowestLevel <= 2 ? 1 : 0,
        lowestLevel <= 3 ? 1 : 0,
        lowestLevel <= 4 ? 1 : 0,
        lowestLevel <= 5 ? 1 : 0);

    /// <summary>PHP uniqid(): eight hex digits of the seconds and five of the microseconds.</summary>
    public static string BatchId(DateTimeOffset now)
    {
        var seconds = now.ToUnixTimeSeconds();
        var micros = now.Ticks % TimeSpan.TicksPerSecond / 10;
        return seconds.ToString("x8", CultureInfo.InvariantCulture) + micros.ToString("x5", CultureInfo.InvariantCulture);
    }

    private static bool IsNumeric(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Number => true,
        JsonValueKind.String => PhpValue.IsNumeric(value.GetString()!),
        _ => false,
    };
}
