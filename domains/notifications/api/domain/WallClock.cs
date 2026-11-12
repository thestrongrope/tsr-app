using System.Text.RegularExpressions;

namespace Tsr.Notifications.Api.Domain;

/// <summary>
/// Wall-clock time in a named IANA zone, as PHP's <c>DateTimeImmutable($wall, $zone)</c> reads it: a wall time a daylight saving jump skips lands on the same offset forward
/// (02:30 when clocks go 02:00 to 03:00 is 03:30), and a wall time that happens twice is the first one. The zone name must look like an IANA name and exist on this host
/// (the API image is Debian-based and ships tzdata; PHP's list refuses a few legacy aliases that .NET accepts).
/// </summary>
internal static partial class WallClock
{
    [GeneratedRegex(@"^[A-Za-z][A-Za-z0-9_+-]*(/[A-Za-z0-9_+-]+){0,2}\z")]
    private static partial Regex ZoneName();

    public static TimeZoneInfo? Zone(string? name)
    {
        var trimmed = PhpText.Trim(name ?? string.Empty);
        if (trimmed.Length == 0 || trimmed.Length > 64 || !ZoneName().IsMatch(trimmed))
        {
            return null;
        }

        return TimeZoneInfo.TryFindSystemTimeZoneById(trimmed, out var zone) ? zone : null;
    }

    /// <summary>The instant of a wall time in the zone, expressed with the zone's offset at that instant.</summary>
    public static DateTimeOffset At(DateTime wall, TimeZoneInfo zone)
    {
        var unspecified = DateTime.SpecifyKind(wall, DateTimeKind.Unspecified);
        TimeSpan offset;
        if (zone.IsInvalidTime(unspecified))
        {
            offset = zone.GetUtcOffset(unspecified.AddHours(-3));
        }
        else if (zone.IsAmbiguousTime(unspecified))
        {
            offset = zone.GetAmbiguousTimeOffsets(unspecified).Max();
        }
        else
        {
            offset = zone.GetUtcOffset(unspecified);
        }

        return TimeZoneInfo.ConvertTime(new DateTimeOffset(unspecified, offset), zone);
    }

    /// <summary>The wall time of an instant in the zone.</summary>
    public static DateTime Local(DateTimeOffset instant, TimeZoneInfo zone) =>
        TimeZoneInfo.ConvertTime(instant, zone).DateTime;

    /// <summary>PHP's <c>modify('+N days')</c>: the wall time is kept across a daylight saving change.</summary>
    public static DateTimeOffset AddDays(DateTimeOffset instant, int days, TimeZoneInfo zone) =>
        At(Local(instant, zone).AddDays(days), zone);
}
