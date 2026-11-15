using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Tsr.Notifications.Api.Domain;

/// <summary>The checked fields of a new scheduled class notification; only those of its kind are set. <c>SendAt</c> and <c>SendTime</c> are wall-clock values in <c>Tz</c>.</summary>
internal sealed record ScheduleDraft(string Kind, string Tz, DateTime? SendAt, string? Weekdays, TimeOnly? SendTime, int? ClassScheduleId, int? OffsetMinutes, bool RepeatWeekly);

/// <summary>
/// The body rules of <c>POST /classes/{id}/notifications/scheduled</c> (PHP routes/classes.php route_class_notifications_scheduled_create), in PHP's order: the kind, then the sender's
/// zone, then the fields of the kind. Pure: the clock and the class's live slots (id to zone name) are passed in.
/// </summary>
internal static partial class ScheduleInput
{
    public const int MaxActivePerClass = 20;
    public const int MaxOffsetMinutes = 10080;

    public const string KindError = "kind must be ONCE, WEEKLY or REMINDER";
    public const string ZoneError = "timezone is required and must be an IANA time zone name such as Asia/Kolkata";

    [GeneratedRegex(@"^([0-9]{4})-([0-9]{2})-([0-9]{2})[T ]([01][0-9]|2[0-3]):([0-5][0-9])(?::([0-5][0-9]))?\z")]
    private static partial Regex LocalDateTime();

    [GeneratedRegex(@"^([01][0-9]|2[0-3]):([0-5][0-9])\z")]
    private static partial Regex ClockTime();

    public static string? Kind(JsonBody body)
    {
        ArgumentNullException.ThrowIfNull(body);
        var kind = PhpText.ToUpperAscii(PhpText.Trim(PhpValue.Text(body.Get("kind"))));
        return kind is "ONCE" or "WEEKLY" or "REMINDER" ? kind : null;
    }

    public static Result<ScheduleDraft> Parse(JsonBody body, string kind, DateTimeOffset now, IReadOnlyDictionary<int, string> classSlots)
    {
        ArgumentNullException.ThrowIfNull(body);
        ArgumentNullException.ThrowIfNull(classSlots);
        var zoneName = ZoneName(body.Get("timezone"));
        var zone = WallClock.Zone(zoneName);
        if (zone is null)
        {
            return Fail(ZoneError);
        }

        var tz = zoneName;
        return kind switch
        {
            "ONCE" => Once(body, tz, zone, now),
            "WEEKLY" => Weekly(body, tz),
            _ => Reminder(body, tz, classSlots),
        };
    }

    private static string ZoneName(JsonElement value)
    {
        if (value.ValueKind != JsonValueKind.String)
        {
            return string.Empty;
        }

        return PhpText.Trim(value.GetString() ?? string.Empty).Replace("Calcutta", "Kolkata", StringComparison.Ordinal);
    }

    private static Result<ScheduleDraft> Fail(string error) => Result.Fail<ScheduleDraft>(error);

    private static Result<ScheduleDraft> Once(JsonBody body, string tz, TimeZoneInfo zone, DateTimeOffset now)
    {
        var sendAt = body.Get("send_at");
        var text = sendAt.ValueKind == JsonValueKind.String ? PhpText.Trim(sendAt.GetString() ?? string.Empty) : string.Empty;
        if (text.Length == 0)
        {
            return Fail("send_at is required for a ONCE notification");
        }

        var match = LocalDateTime().Match(text);
        var wall = match.Success ? ToDateTime(match) : null;
        if (wall is null)
        {
            return Fail("send_at must be a local date and time such as 2026-11-10T18:30, without an offset");
        }

        if (WallClock.At(wall.Value, zone) <= now)
        {
            return Fail("send_at must be in the future");
        }

        return Result.Ok(new ScheduleDraft("ONCE", tz, wall, null, null, null, null, false));
    }

    private static DateTime? ToDateTime(Match match)
    {
        var parts = match.Groups.Cast<Group>().Skip(1).Select(g => g.Success ? int.Parse(g.Value, CultureInfo.InvariantCulture) : 0).ToArray();
        try
        {
            return new DateTime(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], DateTimeKind.Unspecified);
        }
        catch (ArgumentOutOfRangeException)
        {
            return null;
        }
    }

    private static Result<ScheduleDraft> Weekly(JsonBody body, string tz)
    {
        var weekdays = body.Get("weekdays");
        var entries = JsonBody.Entries(weekdays);
        if (entries.Count == 0)
        {
            return Fail("weekdays must be a non-empty list of ISO weekdays (1-7)");
        }

        var days = new SortedSet<int>();
        foreach (var entry in entries)
        {
            var day = PhpValue.ToInteger(entry.Value);
            if (day is < 1 or > 7)
            {
                return Fail("weekdays must be ISO weekdays (1-7)");
            }

            days.Add((int)day);
        }

        var time = body.Get("send_time");
        var match = time.ValueKind == JsonValueKind.String ? ClockTime().Match(time.GetString() ?? string.Empty) : Match.Empty;
        if (!match.Success)
        {
            return Fail("send_time must be HH:MM");
        }

        var clock = new TimeOnly(int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture), int.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture));
        return Result.Ok(new ScheduleDraft("WEEKLY", tz, null, string.Join(',', days), clock, null, null, false));
    }

    private static Result<ScheduleDraft> Reminder(JsonBody body, string tz, IReadOnlyDictionary<int, string> classSlots)
    {
        var scheduleId = (int)Math.Clamp(PhpValue.ToInteger(body.Get("class_schedule_id")), 0, int.MaxValue);
        if (!classSlots.TryGetValue(scheduleId, out var slotZone))
        {
            return Fail("class_schedule_id must be one of this class's schedule slots");
        }

        if (WallClock.Zone(slotZone) is null)
        {
            return Fail("That class schedule slot has no valid time zone, so a reminder cannot be timed from it");
        }

        var offset = Offset(body.Get("offset_minutes"));
        if (offset is null)
        {
            return Fail("offset_minutes is required and must be a whole number");
        }

        if (Math.Abs((long)offset.Value) > MaxOffsetMinutes)
        {
            return Fail("offset_minutes must be within one week of the class");
        }

        return Result.Ok(new ScheduleDraft("REMINDER", tz, null, null, null, scheduleId, offset, PhpTruthy(body.Get("repeat_weekly"))));
    }

    // is_numeric then (int): a number or numeric text; a fraction is cut, a huge value is clamped (it is then refused as out of range).
    private static int? Offset(JsonElement value)
    {
        var numeric = value.ValueKind switch
        {
            JsonValueKind.Number => true,
            JsonValueKind.String => double.TryParse(value.GetString()!.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed) && double.IsFinite(parsed),
            _ => false,
        };
        return numeric ? (int)Math.Clamp(PhpValue.ToInteger(value), int.MinValue, int.MaxValue) : null;
    }

    /// <summary>PHP's <c>!empty($x)</c> of a decoded JSON value.</summary>
    public static bool PhpTruthy(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.True => true,
        JsonValueKind.Number => value.GetDouble() != 0,
        JsonValueKind.String => value.GetString() is not (null or "" or "0"),
        JsonValueKind.Array => value.GetArrayLength() > 0,
        JsonValueKind.Object => value.EnumerateObject().Any(),
        _ => false,
    };
}
