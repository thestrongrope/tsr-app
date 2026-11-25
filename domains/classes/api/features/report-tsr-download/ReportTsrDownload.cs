using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportTsrDownload;

// Slice: GET /reports/tsr/download?format=xlsx|pdf&gender&from&to -> each of the four sections (conduction, MCQ, attendance, recitation) as a table per level and a table of the classes behind it, eight tables in all. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_tsr_download (:742). Order as PHP: format (422, before the sign-in), sign-in, reports:read, dates (422), then the same figures as the screen (domain/TsrReport.cs). No 404. A class that never held a session or set an MCQ
// in the period reads "None in this period". Title "TSR at a glance: Gents|Ladies, <from> to <to>", file "TSR-Gents|Ladies-<from>-to-<to>.<format>" (the days are validated YYYY-MM-DD). Writes nothing.

internal static class ReportTsrDownloadSlice
{
    private const string NeverHeld = "None in this period";

    public static IEndpointRouteBuilder MapReportTsrDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/tsr/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource db, Permissions permissions, ReportExport export, TimeProvider clock, CancellationToken ct)
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
        var (report, refusal) = await TsrReport.OpenAsync(context, db, permissions, caller, today, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var gender = report!.Gender == 2 ? "Ladies" : "Gents";
        var period = report.From + " to " + report.To;
        return await export.DownloadAsync(format, $"TSR at a glance: {gender}, {period}", Sections(report), $"TSR-{gender}-{report.From}-to-{report.To}", ct);
    }

    private static List<ReportSection> Sections(TsrReport.Answer report) =>
    [
        Table("Class conduction", ["Level", "Held", "Classes", "%"], report.Conduction.Levels.Select(Counts)),
        Table("Class conduction: classes", ["Level", "Class", "Teacher", "Last held"], report.Conduction.Classes.Select(Last)),
        Table("MCQ conduction", ["Level", "Set an MCQ", "Classes", "%"], report.Mcq.Levels.Select(Counts)),
        Table("MCQ conduction: classes", ["Level", "Class", "Teacher", "Last MCQ"], report.Mcq.Classes.Select(Last)),
        Table("Attendance", ["Level", "Attendance %"], report.Attendance.Levels.Select(l => (IReadOnlyList<object?>)[l.Level, l.Percent])),
        Table("Attendance: classes", ["Level", "Class", "Teacher", "Attendance %"], report.Attendance.Classes.Select(c => (IReadOnlyList<object?>)[c.Level, c.Class, c.Teacher, c.Percent])),
        Table("Recitation", ["Level", "Recitation"], report.Recitation.Levels.Select(l => (IReadOnlyList<object?>)[l.Level, l.Total])),
        Table("Recitation: classes", ["Level", "Class", "Teacher", "Recitation"], report.Recitation.Classes.Select(c => (IReadOnlyList<object?>)[c.Level, c.Class, c.Teacher, c.Total])),
    ];

    private static ReportSection Table(string heading, string[] headers, IEnumerable<IReadOnlyList<object?>> rows) => new(heading, headers, [.. rows]);

    private static IReadOnlyList<object?> Counts(TsrReport.CountsLevel l) => [l.Level, l.Conducted, l.Total, l.Percent.Value];

    private static IReadOnlyList<object?> Last(TsrReport.LastClass c) =>
        [c.Level, c.Class, c.Teacher, string.IsNullOrEmpty(c.LastConducted) ? NeverHeld : c.LastConducted];
}
