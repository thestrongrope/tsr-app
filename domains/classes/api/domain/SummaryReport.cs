using System.Globalization;
using Microsoft.AspNetCore.Http;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// The class summary as data, for the screen (GET /reports/summary) and the download (its /download): per class, over the months, sessions expected (schedule slots in the weeks that are over), held, not filled, not held, averages and the subjects taught.
/// PHP: routes/reports.php api_require_summary_report (:380), mis.php summary (:917) and summaryReport (every figure a whole number). The figures come from <see cref="SummaryRows"/>.
/// Copied: only classes with a schedule slot in a finished week appear; no 12-month limit (PHP has none here); "from" is required: PHP's default (three months back) is built with strtotime('first day of this'), which is false,
/// so a request with no "from" is always 422 "from and to must be months". The gender and reports:read (403) come first, then the months (422).
/// </summary>
internal static class SummaryReport
{
    internal sealed record Subject(int Count, int Percent);

    internal sealed record Subjects(Subject Arabic, Subject Aqaed, Subject Ahkam, Subject Akhlaq, Subject Other);

    internal sealed record ClassItem(
        int ClassId, string Level, string Class, string? Teacher, int Expected, int Conducted, int NotFilled, int NotConducted, int AvgStudents, int AvgDuration,
        int PercentNotFilled, int PercentConduction, int PercentAttendance, Subjects? Subjects);

    internal sealed record Loaded(int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<ClassItem> Classes);

    public static async Task<(Loaded? Report, IResult? Refusal)> OpenAsync(HttpContext context, NpgsqlDataSource db, Permissions permissions, Caller caller, DateOnly today, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(context);
        var (scope, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return (null, refusal);
        }

        var from = ReportMonths.Param(context, "from") ?? string.Empty;
        var to = ReportMonths.Param(context, "to") ?? today.ToString("MM-yyyy", CultureInfo.InvariantCulture);
        var invalid = ReportMonths.Check(from, to, limitToTwelve: false);
        if (invalid is not null)
        {
            return (null, Problem.Detail(StatusCodes.Status422UnprocessableEntity, invalid));
        }

        var ids = await scope!.ClassIdsAsync(db, 0, ct);
        var rows = await SummaryRows.ForMonthsAsync(db, ids, from, to, today, ct);

        var level = ReportScope.LevelOf(context);
        var classes = rows.Where(r => level.Length == 0 || r.Level == level).Select(ToItem).ToList();
        return (new Loaded(scope.Gender, from, to, [.. rows.Select(r => r.Level).Distinct()], classes), null);
    }

    private static ClassItem ToItem(SummaryRows.Row row)
    {
        var f = SummaryFigures.Of(new SummaryFigures.Sums(
            row.Expected, row.Submitted, row.Conducted, row.Attended, row.Marked, row.DurationCount, row.Duration, row.Arabic, row.Aqaed, row.Ahkam, row.Akhlaq, row.Other));
        var subjects = f.Arabic + f.Aqaed + f.Ahkam + f.Akhlaq + f.Other > 0
            ? new Subjects(new Subject(f.Arabic, f.PercentArabic), new Subject(f.Aqaed, f.PercentAqaed), new Subject(f.Ahkam, f.PercentAhkam), new Subject(f.Akhlaq, f.PercentAkhlaq), new Subject(f.Other, f.PercentOther))
            : null;
        return new ClassItem(
            row.Id, row.Level, row.Class, PhpCast.StrOrNull(row.Teacher), f.Expected, f.Conducted, f.NotFilled, f.NotConducted, f.AvgStudents, f.AvgDuration,
            f.PercentNotFilled, f.PercentConduction, f.PercentAttendance, subjects);
    }
}
