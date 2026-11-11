using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class SummaryFiguresTests
{
    [Test]
    public void The_figures_are_the_queries_divisions_to_four_decimals_times_a_hundred_each_rounded_to_a_whole_number()
    {
        // 10 expected, 8 submitted, 6 conducted, 18 of 24 marked present, durations 45+30 over 2 sessions, Arabic 3, Aqaed 6.
        var figures = SummaryFigures.Of(new SummaryFigures.Sums(10, 8, 6, 18, 24, 2, 75, 3, 6, 0, 1, 0));
        Assert.That((figures.Expected, figures.Conducted, figures.NotFilled, figures.NotConducted), Is.EqualTo((10, 6, 2, 2)));
        Assert.That(figures.AvgStudents, Is.EqualTo(3));
        Assert.That(figures.AvgDuration, Is.EqualTo(38));
        Assert.That((figures.PercentNotFilled, figures.PercentConduction, figures.PercentAttendance), Is.EqualTo((20, 60, 75)));
        Assert.That((figures.Arabic, figures.Aqaed, figures.Ahkam, figures.Akhlaq, figures.Other), Is.EqualTo((3, 6, 0, 1, 0)));
        Assert.That((figures.PercentArabic, figures.PercentAqaed, figures.PercentAhkam, figures.PercentAkhlaq, figures.PercentOther), Is.EqualTo((50, 100, 0, 17, 0)));
    }

    [Test]
    public void The_quotient_is_rounded_to_four_decimals_before_it_is_multiplied_and_rounded_again()
    {
        // 1/3 = 0.3333 (not 0.33333...), times 100 is 33.33; 2/3 = 0.6667, 66.67. 1/8 = 0.125 -> 12.5 -> 13 (half away from zero).
        var figures = SummaryFigures.Of(new SummaryFigures.Sums(8, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0));
        Assert.That(figures.PercentNotFilled, Is.EqualTo(88));
        Assert.That(figures.PercentConduction, Is.EqualTo(13));
    }

    [Test]
    public void Nothing_submitted_nothing_conducted_nothing_marked_are_zero_percent_and_a_class_can_have_a_negative_not_filled_share()
    {
        var empty = SummaryFigures.Of(new SummaryFigures.Sums(4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
        Assert.That((empty.PercentNotFilled, empty.PercentConduction, empty.PercentAttendance, empty.AvgStudents, empty.AvgDuration, empty.PercentArabic), Is.EqualTo((100, 0, 0, 0, 0, 0)));
        var over = SummaryFigures.Of(new SummaryFigures.Sums(2, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0));
        Assert.That((over.NotFilled, over.PercentNotFilled, over.PercentConduction), Is.EqualTo((-1, -50, 150)));
    }
}
