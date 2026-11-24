using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportStudents;

// Slice: GET /reports/students?gender&from&to (days YYYY-MM-DD, default the last 30 days) -> {gender, from, to, levels, classes[{class, level}], students[{token, name, level, class, sessions, attendance, totalMcqs, mcqAttempted, mcqPerformance,
// recitation, recitationAvg, tsrScore}]}: every student of every class the caller reaches who has an attendance mark in the range, best score first. Level, class and search narrow it in the app. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_students (:528, api_require_students_report :508). The queries and every rule (reach, the figures, PHP's global recitation leaderboard) are domain/StudentsReport.cs and StudentRules.cs (shared with the download);
// the level and class pickers are built here from the students and the level order.

internal static class ReportStudentsSlice
{
    internal sealed record Answer(int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<StudentRules.Pick> Classes, IReadOnlyList<StudentsReport.Student> Students);

    public static IEndpointRouteBuilder MapReportStudents(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/students", HandleAsync).RequireMember(createsMember: true);
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
        var (report, refusal) = await StudentsReport.OpenAsync(context, db, permissions, caller, today, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (levels, classes) = StudentRules.Pickers(report!.Students.Select(s => new StudentRules.Pick(s.Class, s.Level)), await StudentsReport.LevelNamesAsync(db, ct));
        return Results.Json(new Answer(report.Gender, report.From, report.To, levels, classes, report.Students), ClassesJson.Answers.ReportStudents);
    }
}
