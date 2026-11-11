using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class SubjectWeeksTests
{
    private static DateOnly D(string text) => DateOnly.ParseExact(text, "yyyy-MM-dd");

    // MariaDB: WEEK(d, 1) is Monday-first; week 1 is the first week with four or more days in the year; earlier days are week 0; late December can be 53.
    [TestCase("2025-01-01", 1)]
    [TestCase("2025-01-05", 1)]
    [TestCase("2025-01-06", 2)]
    [TestCase("2025-12-28", 52)]
    [TestCase("2025-12-29", 53)]
    [TestCase("2025-12-31", 53)]
    [TestCase("2026-01-01", 1)]
    [TestCase("2026-01-04", 1)]
    [TestCase("2026-01-05", 2)]
    [TestCase("2021-01-01", 0)]
    [TestCase("2026-11-11", 46)]
    [TestCase("2024-12-30", 53)]
    [TestCase("2021-01-03", 0)]
    [TestCase("2021-01-04", 1)]
    public void The_week_number_is_MariaDB_WEEK_mode_1(string day, int expected) =>
        Assert.That(SubjectWeeks.WeekMode1(D(day)), Is.EqualTo(expected));

    [Test]
    public void The_label_is_the_calendar_year_and_the_week_so_the_New_Year_weeks_carry_PHPs_mislabel()
    {
        Assert.That(SubjectWeeks.Label(D("2025-11-05")), Is.EqualTo("2025-W45"));
        Assert.That(SubjectWeeks.Label(D("2021-01-01")), Is.EqualTo("2021-W00"));
        Assert.That(SubjectWeeks.Label(D("2025-12-29")), Is.EqualTo("2025-W53"));
    }

    [Test]
    public void A_topic_is_added_to_the_week_once_and_an_empty_or_zero_topic_is_ignored()
    {
        Assert.That(SubjectWeeks.Join(string.Empty, "Alif"), Is.EqualTo("Alif"));
        Assert.That(SubjectWeeks.Join("Alif", "Ba"), Is.EqualTo("Alif; Ba"));
        Assert.That(SubjectWeeks.Join("Alif; Ba", "Alif"), Is.EqualTo("Alif; Ba"));
        Assert.That(SubjectWeeks.Join("Alif", string.Empty), Is.EqualTo("Alif"));
        Assert.That(SubjectWeeks.Join("Alif", "0"), Is.EqualTo("Alif"));
        Assert.That(SubjectWeeks.Join(string.Empty, "0"), Is.EqualTo(string.Empty));
        Assert.That(SubjectWeeks.Join("Alif", "alif"), Is.EqualTo("Alif; alif"));
    }
}
