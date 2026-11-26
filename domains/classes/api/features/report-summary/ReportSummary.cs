using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportSummary;

// Slice: GET /reports/summary?gender&from&to&level (months MM-YYYY) -> per class, over the months: sessions expected (schedule slots in the weeks that are over), held, not filled, not held, averages and the subjects taught.
// PHP: routes/reports.php route_reports_summary (:407, api_require_summary_report :380). The queries and their rules (only classes with a schedule slot in a finished week, "from" required, MariaDB to PostgreSQL rounding) are
// domain/SummaryReport.cs and SummaryRows.cs (shared with the download).

internal static class ReportSummarySlice
{
    internal sealed record Answer(int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<SummaryReport.ClassItem> Classes);

    public static IEndpointRouteBuilder MapReportSummary(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/summary", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
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

        return Results.Json(new Answer(report!.Gender, report.From, report.To, report.Levels, report.Classes), ClassesJson.Answers.ReportSummary);
    }
}
