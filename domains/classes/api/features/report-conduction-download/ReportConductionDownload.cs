using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportConductionDownload;

// Slice: GET /reports/conduction/download?format=xlsx|pdf&gender&year&week&level -> the screen's figures as a file: the week's rows, then the overall figures per class. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_conduction_download (:126). Order as PHP: format (422, before the sign-in), sign-in, reports:read, year and week (422 "Invalid year or week"), then the same rows and level narrowing as the screen
// (domain/ConductionReport.cs). No 404: an empty week is a file with headers only. Title "Conduction report: Gents|Ladies, week W YYYY", file "Conduction-Gents|Ladies-week-W-YYYY.<format>". The percentages are whole numbers. Writes nothing.

internal static class ReportConductionDownloadSlice
{
    private static readonly string[] WeekHeaders = ["Class", "Level", "Teacher", "Status", "Date", "Present", "Minutes", "Reason"];

    private static readonly string[] OverallHeaders = ["Class", "Level", "Teacher", "Conduction %", "Attendance %", "Held", "Expected", "Not filled", "Not held", "Students"];

    public static IEndpointRouteBuilder MapReportConductionDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/conduction/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, ReportExport export, TimeProvider clock, CancellationToken ct)
    {
        if (!ReportExport.TryGetFormat(context, out var format))
        {
            return ReportExport.FormatRefusal(context)!;
        }

        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var (report, refusal) = await ConductionReport.OpenAsync(context, db, permissions, caller, today, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var shaped = ConductionReport.Shape(report!, ReportScope.LevelOf(context));
        var gender = report!.Gender == 2 ? "Ladies" : "Gents";
        var week = report.Week.ToString(CultureInfo.InvariantCulture);
        var year = report.Year.ToString(CultureInfo.InvariantCulture);
        IReadOnlyList<ReportSection> sections =
        [
            new("Week of " + shaped.WeekOf, WeekHeaders, [.. shaped.LastWeek.Select(WeekRow)]),
            new("Overall, " + shaped.SummaryStart + " to " + shaped.SummaryEnd, OverallHeaders, [.. shaped.Classes.Select(OverallRow)]),
        ];
        return await export.DownloadAsync(format, $"Conduction report: {gender}, week {week} {year}", sections, $"Conduction-{gender}-week-{week}-{year}", ct);
    }

    private static IReadOnlyList<object?> WeekRow(ConductionReport.Row r) =>
        [r.Class, r.Level, r.Teacher, StatusOf(r.Conducted), r.ConductedOn?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), r.Attendance, r.Duration, r.Reason];

    private static IReadOnlyList<object?> OverallRow(ConductionReport.ClassFigures f) =>
        [f.Class, f.Level, f.Teacher, f.PercentConduction, f.PercentAttendance, f.Conducted, f.Expected, f.NotFilled, f.NotConducted, f.Students];

    /// <summary>PHP's <c>$weekStatus</c>; any other word stays as it is.</summary>
    private static string StatusOf(string conducted) => conducted switch
    {
        "Yes" => "Held",
        "No" => "Not held",
        "Not Filled" => "Not filled",
        _ => conducted,
    };
}
