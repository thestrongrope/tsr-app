using NUnit.Framework;

namespace Tsr.Classes.Api.Features.ReportWeekly;

[TestFixture]
internal sealed class WeeklyGridTests
{
    private static DateOnly D(string text) => DateOnly.ParseExact(text, "yyyy-MM-dd");

    private static readonly DateOnly Sunday = D("2025-11-02");

    private static List<DateOnly> Days(DateOnly first) => [.. Enumerable.Range(0, 7).Select(first.AddDays)];

    [Test]
    public void The_first_week_belongs_to_the_month_of_its_last_day_and_the_others_to_the_month_of_their_first_day()
    {
        var months = WeeklyGrid.Months(D("2025-09-28"), D("2025-12-06"));
        Assert.That(months.Select(m => m.Label).ToArray(), Is.EqualTo((string[])["Oct-2025", "Nov-2025"]));
        Assert.That(months[0].Weeks.Select(w => w[0]).ToArray(), Is.EqualTo((DateOnly[])[D("2025-09-28"), D("2025-10-05"), D("2025-10-12"), D("2025-10-19"), D("2025-10-26")]));
        Assert.That(months[1].Weeks.Select(w => w[0]).ToArray(), Is.EqualTo((DateOnly[])[D("2025-11-02"), D("2025-11-09"), D("2025-11-16"), D("2025-11-23"), D("2025-11-30")]));
        Assert.That(months[1].Weeks[^1][^1], Is.EqualTo(D("2025-12-06")));
    }

    [Test]
    public void A_partial_last_week_is_kept_as_it_is()
    {
        var months = WeeklyGrid.Months(D("2025-11-02"), D("2025-11-10"));
        Assert.That(months.Sum(m => m.Weeks.Count), Is.EqualTo(2));
        Assert.That(months[0].Weeks[1], Has.Count.EqualTo(2));
    }

    [Test]
    public void A_week_with_no_session_is_NF_a_held_day_is_Yes_a_not_held_day_is_No()
    {
        var days = Days(Sunday);
        Assert.That(WeeklyGrid.CellOf(new Dictionary<DateOnly, int>(), days), Is.EqualTo("NF"));
        Assert.That(WeeklyGrid.CellOf(new Dictionary<DateOnly, int> { [Sunday.AddDays(1)] = 1 }, days), Is.EqualTo("Yes"));
        Assert.That(WeeklyGrid.CellOf(new Dictionary<DateOnly, int> { [Sunday.AddDays(1)] = 0 }, days), Is.EqualTo("No"));
        Assert.That(WeeklyGrid.CellOf(new Dictionary<DateOnly, int> { [Sunday.AddDays(1)] = 1, [Sunday.AddDays(3)] = 0 }, days), Is.EqualTo("Yes"));
        Assert.That(WeeklyGrid.CellOf(new Dictionary<DateOnly, int> { [Sunday.AddDays(1)] = 0, [Sunday.AddDays(3)] = 1 }, days), Is.EqualTo("Yes"));
    }

    [Test]
    public void Two_held_days_count_and_a_not_held_day_after_them_turns_the_cell_into_No_as_PHP_does()
    {
        var days = Days(Sunday);
        Assert.That(WeeklyGrid.CellOf(new Dictionary<DateOnly, int> { [Sunday.AddDays(1)] = 1, [Sunday.AddDays(2)] = 1 }, days), Is.EqualTo("Yes (2)"));
        Assert.That(WeeklyGrid.CellOf(new Dictionary<DateOnly, int> { [Sunday.AddDays(1)] = 1, [Sunday.AddDays(2)] = 1, [Sunday.AddDays(3)] = 1 }, days), Is.EqualTo("Yes (3)"));
        Assert.That(WeeklyGrid.CellOf(new Dictionary<DateOnly, int> { [Sunday.AddDays(1)] = 1, [Sunday.AddDays(2)] = 1, [Sunday.AddDays(3)] = 0 }, days), Is.EqualTo("No"));
    }

    [TestCase("Yes", "held", 1)]
    [TestCase("Yes (2)", "held", 2)]
    [TestCase("Yes (12)", "held", 12)]
    [TestCase("No", "notHeld", 0)]
    [TestCase("NF", "notFilled", 0)]
    public void The_route_reads_a_cell_as_a_status_and_a_session_count(string cell, string status, int sessions) =>
        Assert.That(WeeklyGrid.Read(cell), Is.EqualTo(new WeeklyGrid.Cell(status, sessions)));
}
