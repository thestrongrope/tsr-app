using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class ConductionReportTests
{
    private static readonly DateOnly Sunday = new(2025, 11, 2);

    private static ConductionReport.Row RowOf(string code, string conducted, int? attendance, int? registered, int? extra, string? teacher = "T") =>
        new(1, "MIQDAD", "Gents", code, teacher, new DateTime(2025, 9, 1, 0, 0, 0, DateTimeKind.Unspecified), 2025, 44, Sunday, Sunday.AddDays(6), conducted, null, null, null, attendance, registered, extra, null);

    [TestCase(66.666, 67)]
    [TestCase(12.5, 13)]
    [TestCase(-12.5, -13)]
    [TestCase(0.4, 0)]
    [TestCase(999.4, 999)]
    [TestCase(999.5, 0)]
    [TestCase(10000.0, 0)]
    [TestCase(-1000.0, 0)]
    public void A_percentage_is_rounded_half_away_from_zero_and_a_thousand_or_more_is_zero_because_PHP_number_format_writes_a_comma(double value, int expected) =>
        Assert.That(ConductionReport.Percent(value), Is.EqualTo(expected));

    [Test]
    public void A_class_is_summed_over_its_week_rows_in_the_order_it_first_appears()
    {
        var figures = ConductionReport.Summarise(
        [
            RowOf("B-1", "Not Filled", null, 1, 0),
            RowOf("A-1", "Yes", 10, 3, 1),
            RowOf("A-1", "No", 0, 3, 1),
            RowOf("A-1", "Not Filled", null, 3, 1),
            RowOf("A-1", "Yes", 6, 3, 1),
        ]);

        Assert.That(figures.Select(f => f.Class), Is.EqualTo((string[])["B-1", "A-1"]));
        var a = figures[1];
        Assert.That((a.Expected, a.Conducted, a.NotFilled, a.NotConducted, a.Attendance, a.Students), Is.EqualTo((4, 2, 1, 1, 16, 4)));
        Assert.That((a.PercentNotFilled, a.PercentConduction, a.PercentAttendance), Is.EqualTo((25, 67, 200)));
        var b = figures[0];
        Assert.That((b.Expected, b.Conducted, b.NotFilled, b.PercentNotFilled, b.PercentConduction, b.PercentAttendance), Is.EqualTo((1, 0, 1, 100, 0, 0)));
    }

    [Test]
    public void A_class_with_no_students_or_no_held_week_has_no_attendance_percentage_and_no_division_by_zero()
    {
        var figures = ConductionReport.Summarise([RowOf("C-1", "Yes", 5, null, null), RowOf("D-1", "Not Filled", null, 2, 0)]);
        Assert.That(figures[0].Students, Is.EqualTo(0));
        Assert.That(figures[0].PercentAttendance, Is.EqualTo(0));
        Assert.That(figures[1].PercentConduction, Is.EqualTo(0));
    }

    [Test]
    public void The_students_of_a_class_are_those_of_its_first_row_and_a_missing_teacher_stays_missing()
    {
        var figures = ConductionReport.Summarise([RowOf("E-1", "Yes", 2, 1, 1, null), RowOf("E-1", "Yes", 2, 9, 9, null)]);
        Assert.That(figures[0].Students, Is.EqualTo(2));
        Assert.That(figures[0].Teacher, Is.Null);
    }
}
