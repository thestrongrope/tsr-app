using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class ReportMonthsTests
{
    [TestCase("01-2025", true)]
    [TestCase("12-2099", true)]
    [TestCase("05-2000", true)]
    [TestCase("05-2025\n", true)]
    [TestCase("13-2025", false)]
    [TestCase("00-2025", false)]
    [TestCase("1-2025", false)]
    [TestCase("05-1999", false)]
    [TestCase("05-2100", false)]
    [TestCase("05/2025", false)]
    [TestCase("2025-05", false)]
    [TestCase("", false)]
    [TestCase(" 05-2025", false)]
    [TestCase("٠٥-٢٠٢٥", false)]
    public void A_month_is_MM_dash_YYYY_with_a_real_month_in_the_years_2000_to_2099(string text, bool expected) =>
        Assert.That(ReportMonths.IsMonth(text), Is.EqualTo(expected));

    [Test]
    public void Months_compare_and_subtract_as_year_times_twelve_plus_month()
    {
        Assert.That(ReportMonths.Key("01-2025"), Is.EqualTo(2025 * 12 + 1));
        Assert.That(ReportMonths.Key("12-2025\n"), Is.EqualTo(2025 * 12 + 12));
    }

    [Test]
    public void From_after_to_or_a_bad_month_is_the_months_message()
    {
        Assert.That(ReportMonths.Check("02-2025", "01-2025", true), Is.EqualTo(ReportMonths.NotMonths));
        Assert.That(ReportMonths.Check("xx", "01-2025", true), Is.EqualTo(ReportMonths.NotMonths));
        Assert.That(ReportMonths.Check("01-2025", "13-2025", false), Is.EqualTo(ReportMonths.NotMonths));
    }

    [Test]
    public void Twelve_months_are_allowed_and_a_thirteenth_is_refused_only_where_the_report_limits_it()
    {
        Assert.That(ReportMonths.Check("01-2025", "12-2025", true), Is.Null);
        Assert.That(ReportMonths.Check("01-2025", "01-2026", true), Is.EqualTo(ReportMonths.TooLong));
        Assert.That(ReportMonths.Check("01-2025", "01-2026", false), Is.Null);
        Assert.That(ReportMonths.Check("03-2025", "03-2025", true), Is.Null);
    }
}
