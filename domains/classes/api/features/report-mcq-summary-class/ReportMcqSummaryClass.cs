using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportMcqSummaryClass;

// Slice: GET /reports/mcq-summary/{class_id}?gender&from&to -> {mcqs, maxMarks, students[{name, attempted, pending, correct, percent|null, topics[{topic, max, correct|null}]}]}: one class's students as the web page's table. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_mcq_summary_class (:1367), api_reports_mcq_summary_class (:1313). Same guard, gender and dates as the list. A class that published no MCQ in the range, one the caller does not reach and one of the other gender answer as a class with no students (no 404).
// QUIRK copied: {class_id} is cast as PHP's (int); 0 or a word means no narrowing, so the answer is the FIRST class of the whole report (domain/McqSummaryReport.cs).

internal static class ReportMcqSummaryClassSlice
{
    public static IEndpointRouteBuilder MapReportMcqSummaryClass(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/mcq-summary/{class_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
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

        return Results.Json(McqSummaryReport.Body(report!));
    }
}
