using Tsr.Classes.Api.Domain;
using NUnit.Framework;

namespace Tsr.Classes.Api.Tests.Domain;

public sealed class QuranLeaderboardTests
{
    private static readonly DateOnly Today = new(2026, 11, 12);

    [TestCase(null, 1)]
    [TestCase("", 1)]
    [TestCase("0", 0)]
    [TestCase(" 5 ", 5)]
    [TestCase("+7", 7)]
    [TestCase("-1", 1)]
    [TestCase("007", 1)]
    [TestCase("2.5", 1)]
    [TestCase("abc", 1)]
    [TestCase("99999999999999999999", 1)]
    public void Minimum_keeps_whole_numbers_from_zero_and_defaults_to_one(string? raw, long expected) =>
        Assert.That(QuranLeaderboard.Minimum(raw), Is.EqualTo(expected));

    [Test]
    public void Dates_default_to_the_year_before_today()
    {
        var (range, refusal) = QuranLeaderboard.CheckRange(null, null, Today);
        Assert.That(refusal, Is.Null);
        Assert.That((range!.From, range.To), Is.EqualTo(("2025-11-12", "2026-11-12")));
    }

    [Test]
    public void A_default_from_of_29_February_is_the_first_of_March_as_PHP_strtotime()
    {
        var (range, _) = QuranLeaderboard.CheckRange(null, "2024-02-29", Today);
        Assert.That(range!.From, Is.EqualTo("2023-03-01"));
    }

    [TestCase("2020-01-01", "2025-01-01", null)]
    [TestCase("2020-01-01", "2025-12-31", QuranLeaderboard.TooLong)]
    [TestCase("2026-01-02", "2026-01-01", ReportDates.NotDates)]
    [TestCase("2026-02-30", "2026-03-01", ReportDates.NotDates)]
    [TestCase("2026-01-01", "", ReportDates.NotDates)]
    public void Range_is_checked_in_PHPs_words(string from, string to, string? refusal) =>
        Assert.That(QuranLeaderboard.CheckRange(from, to, Today).Refusal, Is.EqualTo(refusal));
}
