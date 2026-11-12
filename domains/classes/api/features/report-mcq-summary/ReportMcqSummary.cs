using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportMcqSummary;

// Slice: GET /reports/mcq-summary?gender&from&to (days YYYY-MM-DD, default the last 30 days) -> {gender, from, to, levels[], classes[{classId, class, level, teacher, mcqs, students}]}: a line per class that published MCQs in the range. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_mcq_summary (:1283, guard :1263). Order as PHP: sign-in, reports:read for the gender (403), the dates (422). The queries and rules are domain/McqSummaryReport.cs (shared with the class route, the CSV and the file).
// Copied: `teacher` is null when the class has no teacher name; `levels` lists the levels of the classes in the order they appear; `students` is the number of students listed for the class.

internal static class ReportMcqSummarySlice
{
    internal sealed record Line(int ClassId, string Class, string Level, string? Teacher, int Mcqs, int Students);

    internal sealed record Answer(int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<Line> Classes);

    public static IEndpointRouteBuilder MapReportMcqSummary(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/mcq-summary", HandleAsync).RequireMember(createsMember: true);
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

        var classes = report!.Classes
            .Select(c => new Line(c.Class.Id, c.Class.Code, c.Class.Level, c.Class.TeacherName.Length == 0 ? null : c.Class.TeacherName, c.Quizzes, c.Students.Count))
            .ToList();
        return Results.Json(new Answer(report.Gender, report.From, report.To, [.. classes.Select(c => c.Level).Distinct()], classes));
    }
}
