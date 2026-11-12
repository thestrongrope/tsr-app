using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// The pure rules of a class conduction record, PHP's own (routes/conduction.php api_conduction_payload, SessionsModel isEditable, recordedAt, getSessionByDate, getNextSessionDate, the class header's
/// extra students), shared by the six conduction slices. Copied quirks: a flag is <c>filter_var(FILTER_VALIDATE_BOOLEAN)</c> and a missing or null <c>conducted</c> means held; the "present student" check
/// counts the body's students before the class's member filter drops strangers; a topic or reason is stored only when its flag says so; an extra student with a blank name is skipped.
/// Added (PHP would answer 500 on a strict database or truncate): a number beyond a column, a NUL byte, or a text longer than its column is a 422, checked after PHP's own rules and only on what is stored.
/// Dates: <c>ParseDate</c> reads the forms of PHP's <c>strtotime</c> people send (see its comment); relative phrases such as "next monday" are not read.
/// </summary>
internal static partial class ConductionRules
{
    public static readonly string[] Subjects = ["Arabic", "Aqaed", "Ahkam", "Akhlaq", "Other"];

    private const int MaxReason = 100;
    private const int MaxTopic = 1000;
    private const int MaxExtraName = 100;

    private static readonly string[] SubjectKeys = ["arabic", "aqaed", "ahkam", "akhlaq", "other"];

    private static readonly string[] DateFormats =
    [
        "d MMMM yyyy", "d MMM yyyy", "ddd d MMM yyyy", "ddd, d MMM yyyy", "ddd d MMMM yyyy", "MMMM d, yyyy", "MMM d, yyyy", "MMMM d yyyy", "d-MMM-yyyy",
    ];

    internal sealed record Student(int Token, bool Present, int Recitation);

    internal sealed record Extra(int Token, string Name, bool Present);

    /// <summary>A valid record: the day, whether the class was held, the reason (not held only), the five subjects' flags and topics (held only), and the attendance as sent.</summary>
    internal sealed record Payload(
        DateOnly ConductedOn,
        bool Conducted,
        string? Reason,
        int? Duration,
        int? Surah,
        int? Verse,
        IReadOnlyList<bool> Held,
        IReadOnlyList<string?> Topics,
        IReadOnlyList<Student> Students,
        IReadOnlyList<Extra> Extras);

    [GeneratedRegex(@"^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})(?:[T ]+([0-9]{1,2}):([0-9]{2})(?::([0-9]{2})(?:[.,][0-9]+)?)?[ ]*(Z|UTC|[+-][0-9]{2}(?::?[0-9]{2})?)?)?$", RegexOptions.CultureInvariant | RegexOptions.IgnoreCase | RegexOptions.NonBacktracking)]
    private static partial Regex IsoText();

    [GeneratedRegex(@"^([0-9]{4})([0-9]{2})([0-9]{2})$", RegexOptions.CultureInvariant | RegexOptions.NonBacktracking)]
    private static partial Regex CompactText();

    [GeneratedRegex(@"^([0-9]{1,2})-([0-9]{1,2})-([0-9]{4})$", RegexOptions.CultureInvariant | RegexOptions.NonBacktracking)]
    private static partial Regex DayFirstText();

    [GeneratedRegex(@"^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$", RegexOptions.CultureInvariant | RegexOptions.NonBacktracking)]
    private static partial Regex MonthFirstText();

    /// <summary>filter_var($value, FILTER_VALIDATE_BOOLEAN) cast to bool, after PHP's <c>?? default</c> (a missing or null value takes the default).</summary>
    public static bool Truthy(JsonElement value, bool whenMissing) => PhpValue.Truthy(value, whenMissing);

    /// <summary>
    /// PHP's strtotime reduced to a day: Y-m-d (one or two digit parts, an overflowing day such as 2025-02-30 rolls into the next month) with an optional time and offset (read at UTC, PHP's zone here),
    /// YYYYMMDD, d-m-Y, m/d/Y, "20 September 2025" and its weekday and comma variants, and today, now, tomorrow, yesterday. Anything else is null.
    /// </summary>
    public static DateOnly? ParseDate(string text, DateOnly today)
    {
        var trimmed = PhpText.Trim(text);
        var word = PhpText.LowerAscii(trimmed);
        if (word is "today" or "now" or "midnight")
        {
            return today;
        }

        if (word == "tomorrow")
        {
            return today.AddDays(1);
        }

        if (word == "yesterday")
        {
            return today.AddDays(-1);
        }

        var iso = IsoText().Match(trimmed);
        if (iso.Success)
        {
            return FromIso(iso);
        }

        var compact = CompactText().Match(trimmed);
        if (compact.Success)
        {
            return Build(Number(compact, 1), Number(compact, 2), Number(compact, 3));
        }

        var dayFirst = DayFirstText().Match(trimmed);
        if (dayFirst.Success)
        {
            return Build(Number(dayFirst, 3), Number(dayFirst, 2), Number(dayFirst, 1));
        }

        var monthFirst = MonthFirstText().Match(trimmed);
        if (monthFirst.Success)
        {
            return Build(Number(monthFirst, 3), Number(monthFirst, 1), Number(monthFirst, 2));
        }

        return DateTime.TryParseExact(trimmed, DateFormats, CultureInfo.InvariantCulture, DateTimeStyles.AllowWhiteSpaces, out var named) ? DateOnly.FromDateTime(named) : null;
    }

    private static int Number(Match match, int group) => int.Parse(match.Groups[group].Value, CultureInfo.InvariantCulture);

    private static DateOnly? Build(int year, int month, int day)
    {
        if (year < 1 || month is < 1 or > 12 || day is < 1 or > 31)
        {
            return null;
        }

        return new DateOnly(year, month, 1).AddDays(day - 1);
    }

    private static DateOnly? FromIso(Match match)
    {
        var (year, month, day) = (Number(match, 1), Number(match, 2), Number(match, 3));
        if (year < 1 || month is < 1 or > 12 || day is < 1 or > 31)
        {
            return null;
        }

        var hour = match.Groups[4].Success ? Number(match, 4) : 0;
        var minute = match.Groups[5].Success ? Number(match, 5) : 0;
        var second = match.Groups[6].Success ? Number(match, 6) : 0;
        if (hour > 23 || minute > 59 || second > 59)
        {
            return null;
        }

        try
        {
            var start = new DateTimeOffset(year, month, 1, hour, minute, second, OffsetOf(match.Groups[7]));
            return DateOnly.FromDateTime(start.AddDays(day - 1).UtcDateTime);
        }
        catch (ArgumentOutOfRangeException)
        {
            return null;
        }
    }

    private static TimeSpan OffsetOf(Group group)
    {
        if (!group.Success || group.Value[0] is not ('+' or '-'))
        {
            return TimeSpan.Zero;
        }

        var digits = group.Value[1..].Replace(":", string.Empty, StringComparison.Ordinal);
        var hours = int.Parse(digits.AsSpan(0, 2), CultureInfo.InvariantCulture);
        var minutes = digits.Length > 2 ? int.Parse(digits.AsSpan(2), CultureInfo.InvariantCulture) : 0;
        var offset = new TimeSpan(hours, minutes, 0);
        return group.Value[0] == '-' ? -offset : offset;
    }

    /// <summary>PHP's api_conduction_payload, then the length and NUL checks this port adds. The first failing rule is the answer.</summary>
    public static Result<Payload> Parse(JsonBody body, DateOnly today)
    {
        var dateText = PhpText.Trim(PhpValue.Text(body.Get("conductedOn")));
        var day = dateText.Length == 0 ? null : ParseDate(dateText, today);
        if (day is null)
        {
            return Result.Fail<Payload>("conductedOn is required and must be a valid date");
        }

        var conducted = Truthy(body.Get("conducted"), whenMissing: true);
        var reason = PhpText.Trim(PhpValue.Text(body.Get("nonConductionReason")));
        if (!conducted && reason.Length == 0)
        {
            return Result.Fail<Payload>("nonConductionReason is required when the class was not conducted");
        }

        var students = ReadStudents(body.Get("students"));
        var extras = ReadExtras(body.Get("extraStudents"));
        var flags = SubjectKeys.Select(key => Truthy(body.Get(key + "Conducted"), whenMissing: false)).ToArray();
        var topics = SubjectKeys.Select(key => PhpText.Trim(PhpValue.Text(body.Get(key + "Topic")))).ToArray();

        if (conducted)
        {
            var failure = HeldRules(body, students, extras, flags, topics);
            if (failure is not null)
            {
                return Result.Fail<Payload>(failure);
            }
        }

        var stored = topics.Select((topic, i) => conducted && flags[i] ? topic : null).ToArray();
        var storedReason = conducted ? null : reason;
        var duration = Optional(body.Get("duration"), "duration");
        var surah = Optional(body.Get("quranRecitationSurah"), "quranRecitationSurah");
        var verse = Optional(body.Get("quranRecitationVerse"), "quranRecitationVerse");
        var limit = FirstLimit(duration, surah, verse, students, extras) ?? TextLimit(storedReason, stored, extras);
        if (limit is not null)
        {
            return Result.Fail<Payload>(limit);
        }

        return Result.Ok(new Payload(
            day.Value,
            conducted,
            storedReason,
            duration.Value,
            surah.Value,
            verse.Value,
            flags.Select(flag => conducted && flag).ToArray(),
            stored,
            students.Select(s => s.Student).ToArray(),
            extras.Select(e => e.Extra).ToArray()));
    }

    private sealed record StudentRead(Student Student, bool OutOfRange);

    private sealed record ExtraRead(Extra Extra, bool OutOfRange);

    private static string? HeldRules(JsonBody body, List<StudentRead> students, List<ExtraRead> extras, bool[] flags, string[] topics)
    {
        if (PhpValue.ToInteger(body.Get("duration")) <= 0)
        {
            return "duration is required for a conducted class";
        }

        if (!students.Any(s => s.Student.Present) && !extras.Any(e => e.Extra.Present))
        {
            return "At least one student must be marked present";
        }

        if (!flags.Any(flag => flag))
        {
            return "At least one subject must be selected";
        }

        for (var i = 0; i < flags.Length; i++)
        {
            if (flags[i] && topics[i].Length == 0)
            {
                return $"Topic covered is required for {Subjects[i]}";
            }
        }

        return null;
    }

    private static JsonElement Field(JsonElement container, string name) =>
        container.ValueKind == JsonValueKind.Object && container.TryGetProperty(name, out var value) ? value : default;

    private static int Clamp(long value) => (int)Math.Clamp(value, int.MinValue, int.MaxValue);

    private static List<StudentRead> ReadStudents(JsonElement list)
    {
        var students = new List<StudentRead>();
        foreach (var (_, entry) in JsonBody.Entries(list))
        {
            if (entry.ValueKind is not (JsonValueKind.Object or JsonValueKind.Array))
            {
                continue;
            }

            var recitation = PhpValue.ToInteger(Field(entry, "recitation"));
            var token = Clamp(PhpValue.ToInteger(Field(entry, "token")));
            students.Add(new StudentRead(new Student(token, Truthy(Field(entry, "present"), false), Clamp(recitation)), recitation != Clamp(recitation)));
        }

        return students;
    }

    private static List<ExtraRead> ReadExtras(JsonElement list)
    {
        var extras = new List<ExtraRead>();
        foreach (var (_, entry) in JsonBody.Entries(list))
        {
            var name = entry.ValueKind is JsonValueKind.Object or JsonValueKind.Array ? PhpText.Trim(PhpValue.Text(Field(entry, "name"))) : string.Empty;
            if (name.Length == 0)
            {
                continue;
            }

            var token = PhpValue.ToInteger(Field(entry, "token"));
            extras.Add(new ExtraRead(new Extra(Clamp(token), name, Truthy(Field(entry, "present"), false)), token != Clamp(token)));
        }

        return extras;
    }

    private readonly record struct Whole(int? Value, bool OutOfRange, string Field);

    // isset($body[field]) ? (int) $body[field] : null
    private static Whole Optional(JsonElement value, string field)
    {
        if (value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null)
        {
            return new Whole(null, false, field);
        }

        var number = PhpValue.ToInteger(value);
        return new Whole(Clamp(number), number != Clamp(number), field);
    }

    private static string? FirstLimit(Whole duration, Whole surah, Whole verse, List<StudentRead> students, List<ExtraRead> extras)
    {
        foreach (var whole in new[] { duration, surah, verse })
        {
            if (whole.OutOfRange)
            {
                return $"{whole.Field} is out of range";
            }
        }

        if (students.Any(s => s.OutOfRange))
        {
            return "recitation is out of range";
        }

        return extras.Any(e => e.OutOfRange) ? "extraStudents token is out of range" : null;
    }

    private static string? TextLimit(string? reason, string?[] topics, List<ExtraRead> extras)
    {
        var failure = CheckText(reason, "nonConductionReason", MaxReason);
        for (var i = 0; i < topics.Length && failure is null; i++)
        {
            failure = CheckText(topics[i], SubjectKeys[i] + "Topic", MaxTopic);
        }

        return failure ?? extras.Select(e => CheckText(e.Extra.Name, "extraStudents name", MaxExtraName)).FirstOrDefault(message => message is not null);
    }

    private static string? CheckText(string? text, string field, int max)
    {
        if (text is null)
        {
            return null;
        }

        if (text.Contains('\0', StringComparison.Ordinal))
        {
            return $"{field} must not contain a NUL byte";
        }

        return PhpText.CodePointCount(text) > max ? $"{field} must be at most {max} characters" : null;
    }

    /// <summary>SessionsModel::isEditable with canManage true (every caller passes it): PHP's <c>diff()->days</c>, an absolute whole number of days, may not exceed ten.</summary>
    public static bool IsEditable(DateTimeOffset createdAt, DateTimeOffset now) =>
        Math.Floor(Math.Abs((now - createdAt).TotalDays)) <= 10;

    /// <summary>SessionsModel::recordedAt: when the app saved the record, never later than now, to the second; unreadable or absent text is null (the database stamps it).</summary>
    public static DateTimeOffset? RecordedAt(string? iso, DateTimeOffset now)
    {
        if (iso is null || PhpText.Trim(iso).Length == 0)
        {
            return null;
        }

        if (!DateTimeOffset.TryParse(iso, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var recorded))
        {
            return null;
        }

        var instant = (recorded > now ? now : recorded).ToUniversalTime();
        return instant.AddTicks(-(instant.Ticks % TimeSpan.TicksPerSecond));
    }

    /// <summary>The Monday and Sunday of the day's week (PHP "monday this week" / "sunday this week": a Sunday closes the week before it).</summary>
    public static (DateOnly Monday, DateOnly Sunday) WeekOf(DateOnly day)
    {
        var monday = day.AddDays(-(IsoWeekday(day) - 1));
        var sunday = monday.DayNumber > DateOnly.MaxValue.DayNumber - 6 ? DateOnly.MaxValue : monday.AddDays(6);
        return (monday, sunday);
    }

    /// <summary>1 for Monday to 7 for Sunday (PHP date 'N').</summary>
    public static int IsoWeekday(DateOnly day) => (((int)day.DayOfWeek + 6) % 7) + 1;

    /// <summary>
    /// SessionsModel::getNextSessionDate: from the last session's day (yesterday when there is none), the first schedule day after its weekday, else the first schedule day of next week; the schedule is every row ordered by
    /// day, deleted ones included. With no schedule PHP reads an undefined index as 0, so the gap is 7 minus the weekday.
    /// </summary>
    public static DateOnly NextSessionDate(DateOnly? last, DateOnly today, IReadOnlyList<int> scheduleDays)
    {
        var from = last ?? today.AddDays(-1);
        var weekday = IsoWeekday(from);
        var next = scheduleDays.Where(d => d > weekday).Select(d => (int?)d).FirstOrDefault() ?? (scheduleDays.Count > 0 ? scheduleDays[0] : 0);
        var gap = next - weekday;
        return from.AddDays(gap <= 0 ? gap + 7 : gap);
    }

    /// <summary>The class header's extra students: one per non-blank line of <c>classes.extra_students</c>, named by the text before the first comma, numbered 1, 2, 3 in order.</summary>
    public static IReadOnlyList<(int Token, string Name)> ExtraStudentsOf(string? text)
    {
        var raw = PhpText.Trim(text ?? string.Empty);
        var extras = new List<(int, string)>();
        if (raw.Length == 0)
        {
            return extras;
        }

        foreach (var line in raw.Split('\n'))
        {
            var name = PhpText.Trim(line.Split(',')[0]);
            if (name.Length > 0)
            {
                extras.Add((extras.Count + 1, name));
            }
        }

        return extras;
    }
}
