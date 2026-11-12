using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Tsr.Notifications.Api.Domain;

/// <summary>The checked fields of a class's scheduled event. <c>Weekdays</c> is the sorted list the table stores ("1,3,5", 1 = Monday); <c>SendTime</c> is a wall-clock time in the event's zone.</summary>
internal sealed record CalendarEventValues(string Message, string? Description, string? ActionLink, string Weekdays, TimeOnly SendTime);

/// <summary>
/// The body rules of a class's scheduled event (PHP <c>MobileCalendarModel::validate</c> and <c>zone</c>), in PHP's order: the message (1 to 500 characters after trimming), the description
/// (optional, at most 2000, kept as sent), the time (HH:MM), the link (the class notification rule, rewritten to an in-app path), the weekdays (one to seven whole numbers from 1 to 7).
/// Pure: the caller hands in how a field is read, so an edit can fall back to the stored value of a field the body leaves out. A NUL character in a text is refused (PostgreSQL cannot store it).
/// </summary>
internal static partial class CalendarEventInput
{
    public const string MessageError = "Message is required and must be at most 500 characters";
    public const string DescriptionError = "Description must be at most 2000 characters";
    public const string TimeError = "Time must be HH:MM";
    public const string ChooseWeekdaysError = "Choose between one and seven weekdays";
    public const string WeekdaysError = "Weekdays must be integers from 1 (Monday) to 7";
    public const string ZoneError = "A valid IANA time zone from this phone is required";

    [GeneratedRegex(@"^([01][0-9]|2[0-3]):([0-5][0-9])\z")]
    private static partial Regex ClockTime();

    public static Result<CalendarEventValues> Parse(Func<string, JsonElement> field)
    {
        ArgumentNullException.ThrowIfNull(field);
        var message = Message(field("message"));
        if (message is null)
        {
            return Fail(MessageError);
        }

        var description = field("description");
        if (!DescriptionAllowed(description))
        {
            return Fail(DescriptionError);
        }

        var time = Time(field("send_time"));
        if (time is null)
        {
            return Fail(TimeError);
        }

        var link = ClassMessage.Link(field("action_link"), rewriteLink: true);
        if (!link.IsSuccess)
        {
            return Fail(link.Error!);
        }

        var weekdays = Weekdays(field("weekdays"));
        return weekdays.IsSuccess
            ? Result.Ok(new CalendarEventValues(message, description.ValueKind == JsonValueKind.String ? description.GetString() : null, link.Value, weekdays.Value!, time.Value))
            : Fail(weekdays.Error!);
    }

    /// <summary>The sender's zone: a trimmed IANA name this host knows (PHP stores Asia/Calcutta as Asia/Kolkata), or null.</summary>
    public static string? Zone(JsonElement value)
    {
        if (value.ValueKind != JsonValueKind.String)
        {
            return null;
        }

        var name = PhpText.Trim(value.GetString() ?? string.Empty);
        name = name == "Asia/Calcutta" ? "Asia/Kolkata" : name;
        return WallClock.Zone(name) is null ? null : name;
    }

    private static Result<CalendarEventValues> Fail(string error) => Result.Fail<CalendarEventValues>(error);

    private static string? Message(JsonElement value)
    {
        if (value.ValueKind != JsonValueKind.String)
        {
            return null;
        }

        var text = PhpText.Trim(value.GetString() ?? string.Empty);
        return text.Length == 0 || PhpText.CodePointCount(text) > 500 || text.Contains('\0', StringComparison.Ordinal) ? null : text;
    }

    private static bool DescriptionAllowed(JsonElement value)
    {
        if (value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null)
        {
            return true;
        }

        if (value.ValueKind != JsonValueKind.String)
        {
            return false;
        }

        var text = value.GetString() ?? string.Empty;
        return PhpText.CodePointCount(text) <= 2000 && !text.Contains('\0', StringComparison.Ordinal);
    }

    private static TimeOnly? Time(JsonElement value)
    {
        var match = value.ValueKind == JsonValueKind.String ? ClockTime().Match(value.GetString() ?? string.Empty) : Match.Empty;
        return match.Success
            ? new TimeOnly(int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture), int.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture))
            : null;
    }

    // PHP's is_array is true for a JSON list and a JSON object alike; each value must be an int (1.0 and "1" are not).
    private static Result<string> Weekdays(JsonElement value)
    {
        var entries = JsonBody.Entries(value);
        if (entries.Count is 0 or > 7)
        {
            return Result.Fail<string>(ChooseWeekdaysError);
        }

        var days = new SortedSet<long>();
        foreach (var entry in entries)
        {
            if (!PhpValue.IsInt(entry.Value, out var day) || day is < 1 or > 7)
            {
                return Result.Fail<string>(WeekdaysError);
            }

            days.Add(day);
        }

        return Result.Ok(string.Join(',', days));
    }
}
