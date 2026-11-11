using Tsr.Classes.Api.Domain;

namespace Tsr.Classes.Api.Features.ReportTsr;

/// <summary>PHP <c>MisModel::tsrPercent</c> and the rounding and ordering of <c>tsrSummaryReport</c>: the arithmetic and the list orders of TSR at a glance.</summary>
internal static class TsrRules
{
    /// <summary>The share of classes that held a session (or set an MCQ), to one decimal, a float; 0 for no classes. PHP <c>round(($conducted / $total) * 100, 1)</c>.</summary>
    public static PhpFloat Percent(int conducted, int total) =>
        total > 0 ? PhpFloat.Round((decimal)conducted * 100 / total, 1) : new PhpFloat(0);

    /// <summary>A level's attendance: MariaDB's <c>avg</c> of the classes' quotients (eight decimals, half up), then the whole percent; no class with a figure is 0.</summary>
    public static int LevelAttendance(decimal quotientSum, int classes) =>
        classes == 0 ? 0 : ReportFigures.WholePercent(Math.Round(quotientSum / classes, 8, MidpointRounding.AwayFromZero));

    /// <summary>The classes by their last day, newest first, classes with none last, equal ones by code (PHP leaves ties to the database; its grouping order is by code).</summary>
    public static List<T> NewestFirst<T>(IEnumerable<T> items, Func<T, string?> last, Func<T, string> code)
    {
        ArgumentNullException.ThrowIfNull(items);
        ArgumentNullException.ThrowIfNull(last);
        ArgumentNullException.ThrowIfNull(code);
        return [.. items.OrderBy(i => last(i) is null).ThenByDescending(i => last(i), StringComparer.Ordinal).ThenBy(code, StringComparer.Ordinal)];
    }

    /// <summary>The classes by attendance quotient, highest first, classes with none last, equal ones by code.</summary>
    public static List<T> HighestFirst<T>(IEnumerable<T> items, Func<T, decimal?> quotient, Func<T, string> code)
    {
        ArgumentNullException.ThrowIfNull(items);
        ArgumentNullException.ThrowIfNull(quotient);
        ArgumentNullException.ThrowIfNull(code);
        return [.. items.OrderBy(i => quotient(i) is null).ThenByDescending(i => quotient(i)).ThenBy(code, StringComparer.Ordinal)];
    }
}
