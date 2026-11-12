using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Tsr.Notifications.Api.Domain;

/// <summary>What a member's alert setting is about: a class's scheduled event (<c>event:12</c>) or a timetable slot (<c>slot:7</c>).</summary>
internal readonly record struct EventKey(string Text, bool IsEvent, long Id);

/// <summary>One change a phone sends: the alert offset in minutes (null: the app's default), muted, deleted for this member, and when the phone made it.</summary>
internal sealed record SettingChange(int? OffsetMinutes, bool Muted, bool Deleted, DateTimeOffset ClientTime);

/// <summary>
/// The pure rules of <c>PUT /me/calendar/settings</c> (PHP <c>MobileCalendarModel::syncSettings</c>, <c>applySetting</c>, <c>changeTime</c>): the installation's device key, the event key, a change's
/// fields in PHP's order (offset, the two switches, the client time), the clock-skew clamp and the last-writer rule. Times are compared and stored in whole milliseconds, as PHP's <c>datetime(3)</c>.
/// </summary>
internal static partial class CalendarSettings
{
    public const int MaxChanges = 200;
    public const string DeviceKeyError = "device_key must be a random installation identifier (16-64 characters)";
    public const string BatchError = "A batch must contain at most 200 changes";
    public const string ChangeNotObjectError = "Each change must be an object";

    private static readonly int[] Offsets = [0, -5, -15, -30, -60, -1440, -2880];

    private static readonly TimeSpan AllowedSkew = TimeSpan.FromMinutes(5);

    [GeneratedRegex(@"^[a-zA-Z0-9_-]{16,64}\z")]
    private static partial Regex DeviceKey();

    [GeneratedRegex(@"^(event|slot):([1-9][0-9]{0,9})\z")]
    private static partial Regex KeyText();

    [GeneratedRegex(@"^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(?:\.([0-9]{1,3}))?Z\z")]
    private static partial Regex UtcTime();

    public static bool IsDeviceKey(JsonElement value) =>
        value.ValueKind == JsonValueKind.String && DeviceKey().IsMatch(value.GetString() ?? string.Empty);

    /// <summary>The change's <c>event_key</c>: absent or null reads as empty (invalid); anything but text is refused by its own message.</summary>
    public static Result<EventKey> Key(JsonElement change)
    {
        var value = Field(change, "event_key");
        if (value.ValueKind is not (JsonValueKind.String or JsonValueKind.Undefined or JsonValueKind.Null))
        {
            return Result.Fail<EventKey>("event_key must be a string");
        }

        var text = value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;
        var match = KeyText().Match(text);
        return match.Success
            ? Result.Ok(new EventKey(text, match.Groups[1].Value == "event", long.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture)))
            : Result.Fail<EventKey>("Invalid event_key");
    }

    public static Result<SettingChange> Change(JsonElement change)
    {
        var offset = Field(change, "offset_minutes");
        var hasOffset = offset.ValueKind is not (JsonValueKind.Undefined or JsonValueKind.Null);
        var minutes = 0L;
        if (hasOffset && (!PhpValue.IsInt(offset, out minutes) || !Offsets.Contains((int)Math.Clamp(minutes, int.MinValue, int.MaxValue))))
        {
            return Result.Fail<SettingChange>("Choose a supported alert offset");
        }

        var muted = Field(change, "muted");
        var deleted = Field(change, "deleted");
        if (!IsBoolean(muted) || !IsBoolean(deleted))
        {
            return Result.Fail<SettingChange>("muted and deleted must be booleans");
        }

        var time = ClientTime(Field(change, "client_updated_at"));
        return time.IsSuccess
            ? Result.Ok(new SettingChange(hasOffset ? (int)minutes : null, muted.ValueKind == JsonValueKind.True, deleted.ValueKind == JsonValueKind.True, time.Value))
            : Result.Fail<SettingChange>(time.Error!);
    }

    /// <summary>The time kept for a change: the phone's, unless its clock runs more than five minutes ahead of the server's, in which case the server's (and the answer says so).</summary>
    public static (DateTimeOffset Stamp, bool Skew) Stamp(DateTimeOffset clientTime, DateTimeOffset now)
    {
        var skew = clientTime > now + AllowedSkew;
        return (Milliseconds(skew ? now : clientTime), skew);
    }

    /// <summary>The last writer wins: a change loses to a stored one made later, and at the same millisecond to one from a device key that is not smaller (bytes compared, as <c>strcmp</c>).</summary>
    public static bool Loses(DateTimeOffset stamp, string device, DateTimeOffset oldStamp, string oldDevice)
    {
        var mine = Milliseconds(stamp);
        var theirs = Milliseconds(oldStamp);
        return mine < theirs || (mine == theirs && string.CompareOrdinal(device, oldDevice) <= 0);
    }

    /// <summary>The wire form of a setting's time: UTC with milliseconds.</summary>
    public static string Iso(DateTimeOffset value) => value.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'", CultureInfo.InvariantCulture);

    /// <summary>PHP <c>settingPayload</c>, key order included: a stored setting as both calendar routes answer it.</summary>
    public static Dictionary<string, object?> Payload(MemberEventSetting setting)
    {
        ArgumentNullException.ThrowIfNull(setting);
        return new()
        {
            ["offset_minutes"] = setting.OffsetMinutes,
            ["muted"] = setting.Muted != 0,
            ["deleted"] = setting.DeletedForMe != 0,
            ["updated_at"] = Iso(setting.ClientUpdatedAt),
            ["server_updated_at"] = Iso(setting.ServerUpdatedAt),
            ["device_key"] = setting.DeviceKey,
        };
    }

    public static DateTimeOffset Milliseconds(DateTimeOffset value)
    {
        var utc = value.ToUniversalTime();
        return utc.AddTicks(-(utc.Ticks % TimeSpan.TicksPerMillisecond));
    }

    // A change is a JSON object; PHP also lets a list through, which then has no named field.
    private static JsonElement Field(JsonElement change, string name) =>
        change.ValueKind == JsonValueKind.Object && change.TryGetProperty(name, out var value) ? value : default;

    private static bool IsBoolean(JsonElement value) => value.ValueKind is JsonValueKind.True or JsonValueKind.False;

    private static Result<DateTimeOffset> ClientTime(JsonElement value)
    {
        var match = value.ValueKind == JsonValueKind.String ? UtcTime().Match(value.GetString() ?? string.Empty) : Match.Empty;
        if (!match.Success)
        {
            return Result.Fail<DateTimeOffset>("client_updated_at must be an ISO UTC timestamp");
        }

        var parts = Enumerable.Range(1, 6).Select(i => int.Parse(match.Groups[i].Value, CultureInfo.InvariantCulture)).ToArray();
        var milliseconds = match.Groups[7].Success ? int.Parse(match.Groups[7].Value.PadRight(3, '0'), CultureInfo.InvariantCulture) : 0;
        try
        {
            return Result.Ok(new DateTimeOffset(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], milliseconds, TimeSpan.Zero));
        }
        catch (ArgumentOutOfRangeException)
        {
            // Not a real date or time (31 February, hour 24): PHP's parser warns or fails, and the model refuses both.
            return Result.Fail<DateTimeOffset>("Invalid client_updated_at");
        }
    }
}
