using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ClassMyScores;

// Slice: GET /classes/{class_id}/my-scores?start_date&end_date -> the quizzes of a class the caller answered, with their score. Contract: spec/api.yaml.
// PHP: routes/mcq.php route_quiz_my_scores (:449), McqModel getStudentScoresByClass (shared query: domain/ScoreRows.cs). Order: quiz-scores:read (no class target: 403), gender (400), a current student of the class (404 "Class not found or not enrolled").
// Body: a bare array, newest attempt first: quizId, quizName, topic, attemptedAt (the last response's time, Y-m-dTH:i:s), score, total (question count), percent (a float; 0.0 with no questions).
// Dates: the bounds apply to each response's own time (see ScoreRows). Exposes only the caller's own figures; no question, option or answer.

internal static class ClassMyScoresSlice
{
    internal sealed record Item(int QuizId, string QuizName, string? Topic, string? AttemptedAt, int Score, int Total, PhpFloat Percent);

    public static IEndpointRouteBuilder MapClassMyScores(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/my-scores", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, AssessmentContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "quiz-scores:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        if (!await QuizAccess.HasNumericGenderAsync(db, caller, ct))
        {
            return Refusals.GenderNotSet();
        }

        var classId = PhpValue.IntOfText(class_id);
        if (!await QuizAccess.IsEnrolledStudentAsync(db, classId, caller.Token, ct))
        {
            return Refusals.ClassNotEnrolled();
        }

        var from = context.Request.Query["start_date"].LastOrDefault();
        var to = context.Request.Query["end_date"].LastOrDefault();
        var rows = await ScoreRows.ForAsync(db, classId, caller.Token, from, to, ct);
        return Results.Json(rows.Select(ToItem).ToList());
    }

    private static Item ToItem(ScoreRows.Row row)
    {
        var score = row.Score ?? 0;
        var percent = row.Total > 0 ? PhpFloat.Round(score * 100m / row.Total, 2) : new PhpFloat(0);
        return new Item(row.QuizId, row.QuizName ?? string.Empty, QuizResult.TextOrNull(row.Topic), QuizAccess.Stamp(row.AttemptedAt), score, row.Total, percent);
    }
}
