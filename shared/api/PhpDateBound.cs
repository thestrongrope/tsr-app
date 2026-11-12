using System.Globalization;
using System.Text.RegularExpressions;

namespace Tsr.Shared.Api;

/// <summary>
/// A date parameter as MariaDB reads it when PHP hands the raw text to a datetime comparison: Y-m-d with one or two digit parts and any punctuation,
/// or YYYYMMDD, each with an optional time after a T or a space. Text MariaDB cannot read as a date is ignored here (Postgres would throw).
/// </summary>
public static partial class PhpDateBound
{
    // [0-9], not \d: .NET's \d also matches other scripts' digits, which int.Parse then refuses.
    [GeneratedRegex(
        @"^([0-9]{4})[^0-9]([0-9]{1,2})[^0-9]([0-9]{1,2})(?:[T ]([0-9]{1,2}):([0-9]{1,2}):([0-9]{1,2})(?:\.[0-9]+)?)?$|^([0-9]{4})([0-9]{2})([0-9]{2})$",
        RegexOptions.CultureInvariant | RegexOptions.NonBacktracking)]
    private static partial Regex DateText();

    /// <summary>A bound as a point in time (a bare date is its midnight, as in MariaDB; read as UTC, the zone of the stored times), or null when it is empty or not a real date.</summary>
    public static DateTime? Bound(string? raw)
    {
        var match = DateText().Match(raw?.Trim() ?? string.Empty);
        if (!match.Success)
        {
            return null;
        }

        var first = match.Groups[7].Success ? 7 : 1;
        var year = Part(match, first);
        var month = Part(match, first + 1);
        var day = Part(match, first + 2);
        if (year < 1 || month is < 1 or > 12 || day < 1 || day > DateTime.DaysInMonth(year, month))
        {
            return null;
        }

        var (hour, minute, second) = (Part(match, first + 3), Part(match, first + 4), Part(match, first + 5));
        return hour > 23 || minute > 59 || second > 59 ? null : new DateTime(year, month, day, hour, minute, second, DateTimeKind.Utc);
    }

    /// <summary>A captured number, 0 when the group did not take part (no time given; the compact form has only three groups).</summary>
    private static int Part(Match match, int group) =>
        match.Groups[group].Success ? int.Parse(match.Groups[group].Value, CultureInfo.InvariantCulture) : 0;
}
