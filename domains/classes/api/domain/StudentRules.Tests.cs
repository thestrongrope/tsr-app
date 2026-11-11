using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class StudentRulesTests
{
    [Test]
    public void The_figures_are_four_decimal_fractions_and_the_score_their_mean_to_eight_decimals()
    {
        var f = StudentRules.Of(new StudentRules.Sums(5, 4, 2, 5, 2, 4));

        Assert.That((f.Attendance, f.Attempted, f.QuizPercent), Is.EqualTo((80, 100, 80)));
        Assert.That(f.PerformanceExact, Is.EqualTo(0.86666667m), "(0.8 + 1 + 0.8) / 3");
        Assert.That(f.Performance, Is.EqualTo(87));
    }

    [Test]
    public void A_figure_with_nothing_to_divide_by_is_zero()
    {
        var f = StudentRules.Of(new StudentRules.Sums(2, 2, 0, 0, 0, 0));

        Assert.That((f.Attendance, f.Attempted, f.QuizPercent), Is.EqualTo((100, 0, 0)));
        Assert.That(f.PerformanceExact, Is.EqualTo(0.33333333m));
        Assert.That(f.Performance, Is.EqualTo(33));
    }

    [Test]
    public void A_third_that_is_not_exact_rounds_each_part_to_four_decimals_first()
    {
        var f = StudentRules.Of(new StudentRules.Sums(3, 1, 3, 3, 1, 1));

        Assert.That(f.PerformanceExact, Is.EqualTo(0.3333m), "each part is 0.3333, so their mean is 0.3333");
        Assert.That(f.Attendance, Is.EqualTo(33));
    }

    [TestCase(0L, 5, 0.0)]
    [TestCase(3000L, 2, 1500.0)]
    [TestCase(110000L, 5, 22000.0)]
    [TestCase(10L, 3, 3.33)]
    [TestCase(5L, 8, 0.63)]
    [TestCase(23L, 40, 0.58)] // 0.575 is not exact in binary: PHP 8.5 round() gives 0.58 (checked on the parity stack)
    [TestCase(41L, 40, 1.03)]
    [TestCase(51L, 40, 1.28)]
    public void The_recitation_average_is_a_float_to_two_decimals_half_away_from_zero(long total, int sessions, double expected) =>
        Assert.That(StudentRules.AverageRecitation(total, sessions).Value, Is.EqualTo(expected));

    private static readonly string[] Order = ["SALMAN", "ABUZAR", "MIQDAD"];
    private static readonly string[] LevelsOut = ["ABUZAR", "MIQDAD", "Odd"];
    private static readonly string[] CodesOut = ["B-2", "A-9", "A-10", "Z-1"];

    [Test]
    public void The_pickers_list_each_class_once_by_level_position_then_natural_order_and_the_levels_in_that_order()
    {
        StudentRules.Pick[] students =
        [
            new("A-10", "MIQDAD"), new("A-9", "MIQDAD"), new("A-10", "MIQDAD"), new("Z-1", "Odd"), new("B-2", "ABUZAR"),
        ];

        var (levels, classes) = StudentRules.Pickers(students, Order);

        Assert.That(classes.Select(c => c.Class), Is.EqualTo(CodesOut));
        Assert.That(levels, Is.EqualTo(LevelsOut));
    }

    [Test]
    public void A_class_listed_under_two_levels_keeps_the_last_one()
    {
        var (_, classes) = StudentRules.Pickers([new("A-1", "SALMAN"), new("A-1", "MIQDAD")], Order);

        Assert.That(classes.Single().Level, Is.EqualTo("MIQDAD"));
    }
}
