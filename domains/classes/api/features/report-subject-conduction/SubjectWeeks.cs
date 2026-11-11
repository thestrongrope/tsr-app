using System.Globalization;

namespace Tsr.Classes.Api.Features.ReportSubjectConduction;

/// <summary>PHP <c>MisModel::subjectConductionWeekly</c>'s grouping: MariaDB <c>WEEK(day, 1)</c>, the week label, and the topics of a week joined with "; ".</summary>
internal static class SubjectWeeks
{
    /// <summary>MariaDB <c>WEEK(day, 1)</c>: Monday-first, week 1 is the first week with four or more days in the year, the days before it are week 0, and the year's last days can be week 53 (it does not roll over).</summary>
    public static int WeekMode1(DateOnly day)
    {
        var january1 = new DateOnly(day.Year, 1, 1);
        var daysSinceMonday = ((int)january1.DayOfWeek + 6) % 7;
        var weekOneStart = daysSinceMonday <= 3 ? january1.AddDays(-daysSinceMonday) : january1.AddDays(7 - daysSinceMonday);
        return day < weekOneStart ? 0 : ((day.DayNumber - weekOneStart.DayNumber) / 7) + 1;
    }

    /// <summary>PHP: <c>YEAR(day) . '-W' . str_pad(WEEK(day, 1), 2, '0')</c>, the calendar year of the day (so a week at New Year can carry the wrong year: copied).</summary>
    public static string Label(DateOnly day) =>
        day.Year.ToString(CultureInfo.InvariantCulture) + "-W" + WeekMode1(day).ToString("00", CultureInfo.InvariantCulture);

    /// <summary>PHP: a topic that is empty or "0" (<c>empty()</c>) is skipped; one already among the week's "; "-separated topics is not added twice (case counts).</summary>
    public static string Join(string current, string topic)
    {
        ArgumentNullException.ThrowIfNull(current);
        ArgumentNullException.ThrowIfNull(topic);
        if (topic is "" or "0")
        {
            return current;
        }

        if (current.Length == 0)
        {
            return topic;
        }

        return current.Split("; ").Contains(topic, StringComparer.Ordinal) ? current : current + "; " + topic;
    }
}
