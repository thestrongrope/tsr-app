using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportSubjectConduction;

// Slice: GET /reports/subject-conduction?gender&from&to&level&classId (months MM-YYYY, default this month) -> per class and week of the months, the date it last met and the topics each subject covered.
// PHP: routes/reports.php route_reports_subject_conduction (:1052, api_require_subject_conduction_report :996). The queries and their rules are domain/SubjectConductionReport.cs (shared with the download).

internal static class ReportSubjectConductionSlice
{
    internal sealed record Answer(
        int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<SubjectConductionReport.Choice> Classes, IReadOnlyList<SubjectConductionReport.RowItem> Rows);

    public static IEndpointRouteBuilder MapReportSubjectConduction(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/subject-conduction", HandleAsync).RequireMember(createsMember: true);
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
        var (report, refusal) = await SubjectConductionReport.OpenAsync(context, db, permissions, caller, today, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        return Results.Json(new Answer(report!.Gender, report.From, report.To, report.Levels, report.Classes, report.Rows), ClassesJson.Answers.ReportSubjectConduction);
    }
}
