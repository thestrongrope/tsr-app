using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportPendingDownload;

// Slice: GET /reports/pending/download?format=xlsx|pdf&gender&from&to&level -> a row per pending class, grouped by teacher as the screen lists them. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_pending_download (:877). Order as PHP: format (422, before the sign-in), sign-in, reports:read, months (422), then the same teachers and classes as the screen (domain/PendingReport.cs). No 404: nothing pending is a file with headers only.
// Title "Pending work: Gents|Ladies, <from>[ to <to>]", file "Pending-Gents|Ladies-<from>-to-<to>.<format>" (always with the "-to-", as PHP). Writes nothing.

internal static class ReportPendingDownloadSlice
{
    private static readonly string[] Headers = ["Teacher", "Class", "Level", "Forms not filled", "MCQs pending", "MCQs conducted", "MCQs in the syllabus"];

    public static IEndpointRouteBuilder MapReportPendingDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/pending/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
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
        var (report, refusal) = await PendingReport.OpenAsync(context, db, permissions, caller, today, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var gender = report!.Gender == 2 ? "Ladies" : "Gents";
        var period = report.From == report.To ? report.From : report.From + " to " + report.To;
        IReadOnlyList<IReadOnlyList<object?>> rows =
        [
            .. report.Teachers.SelectMany(t => t.Classes.Select(c =>
                (IReadOnlyList<object?>)[t.Teacher, c.Class, c.Level, c.NotFilled, c.McqPending, c.McqConducted, c.McqExpected])),
        ];
        var heading = "Class forms not filled in " + period + "; MCQs copied but not conducted, as they stand now";
        return await export.DownloadAsync(format, $"Pending work: {gender}, {period}", [new ReportSection(heading, Headers, rows)], $"Pending-{gender}-{report.From}-to-{report.To}", ct);
    }
}
