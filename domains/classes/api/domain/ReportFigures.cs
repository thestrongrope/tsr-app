namespace Tsr.Classes.Api.Domain;

/// <summary>The arithmetic several reports share: MariaDB's decimal division and PHP's whole percent of a fraction.</summary>
internal static class ReportFigures
{
    /// <summary>MariaDB's <c>number / divisor</c> on decimals: four decimals, rounded half up; a zero divisor is 0 (the SQL cases guard it).</summary>
    public static decimal Quotient(decimal number, decimal divisor) =>
        divisor == 0 ? 0 : Math.Round(number / divisor, 4, MidpointRounding.AwayFromZero);

    /// <summary>PHP <c>(int) round((float) $fraction * 100)</c>: half away from zero on the float; no figure is 0.</summary>
    public static int WholePercent(decimal? fraction) =>
        fraction is null ? 0 : (int)Math.Round((double)fraction.Value * 100, MidpointRounding.AwayFromZero);
}
