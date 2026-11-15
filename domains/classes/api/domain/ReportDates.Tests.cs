using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class ReportDatesTests
{
    private static readonly DateOnly Today = new(2026, 11, 11);

    [TestCase("2025-11-05", true)]
    [TestCase("2024-02-29", true)]
    [TestCase("2025-11-05\n", true)]
    [TestCase("2025-02-29", false)]
    [TestCase("2025-13-01", false)]
    [TestCase("2025-00-10", false)]
    [TestCase("2025-04-31", false)]
    [TestCase("0000-01-01", false)]
    [TestCase("2025-1-05", false)]
    [TestCase("25-11-05", false)]
    [TestCase("2025/11/05", false)]
    [TestCase(" 2025-11-05", false)]
    [TestCase("", false)]
    [TestCase("٢٠٢٥-١١-٠٥", false)]
    public void A_date_is_YYYY_MM_DD_and_a_real_day(string text, bool expected) =>
        Assert.That(ReportDates.ParseDay(text) is not null, Is.EqualTo(expected));

    [Test]
    public void The_days_default_to_today_and_a_number_of_days_before_it()
    {
        var (range, refusal) = ReportDates.Check(null, null, Today, 30);

        Assert.That(refusal, Is.Null);
        Assert.That((range!.From, range.To), Is.EqualTo(("2026-10-12", "2026-11-11")));
    }

    [Test]
    public void The_default_from_counts_back_from_the_to_asked_for_not_from_today()
    {
        var (range, _) = ReportDates.Check(null, "2025-03-10", Today, 14);

        Assert.That(range!.From, Is.EqualTo("2025-02-24"));
    }

    [Test]
    public void Both_days_are_kept_as_sent()
    {
        var (range, _) = ReportDates.Check("2025-11-01", "2025-11-05\n", Today, 30);

        Assert.That((range!.From, range.To), Is.EqualTo(("2025-11-01", "2025-11-05\n")));
        Assert.That((range.FromDay, range.ToDay), Is.EqualTo((new DateOnly(2025, 11, 1), new DateOnly(2025, 11, 5))));
    }

    [TestCase("2025-11-05", "2025-11-04")]
    [TestCase("2025-11-05\n", "2025-11-05")]
    [TestCase("2025-02-30", "2025-03-05")]
    [TestCase("2025-01-01", "2025-13-05")]
    [TestCase("", "2025-11-05")]
    [TestCase("2025-11-05", "")]
    [TestCase("yesterday", "2025-11-05")]
    public void A_bad_pair_is_refused_in_PHPs_words(string from, string to) =>
        Assert.That(ReportDates.Check(from, to, Today, 30), Is.EqualTo(((DateRange?)null, (string?)ReportDates.NotDates)));

    [Test]
    public void A_range_is_at_most_366_days()
    {
        Assert.That(ReportDates.Check("2025-01-01", "2026-01-02", Today, 30).Refusal, Is.Null, "366 days");
        Assert.That(ReportDates.Check("2025-01-01", "2026-01-03", Today, 30).Refusal, Is.EqualTo(ReportDates.TooLong), "367 days");
    }

    [Test]
    public void A_default_from_before_year_one_is_refused_not_a_crash()
    {
        Assert.That(ReportDates.Check(null, "0001-01-15", Today, 30).Refusal, Is.EqualTo(ReportDates.NotDates));
        Assert.That(ReportDates.Check(null, "0001-02-10", Today, 30).Range!.From, Is.EqualTo("0001-01-11"));
    }
}
