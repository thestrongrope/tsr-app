using System.Text;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportMcqAdherenceAll;

// Slice: GET /reports/mcq-adherence/download-all?gender&classIds=1,2 -> a row per standard MCQ of every class in the report (or only the classIds asked for) as CSV. 404 "No MCQ adherence to download" when none is left.
// PHP: routes/reports.php route_reports_mcq_adherence_download_all (:1474), mis.php mcqAdherenceCsv (:658). Same guard and gender as the list; a class id outside the caller's reach adds nothing. File "MCQ_adherence.csv". The Status column is the lower-case word (conducted, pending, skipped);
// Published At is the latest publish time of the class's copy as "yyyy-MM-dd HH:mm:ss" in UTC (assumption: MariaDB gave the server's local text). Writes nothing.

internal static class ReportMcqAdherenceAllSlice
{
    public static IEndpointRouteBuilder MapReportMcqAdherenceAll(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/mcq-adherence/download-all", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (report, refusal) = await McqAdherenceReport.OpenAsync(context, db, permissions, caller, 0, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var csv = await McqAdherenceReport.CsvAsync(db, report!, AskedClassIds.Of(context), ct);
        if (csv is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "No MCQ adherence to download");
        }

        context.Response.Headers.ContentDisposition = "attachment; filename=\"MCQ_adherence.csv\"";
        return Results.Bytes(Encoding.UTF8.GetBytes(csv), "text/csv;charset=UTF-8");
    }
}
