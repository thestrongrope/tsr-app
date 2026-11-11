using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportSummaryDownload;

// Slice: GET /reports/summary/download?format=xlsx|pdf&gender&from&to&level -> the screen's figures, a row per class, the subjects as "count (percent%)" (empty for a class with no subject). Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_summary_download (:425). Order as PHP: format (422, before the sign-in), sign-in, reports:read, months (422), then the same classes as the screen (domain/SummaryReport.cs). No 404: no class is a file with headers only.
// Title "Class summary: Gents|Ladies, <from> to <to>", file "Summary-Gents|Ladies-<from>-to-<to>.<format>" (the months are validated MM-YYYY). Writes nothing.

internal static class ReportSummaryDownloadSlice
{
    private static readonly string[] Headers =
    [
        "Class", "Level", "Teacher", "Expected", "Held", "Not filled", "Not held", "Avg students", "% not filled", "% conduction", "% attendance", "Avg minutes",
        "Arabic", "Aqaed", "Ahkam", "Akhlaq", "Other",
    ];

    public static IEndpointRouteBuilder MapReportSummaryDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/summary/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
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
        var (report, refusal) = await SummaryReport.OpenAsync(context, db, permissions, caller, today, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var gender = report!.Gender == 2 ? "Ladies" : "Gents";
        var period = report.From + " to " + report.To;
        IReadOnlyList<IReadOnlyList<object?>> rows = [.. report.Classes.Select(Row)];
        return await export.DownloadAsync(format, $"Class summary: {gender}, {period}", [new ReportSection(period, Headers, rows)], $"Summary-{gender}-{report.From}-to-{report.To}", ct);
    }

    private static IReadOnlyList<object?> Row(SummaryReport.ClassItem c) =>
    [
        c.Class, c.Level, c.Teacher, c.Expected, c.Conducted, c.NotFilled, c.NotConducted, c.AvgStudents, c.PercentNotFilled, c.PercentConduction, c.PercentAttendance, c.AvgDuration,
        .. SubjectCells(c.Subjects),
    ];

    private static string[] SubjectCells(SummaryReport.Subjects? s) => s is null
        ? ["", "", "", "", ""]
        : [Cell(s.Arabic), Cell(s.Aqaed), Cell(s.Ahkam), Cell(s.Akhlaq), Cell(s.Other)];

    private static string Cell(SummaryReport.Subject s) =>
        s.Count.ToString(CultureInfo.InvariantCulture) + " (" + s.Percent.ToString(CultureInfo.InvariantCulture) + "%)";
}
