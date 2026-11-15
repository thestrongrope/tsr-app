using NUnit.Framework;
using Tsr.Classes.Api.Domain;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class TsrRulesTests
{
    [TestCase(0, 0, 0.0)]
    [TestCase(1, 1, 100.0)]
    [TestCase(2, 3, 66.7)]
    [TestCase(1, 3, 33.3)]
    [TestCase(1, 8, 12.5)]
    [TestCase(49, 400, 12.3)]
    [TestCase(0, 5, 0.0)]
    public void The_share_of_classes_is_a_float_to_one_decimal_half_away_from_zero(int conducted, int total, double expected) =>
        Assert.That(TsrRules.Percent(conducted, total).Value, Is.EqualTo(expected));

    [Test]
    public void A_level_averages_its_class_quotients_to_eight_decimals_and_no_class_is_zero()
    {
        Assert.That(TsrRules.LevelAttendance(0m, 0), Is.EqualTo(0));
        Assert.That(TsrRules.LevelAttendance(0.5m + 0.51m, 2), Is.EqualTo(51), "0.505 is 50.5 percent, which rounds up");
        Assert.That(TsrRules.LevelAttendance(0.3333m + 0.3333m + 0.3334m, 3), Is.EqualTo(33));
    }

    [Test]
    public void The_newest_last_day_comes_first_classes_without_one_come_last_and_ties_go_by_code()
    {
        (string Code, string? Last)[] rows = [("C", null), ("B", "2025-10-01"), ("A", "2025-10-01"), ("D", "2025-11-01")];

        var ordered = TsrRules.NewestFirst(rows, r => r.Last, r => r.Code);

        Assert.That(ordered.Select(r => r.Code), Is.EqualTo(Codes("D", "A", "B", "C")));
    }

    [Test]
    public void The_highest_attendance_comes_first_classes_without_one_come_last_and_ties_go_by_code()
    {
        (string Code, decimal? Per)[] rows = [("C", null), ("B", 0.5m), ("A", 0.5m), ("D", 0.9m)];

        var ordered = TsrRules.HighestFirst(rows, r => r.Per, r => r.Code);

        Assert.That(ordered.Select(r => r.Code), Is.EqualTo(Codes("D", "A", "B", "C")));
    }

    private static string[] Codes(params string[] codes) => codes;
}
