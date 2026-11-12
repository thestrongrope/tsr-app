using System.Text;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportMcqSummaryAll;

// Slice: GET /reports/mcq-summary/download-all?gender&from&to&classIds=1,2 -> a row per student of every class in the report (or only the classIds asked for) as CSV, a Score and a Max column for each topic. 404 "No MCQ summary to download" when no student is left.
// PHP: routes/reports.php route_reports_mcq_summary_download_all (:1356), mis.php mcqSummaryCsv (:617). Same guard, gender and dates as the list; a class id outside the caller's reach adds nothing. File "MCQ_summary_<from>_to_<to>.csv". Writes nothing.

internal static class ReportMcqSummaryAllSlice
{
    public static IEndpointRouteBuilder MapReportMcqSummaryAll(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/mcq-summary/download-all", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var (report, refusal) = await McqSummaryReport.OpenAsync(context, db, permissions, caller, today, 0, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var csv = McqSummaryReport.Csv(report!, AskedClassIds.Of(context));
        if (csv is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "No MCQ summary to download");
        }

        // Trimmed: ParseDay accepts a date with a trailing line feed (as PHP) and echoes it; a control character in a header is a 500 from Kestrel.
        context.Response.Headers.ContentDisposition = "attachment; filename=\"MCQ_summary_" + report!.From.Trim() + "_to_" + report.To.Trim() + ".csv\"";
        return Results.Bytes(Encoding.UTF8.GetBytes(csv), "text/csv;charset=UTF-8");
    }
}
