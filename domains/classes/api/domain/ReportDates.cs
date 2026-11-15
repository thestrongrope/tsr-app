using System.Globalization;
using System.Text.RegularExpressions;

namespace Tsr.Classes.Api.Domain;

/// <summary>The two days a report asks for, as sent (PHP echoes the text) and as days.</summary>
internal sealed record DateRange(string From, string To, DateOnly FromDay, DateOnly ToDay);

/// <summary>The date parameters of the reports (PHP <c>api_reports_date_ok</c> and the checks of <c>api_require_students_report</c>), 'YYYY-MM-DD', in PHP's words.</summary>
internal static partial class ReportDates
{
    public const string NotDates = "from and to must be dates as YYYY-MM-DD, from not after to";
    public const string TooLong = "The range can cover at most a year";

    private const int MostDays = 366;

    // [0-9], not \d: .NET's \d also matches other scripts' digits. $ also matches before a final newline, as PHP's does.
    [GeneratedRegex("^([0-9]{4})-([0-9]{2})-([0-9]{2})$")]
    private static partial Regex Pattern();

    /// <summary>PHP <c>api_reports_date_ok</c>: the pattern, then <c>checkdate</c> (year 0000 is not a date). A trailing newline passes, as in PHP.</summary>
    public static DateOnly? ParseDay(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        var match = Pattern().Match(text);
        if (!match.Success)
        {
            return null;
        }

        var year = int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture);
        var month = int.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture);
        var day = int.Parse(match.Groups[3].Value, CultureInfo.InvariantCulture);
        var valid = year >= 1 && month is >= 1 and <= 12 && day >= 1 && day <= DateTime.DaysInMonth(year, month);
        return valid ? new DateOnly(year, month, day) : null;
    }

    /// <summary>
    /// The range or PHP's refusal: <c>to</c> defaults to today, <c>from</c> to <paramref name="defaultDays"/> before <c>to</c> (PHP counts back from the to it was given); both must be real days, from not after to (compared as text, as PHP does),
    /// and at most 366 days apart. A default from before year 1 is PHP's "0000-..." text, which is not a date.
    /// </summary>
    public static (DateRange? Range, string? Refusal) Check(string? from, string? to, DateOnly today, int defaultDays)
    {
        to ??= today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var toDay = ParseDay(to);
        if (toDay is null)
        {
            return (null, NotDates);
        }

        var fromDay = from is null ? DefaultFrom(toDay.Value, defaultDays) : ParseDay(from);
        if (fromDay is null)
        {
            return (null, NotDates);
        }

        from ??= fromDay.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        if (string.CompareOrdinal(from, to) > 0)
        {
            return (null, NotDates);
        }

        return toDay.Value.DayNumber - fromDay.Value.DayNumber > MostDays
            ? (null, TooLong)
            : (new DateRange(from, to, fromDay.Value, toDay.Value), null);
    }

    private static DateOnly? DefaultFrom(DateOnly to, int days) => to.DayNumber - days < DateOnly.MinValue.DayNumber ? null : to.AddDays(-days);
}
