using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class ReportCalendarTests
{
    private static DateOnly D(string text) => DateOnly.ParseExact(text, "yyyy-MM-dd");

    private static readonly DateOnly Today = D("2026-11-11");

    [TestCase("2025-01-01", 0)]
    [TestCase("2025-01-04", 0)]
    [TestCase("2025-01-05", 1)]
    [TestCase("2026-01-03", 0)]
    [TestCase("2026-01-04", 1)]
    [TestCase("2026-12-27", 52)]
    [TestCase("2026-12-31", 52)]
    [TestCase("2023-01-01", 1)]
    [TestCase("2023-12-31", 53)]
    [TestCase("2025-11-09", 45)]
    public void The_week_number_is_MariaDB_WEEK_mode_0(string day, int expected) =>
        Assert.That(ReportCalendar.NumberOf(D(day)), Is.EqualTo(expected));

    [TestCase(2025, 0, "2025-01-01", "2025-01-04")]
    [TestCase(2025, 1, "2025-01-05", "2025-01-11")]
    [TestCase(2026, 0, "2026-01-01", "2026-01-03")]
    [TestCase(2025, 52, "2025-12-28", "2025-12-31")]
    [TestCase(2025, 45, "2025-11-09", "2025-11-15")]
    [TestCase(2010, 0, "2010-01-01", "2010-01-02")]
    public void A_week_is_the_days_of_one_year_with_that_number(int year, int number, string min, string max)
    {
        var week = ReportCalendar.Range(year, number);
        Assert.That(week, Is.Not.Null);
        Assert.That(week!.Value.Min, Is.EqualTo(D(min)));
        Assert.That(week.Value.Max, Is.EqualTo(D(max)));
        Assert.That(week.Value.Year, Is.EqualTo(year));
        Assert.That(week.Value.Number, Is.EqualTo(number));
    }

    [TestCase(2025, 53)]
    [TestCase(2023, 0)]
    [TestCase(2009, 52)]
    [TestCase(2041, 1)]
    [TestCase(2026, 53)]
    public void A_week_that_is_not_in_the_table_has_no_range(int year, int number) =>
        Assert.That(ReportCalendar.Range(year, number), Is.Null);

    [Test]
    public void The_days_outside_the_table_have_no_week()
    {
        Assert.That(ReportCalendar.OnDate(D("2009-12-31")), Is.Null);
        Assert.That(ReportCalendar.OnDate(D("2041-01-01")), Is.Null);
        Assert.That(ReportCalendar.OnDate(D("2025-11-12"))!.Value.Number, Is.EqualTo(45));
    }

    [Test]
    public void A_week_across_New_Year_is_two_weeks_each_cut_to_the_range_asked_for()
    {
        var weeks = ReportCalendar.Weeks(D("2025-12-28"), D("2026-01-03"));
        Assert.That(weeks.Select(w => (w.Year, w.Number, w.Min, w.Max)), Is.EqualTo(new[]
        {
            (2025, 52, D("2025-12-28"), D("2025-12-31")),
            (2026, 0, D("2026-01-01"), D("2026-01-03")),
        }));
        Assert.That(ReportCalendar.Weeks(D("2026-11-30"), D("2026-11-11")), Is.Empty);
    }

    [Test]
    public void A_window_is_whole_Sunday_to_Saturday_weeks_over_the_months_and_ends_no_later_than_this_week()
    {
        Assert.That(ReportCalendar.Window("11-2025", "11-2025", Today), Is.EqualTo((D("2025-10-26"), D("2025-12-06"))));
        Assert.That(ReportCalendar.Window("11-2026", "11-2026", Today), Is.EqualTo((D("2026-11-01"), D("2026-11-14"))));
        Assert.That(ReportCalendar.Window("12-2025", "01-2026", Today), Is.EqualTo((D("2025-11-30"), D("2026-01-31"))));
        Assert.That(ReportCalendar.Window("01-1970", "01-1970", Today), Is.EqualTo((D("1969-12-28"), D("1970-01-31"))));
    }

    [Test]
    public void A_window_wholly_in_the_future_starts_after_it_ends()
    {
        var (start, end) = ReportCalendar.Window("12-2026", "12-2026", Today);
        Assert.That(start, Is.GreaterThan(end));
    }

    [Test]
    public void The_last_completed_week_is_the_week_of_seven_days_ago()
    {
        Assert.That(ReportCalendar.LastCompleted(Today), Is.EqualTo((2026, 44)));
        Assert.That(ReportCalendar.LastCompleted(D("2026-01-06")), Is.EqualTo((2025, 52)));
    }

    [Test]
    public void The_neighbours_step_one_day_outside_the_week_and_the_next_stops_at_the_last_completed_week()
    {
        var (previous, next) = ReportCalendar.Neighbours(2025, 52, Today);
        Assert.That((previous!.Value.Year, previous.Value.Number), Is.EqualTo((2025, 51)));
        Assert.That((next!.Value.Year, next.Value.Number), Is.EqualTo((2026, 0)));

        (previous, next) = ReportCalendar.Neighbours(2026, 45, Today);
        Assert.That((previous!.Value.Year, previous.Value.Number), Is.EqualTo((2026, 44)));
        Assert.That(next, Is.Null);

        (previous, next) = ReportCalendar.Neighbours(2010, 0, Today);
        Assert.That(previous, Is.Null);
        Assert.That(next!.Value.Number, Is.EqualTo(1));
    }

    [Test]
    public void A_week_that_does_not_exist_has_no_neighbours()
    {
        var (previous, next) = ReportCalendar.Neighbours(2025, 53, Today);
        Assert.That(previous, Is.Null);
        Assert.That(next, Is.Null);
    }
}
