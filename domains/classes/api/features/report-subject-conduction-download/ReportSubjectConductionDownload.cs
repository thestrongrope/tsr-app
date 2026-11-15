using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportSubjectConductionDownload;

// Slice: GET /reports/subject-conduction/download?format=xlsx|pdf&gender&from&to&level&classId -> one row per class and week: Class, Level, Teacher, Week, Held on and the topic of each subject. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_subject_conduction_download (:1100). Order as PHP: format (422, before the sign-in), sign-in, reports:read, months (422), a class asked for that the caller does not reach (403), then the same rows as the screen
// (domain/SubjectConductionReport.cs). No 404: no row is a file with headers only. Title "Subject conduction: Gents|Ladies, <from>[ to <to>]", file "Subject-conduction-Gents|Ladies-<from>[-to-<to>].<format>". Writes nothing.

internal static class ReportSubjectConductionDownloadSlice
{
    private static readonly string[] Headers = ["Class", "Level", "Teacher", "Week", "Held on", "Arabic", "Aqaed", "Ahkam", "Akhlaq", "Other"];

    public static IEndpointRouteBuilder MapReportSubjectConductionDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/subject-conduction/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
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
        var (report, refusal) = await SubjectConductionReport.OpenAsync(context, db, permissions, caller, today, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var gender = report!.Gender == 2 ? "Ladies" : "Gents";
        var sameMonth = report.From == report.To;
        var period = sameMonth ? report.From : report.From + " to " + report.To;
        IReadOnlyList<IReadOnlyList<object?>> rows =
        [
            .. report.Rows.Select(r => (IReadOnlyList<object?>)[r.Class, r.Level, r.Teacher, r.Week, r.HeldOn, r.Arabic, r.Aqaed, r.Ahkam, r.Akhlaq, r.Other]),
        ];
        var filename = "Subject-conduction-" + gender + "-" + report.From + (sameMonth ? string.Empty : "-to-" + report.To);
        return await export.DownloadAsync(format, $"Subject conduction: {gender}, {period}", [new ReportSection(period, Headers, rows)], filename, ct);
    }
}
