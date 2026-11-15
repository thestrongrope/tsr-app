using System.Globalization;
using System.Text.RegularExpressions;

namespace Tsr.Classes.Api.Domain;

/// <summary>PHP <c>MisModel::weeklyMonths</c> and <c>weeklyCell</c>, and the route's reading of a cell.</summary>
internal static partial class WeeklyGrid
{
    internal sealed record Month(string Label, IReadOnlyList<IReadOnlyList<DateOnly>> Weeks);

    internal sealed record Cell(string Status, int Sessions);

    [GeneratedRegex(@"\((\d+)\)")]
    private static partial Regex Count();

    /// <summary>
    /// The Sunday-start weeks of the window grouped by label ('Nov-2025'): the first week takes the month of its last day, every other week the month of its first day. The window starts on a Sunday
    /// (<see cref="ReportCalendar.Window"/>); the last week may be shorter.
    /// </summary>
    public static IReadOnlyList<Month> Months(DateOnly start, DateOnly end)
    {
        var months = new List<(string Label, List<IReadOnlyList<DateOnly>> Weeks)>();
        var first = true;
        for (var weekStart = start; weekStart <= end; weekStart = weekStart.AddDays(7))
        {
            var last = weekStart.AddDays(6) > end ? end : weekStart.AddDays(6);
            var labelled = (first ? last : weekStart).ToString("MMM-yyyy", CultureInfo.InvariantCulture);
            first = false;
            var days = Enumerable.Range(0, last.DayNumber - weekStart.DayNumber + 1).Select(weekStart.AddDays).ToList();
            var at = months.FindIndex(m => m.Label == labelled);
            if (at < 0)
            {
                months.Add((labelled, [days]));
                continue;
            }

            months[at].Weeks.Add(days);
        }

        return [.. months.Select(m => new Month(m.Label, m.Weeks))];
    }

    /// <summary>
    /// PHP <c>weeklyCell</c>, literally: "NF" when no day has a session, "Yes" for a held day, "Yes (n)" for several, "No" for a day not held. After "Yes (n)" a later day not held makes it "No"
    /// (the status is no longer exactly "Yes"): copied.
    /// </summary>
    public static string CellOf(IReadOnlyDictionary<DateOnly, int> conducted, IReadOnlyList<DateOnly> days)
    {
        ArgumentNullException.ThrowIfNull(conducted);
        ArgumentNullException.ThrowIfNull(days);
        var status = "NF";
        var held = 0;
        foreach (var day in days)
        {
            if (conducted.TryGetValue(day, out var flag))
            {
                if (flag == 1)
                {
                    status = "Yes";
                    held++;
                }
                else if (status != "Yes")
                {
                    status = "No";
                }
            }

            if (status == "Yes" && held > 1)
            {
                status = "Yes (" + held.ToString(CultureInfo.InvariantCulture) + ")";
            }
        }

        return status;
    }

    /// <summary>PHP <c>api_reports_weekly_class</c>: "Yes..." is held (the count in brackets, else 1), "No" is notHeld, anything else notFilled.</summary>
    public static Cell Read(string cell)
    {
        ArgumentNullException.ThrowIfNull(cell);
        if (cell.StartsWith("Yes", StringComparison.Ordinal))
        {
            var match = Count().Match(cell);
            return new Cell("held", match.Success ? int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture) : 1);
        }

        return new Cell(cell == "No" ? "notHeld" : "notFilled", 0);
    }
}
