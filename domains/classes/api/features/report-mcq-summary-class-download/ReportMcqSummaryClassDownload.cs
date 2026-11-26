using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportMcqSummaryClassDownload;

// Slice: GET /reports/mcq-summary/{class_id}/download?format=xlsx|pdf&gender&from&to -> the class's students in the screen's columns (Name, Attempted, Pending, Score), a column per topic after them. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_mcq_summary_class_download (:1379). Order as PHP: format (422, before the sign-in), sign-in, reports:read, dates (422), then the same class as the class route (domain/McqSummaryReport.cs, including the {class_id} 0 quirk).
// Cells are text as PHP's: "attempted / mcqs", the pending count, "correct / max (percent%)" or "-", "correct / max" or "-" per topic. Title "MCQ summary: <from> to <to>", file "MCQ-summary-<class_id>-<from>-to-<to>.<format>" (the id as written in the path, cut to safe characters). No 404. Writes nothing.

internal static class ReportMcqSummaryClassDownloadSlice
{
    private static readonly string[] BaseHeaders = ["Name", "Attempted", "Pending", "Score"];

    public static IEndpointRouteBuilder MapReportMcqSummaryClassDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/mcq-summary/{class_id}/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource db, Permissions permissions, ReportExport export, TimeProvider clock, CancellationToken ct)
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
        var (report, refusal) = await McqSummaryReport.OpenAsync(context, db, permissions, caller, today, ClassGuards.IdOf(class_id), ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var body = McqSummaryReport.Body(report!);
        var topics = body.Students.Count == 0 ? [] : body.Students[0].Topics.Select(t => t.Topic);
        IReadOnlyList<IReadOnlyList<object?>> rows = [.. body.Students.Select(s => Row(s, body))];
        var period = report!.From + " to " + report.To;
        string[] headers = [.. BaseHeaders, .. topics];
        return await export.DownloadAsync(format, "MCQ summary: " + period, [new ReportSection(period, headers, rows)], "MCQ-summary-" + class_id + "-" + report.From + "-to-" + report.To, ct);
    }

    private static List<object?> Row(McqSummaryReport.StudentLine s, McqSummaryReport.ClassBody body)
    {
        var score = s.Percent is null ? "-" : Number(s.Correct) + " / " + Number(body.MaxMarks) + " (" + Number(s.Percent.Value) + "%)";
        List<object?> row = [s.Name, Number(s.Attempted) + " / " + Number(body.Mcqs), s.Pending, score];
        row.AddRange(s.Topics.Select(t => t.Correct is null ? "-" : Number(t.Correct.Value) + " / " + Number(t.Max)));
        return row;
    }

    private static string Number(int value) => value.ToString(CultureInfo.InvariantCulture);
}
