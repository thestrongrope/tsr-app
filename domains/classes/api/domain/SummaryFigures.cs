namespace Tsr.Classes.Api.Domain;

/// <summary>PHP <c>MisModel::summary</c>'s arithmetic and <c>summaryReport</c>'s rounding: the sums the query returns, as the whole numbers the route sends.</summary>
internal static class SummaryFigures
{
    internal sealed record Sums(int Expected, int Submitted, int Conducted, long Attended, long Marked, int DurationCount, long Duration, int Arabic, int Aqaed, int Ahkam, int Akhlaq, int Other);

    internal sealed record Figures(
        int Expected, int Conducted, int NotFilled, int NotConducted, int AvgStudents, int AvgDuration, int PercentNotFilled, int PercentConduction, int PercentAttendance,
        int Arabic, int Aqaed, int Ahkam, int Akhlaq, int Other, int PercentArabic, int PercentAqaed, int PercentAhkam, int PercentAkhlaq, int PercentOther);

    // MariaDB divides to four decimals (div_precision_increment), rounding half up; the SQL case guards the divisor, so a zero divisor is 0.
    private static decimal Quotient(decimal number, decimal divisor) =>
        divisor == 0 ? 0 : Math.Round(number / divisor, 4, MidpointRounding.AwayFromZero);

    private static int Whole(decimal value) => (int)Math.Round(value, MidpointRounding.AwayFromZero);

    public static Figures Of(Sums sums)
    {
        ArgumentNullException.ThrowIfNull(sums);
        var students = sums.Conducted == 0 ? 0 : Quotient(sums.Attended, sums.Conducted);
        var notFilled = (1 - (sums.Expected == 0 ? 0 : Quotient(sums.Submitted, sums.Expected))) * 100;
        var conduction = (sums.Submitted == 0 ? 0 : Quotient(sums.Conducted, sums.Expected)) * 100;
        var attendance = (sums.Marked == 0 ? 0 : Quotient(sums.Attended, sums.Marked)) * 100;
        var duration = sums.DurationCount == 0 ? 0 : Quotient(sums.Duration, sums.DurationCount);
        return new Figures(
            sums.Expected, sums.Conducted, sums.Expected - sums.Submitted, sums.Submitted - sums.Conducted, Whole(students), Whole(duration),
            Whole(notFilled), Whole(conduction), Whole(attendance),
            sums.Arabic, sums.Aqaed, sums.Ahkam, sums.Akhlaq, sums.Other,
            Share(sums.Arabic, sums.Conducted), Share(sums.Aqaed, sums.Conducted), Share(sums.Ahkam, sums.Conducted), Share(sums.Akhlaq, sums.Conducted), Share(sums.Other, sums.Conducted));
    }

    private static int Share(int count, int conducted) => Whole((conducted == 0 ? 0 : Quotient(count, conducted)) * 100);
}
