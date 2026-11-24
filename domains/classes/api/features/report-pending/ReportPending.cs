using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportPending;

// Slice: GET /reports/pending?gender&from&to&level (months MM-YYYY) -> {gender, from, to, levels, teachers[{teacherToken, teacher, notFilled, mcqPending, classes[{classId, level, class, notFilled, mcqPending, mcqConducted, mcqExpected}]}]}:
// per teacher, the class forms not filled in the months and the standard MCQs a teacher copied but did not conduct, teachers with something pending, most first. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_pending (:835, api_require_pending_report :785). The queries and every rule (scope, forms not filled, MCQ figures, level narrowing, ordering) are domain/PendingReport.cs and PendingRules.cs (shared with the download).

internal static class ReportPendingSlice
{
    internal sealed record Answer(int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<PendingRules.PendingTeacher> Teachers);

    public static IEndpointRouteBuilder MapReportPending(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/pending", HandleAsync).RequireMember(createsMember: true);
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
        var (report, refusal) = await PendingReport.OpenAsync(context, db, permissions, caller, today, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        return Results.Json(new Answer(report!.Gender, report.From, report.To, report.Levels, report.Teachers), ClassesJson.Answers.ReportPending);
    }
}
