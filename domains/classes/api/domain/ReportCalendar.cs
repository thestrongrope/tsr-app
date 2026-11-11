namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP's <c>calendar_table</c> and the date arithmetic of <c>MisModel</c>, without the table: a day's week is <c>(YEAR(dt), WEEK(dt, 0))</c>, Sunday to Saturday, the days before the year's first Sunday
/// are week 0, and a week that spans New Year is two weeks. The table covers 2010-01-01 to 2040-12-31 (PHP's seed); a date outside it has no week. Today is passed in (UTC, as PHP and its database run).
/// </summary>
internal static class ReportCalendar
{
    private static readonly DateOnly FirstDay = new(2010, 1, 1);
    private static readonly DateOnly LastDay = new(2040, 12, 31);

    internal readonly record struct Week(int Year, int Number, DateOnly Min, DateOnly Max);

    private static int FirstSundayOffset(int year) => (7 - (int)new DateOnly(year, 1, 1).DayOfWeek) % 7;

    /// <summary>MariaDB <c>WEEK(day, 0)</c>.</summary>
    public static int NumberOf(DateOnly day)
    {
        var offset = FirstSundayOffset(day.Year);
        var index = day.DayOfYear - 1;
        return index < offset ? 0 : ((index - offset) / 7) + 1;
    }

    /// <summary>The calendar row of a day: its week, whole (not cut to any range), or null outside the table.</summary>
    public static Week? OnDate(DateOnly day) => day < FirstDay || day > LastDay ? null : Range(day.Year, NumberOf(day));

    /// <summary>PHP <c>get_week_range</c>: the first and last day of that week in the table, or null when no day has it.</summary>
    public static Week? Range(int year, int number)
    {
        if (year < FirstDay.Year || year > LastDay.Year || number < 0)
        {
            return null;
        }

        var yearEnd = new DateOnly(year, 12, 31);
        var first = new DateOnly(year, 1, 1);
        var offset = FirstSundayOffset(year);
        var min = number == 0 ? first : first.AddDays(offset + (7 * (number - 1)));
        var max = number == 0 ? first.AddDays(offset - 1) : min.AddDays(6);
        if (max > yearEnd)
        {
            max = yearEnd;
        }

        return min > max ? null : new Week(year, number, min, max);
    }

    /// <summary>The weeks (the table's group by year and week) of the days from <paramref name="start"/> to <paramref name="end"/>, each cut to those days, in date order.</summary>
    public static IReadOnlyList<Week> Weeks(DateOnly start, DateOnly end)
    {
        var from = start < FirstDay ? FirstDay : start;
        var to = end > LastDay ? LastDay : end;
        var weeks = new List<Week>();
        for (var day = from; day <= to; day = day.AddDays(1))
        {
            var number = NumberOf(day);
            if (weeks.Count > 0 && weeks[^1].Year == day.Year && weeks[^1].Number == number)
            {
                weeks[^1] = weeks[^1] with { Max = day };
                continue;
            }

            weeks.Add(new Week(day.Year, number, day, day));
        }

        return weeks;
    }

    /// <summary>
    /// PHP <c>getDates('MM-YYYY', 'MM-YYYY')</c>: the first day of the start month moved back to a Sunday, the last day of the end month (no later than today) moved forward to a Saturday.
    /// The start can come after the end when the months lie in the future.
    /// </summary>
    public static (DateOnly Start, DateOnly End) Window(string startMonth, string endMonth, DateOnly today)
    {
        var start = FirstOfMonth(startMonth);
        var last = FirstOfMonth(endMonth).AddMonths(1).AddDays(-1);
        var end = last > today ? today : last;
        return (start.AddDays(-(int)start.DayOfWeek), end.AddDays(6 - (int)end.DayOfWeek));
    }

    private static DateOnly FirstOfMonth(string month)
    {
        var parts = month.Split('-');
        return new DateOnly(int.Parse(parts[1], System.Globalization.CultureInfo.InvariantCulture), int.Parse(parts[0], System.Globalization.CultureInfo.InvariantCulture), 1);
    }

    /// <summary>PHP <c>lastCompletedWeek</c>: the week of the day seven days before today.</summary>
    public static (int Year, int Number) LastCompleted(DateOnly today)
    {
        var week = OnDate(today.AddDays(-7)) ?? throw new InvalidOperationException("Today is outside the calendar table");
        return (week.Year, week.Number);
    }

    /// <summary>
    /// PHP <c>weekNeighbours</c>: the weeks either side, found one day outside the week. A week with no row steps from the epoch (PHP's <c>strtotime(null)</c>), so it has none. The next is
    /// null once it would pass the last completed week.
    /// </summary>
    public static (Week? Previous, Week? Next) Neighbours(int year, int number, DateOnly today)
    {
        var range = Range(year, number);
        var min = range?.Min ?? new DateOnly(1970, 1, 1);
        var max = range?.Max ?? new DateOnly(1970, 1, 1);
        var previous = OnDate(min.AddDays(-1));
        var next = OnDate(max.AddDays(1));
        var (lastYear, lastNumber) = LastCompleted(today);
        var pastLast = next is { } n && (n.Year > lastYear || (n.Year == lastYear && n.Number > lastNumber));
        return (previous, pastLast ? null : next);
    }
}
