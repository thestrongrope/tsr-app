using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportTsr;

// Slice: GET /reports/tsr?gender&from&to (days YYYY-MM-DD, default the last 14 days) -> {gender, from, to, conduction, mcq, attendance, recitation}, each with `levels` (one row per level) and `classes` (one row per class): the share of classes that held a
// session or set an MCQ, the last day of each, their attendance and their Quran recitation. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_tsr (:611, api_require_tsr_report :584). The eight queries and every rule (reach, levels of every gender, closed classes in the recitation list, ties) are domain/TsrReport.cs and TsrRules.cs (shared with the download).

internal static class ReportTsrSlice
{
    public static IEndpointRouteBuilder MapReportTsr(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/tsr", HandleAsync).RequireMember(createsMember: true);
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
        var (report, refusal) = await TsrReport.OpenAsync(context, db, permissions, caller, today, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        return Results.Json(report, ClassesJson.Answers.ReportTsr);
    }
}
