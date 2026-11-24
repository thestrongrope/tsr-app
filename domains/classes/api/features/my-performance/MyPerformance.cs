using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.MyPerformance;

// Slice: GET /classes/{class_id}/my-performance?start_date&end_date -> the caller's attendance and quiz figures in a class. Contract: spec/api.yaml.
// PHP: routes/classes.php route_class_performance (classes.php:477). Guards as my-attendance, with performance:read.
// Deviation: the dates bound the sessions only; PHP also bounds the member's quiz responses by their own time, which assessment's view does not carry.

internal static class MyPerformanceSlice
{
    internal sealed record Body(
        int TotalSessions,
        int AttendedSessions,
        PhpFloat AttendancePercent,
        int TotalRecitation,
        PhpFloat AverageRecitation,
        int QuizzesAttempted,
        PhpFloat QuizAverageScore);

    public static IEndpointRouteBuilder MapMyPerformance(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/my-performance", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "performance:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        if (!await ClassGuards.HasNumericGenderAsync(source, caller, ct))
        {
            return Refusals.GenderNotSet();
        }

        var classId = ClassGuards.IdOf(class_id);
        if (!await ClassGuards.CanViewClassAsync(source, classId, caller.Token, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Class not found or not enrolled");
        }

        var from = context.Request.Query["start_date"].LastOrDefault();
        var to = context.Request.Query["end_date"].LastOrDefault();
        var history = await StudentAttendance.HistoryAsync(source, (int)classId, caller.Token, from, to, ct);
        var summary = StudentAttendance.Summarise(history);
        var quiz = await StudentAttendance.QuizAsync(source, (int)classId, caller.Token, from, to, ct);
        var averageRecitation = summary.AttendedSessions > 0
            ? PhpFloat.Round(summary.TotalRecitation / (decimal)summary.AttendedSessions, 2)
            : new PhpFloat(0);
        return Results.Json(new Body(
            summary.TotalSessions,
            summary.AttendedSessions,
            StudentAttendance.Percent(summary, 2),
            summary.TotalRecitation,
            averageRecitation,
            quiz.QuizzesAttempted,
            new PhpFloat(quiz.AverageScore)), ClassesJson.Answers.MyPerformanceBody);
    }
}
