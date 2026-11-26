using System.Globalization;
using System.Text;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportConductionAll;

// Slice: GET /reports/conduction/download-all?gender&year&week -> every week's raw rows of the summary window as CSV (level ignored). 404 "No data to download" when there are none. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_conduction_download_all (:166), mis.php conductionDetailsCsv. The file name carries the time (UTC, as PHP's server).

internal static class ReportConductionAllSlice
{
    public static IEndpointRouteBuilder MapReportConductionAll(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/conduction/download-all", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var now = clock.GetUtcNow().UtcDateTime;
        var (report, refusal) = await ConductionReport.OpenAsync(context, db, permissions, caller, DateOnly.FromDateTime(now), ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var csv = ConductionReport.Csv(report!.Rows);
        if (csv is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "No data to download");
        }

        context.Response.Headers.ContentDisposition = "attachment; filename=\"Class_Report_All_" + now.ToString("yyyyMMdd_HHmmss", CultureInfo.InvariantCulture) + ".csv\"";
        return Results.Bytes(Encoding.UTF8.GetBytes(csv), "text/csv;charset=UTF-8");
    }
}
