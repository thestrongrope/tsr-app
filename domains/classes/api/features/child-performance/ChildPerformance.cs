using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ChildPerformance;

// Slice: GET /me/children/{child_token}/classes/{class_id}/performance?start_date&end_date -> a linked child's attendance and quiz summary. Contract: spec/api.yaml.
// PHP: routes/children.php route_child_performance, GuardiansModel::getChildPerformance. Guards as child-attendance.
// Deviation: the dates bound the sessions only, not the quiz responses (see my-performance).

internal static class ChildPerformanceSlice
{
    internal sealed record Attendance(
        [property: JsonPropertyName("total_sessions")] int TotalSessions,
        [property: JsonPropertyName("attended_sessions")] int AttendedSessions,
        [property: JsonPropertyName("attendance_percentage")] PhpFloat AttendancePercentage,
        [property: JsonPropertyName("total_recitation")] int TotalRecitation);

    internal sealed record Quizzes(
        [property: JsonPropertyName("quizzes_attempted")] int QuizzesAttempted,
        [property: JsonPropertyName("quiz_average_score")] PhpFloat QuizAverageScore);

    internal sealed record Body([property: JsonPropertyName("attendance")] Attendance Attendance, [property: JsonPropertyName("quizzes")] Quizzes Quizzes);

    public static IEndpointRouteBuilder MapChildPerformance(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/me/children/{child_token}/classes/{class_id}/performance", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string child_token, string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "children-performance:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var childToken = ClassGuards.IdOf(child_token);
        var classId = ClassGuards.IdOf(class_id);
        if (!await ChildGuards.IsActiveGuardianAsync(source, caller.Token, childToken, ct)
            || !await ChildGuards.IsChildEnrolledAsync(source, childToken, classId, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Child or class not found");
        }

        var from = context.Request.Query["start_date"].LastOrDefault();
        var to = context.Request.Query["end_date"].LastOrDefault();
        var history = await StudentAttendance.HistoryAsync(source, (int)classId, (int)childToken, from, to, ct);
        var summary = StudentAttendance.Summarise(history);
        var quiz = await StudentAttendance.QuizAsync(source, (int)classId, (int)childToken, from, to, ct);
        return Results.Json(new Body(
            new Attendance(summary.TotalSessions, summary.AttendedSessions, StudentAttendance.Percent(summary, 1), summary.TotalRecitation),
            new Quizzes(quiz.QuizzesAttempted, PhpFloat.Round((decimal)quiz.AverageScore, 1))), ClassesJson.Answers.ChildPerformanceBody);
    }
}
