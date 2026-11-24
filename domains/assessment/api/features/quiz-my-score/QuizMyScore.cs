using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.QuizMyScore;

// Slice: GET /mcq/quizzes/{quiz_id}/my-score -> the caller's answers to a quiz and the result. Contract: spec/api.yaml.
// PHP: routes/mcq.php route_quiz_my_score (:411), McqModel getStudentResponses. Order: quizzes:take (403), gender (400), visible quiz (404 "Quiz not found"), no response of the caller (404 "No attempt found").
// Exposes: the caller's own answers with the correct text and the flag (the caller has answered, so the key is theirs to see). `selected` is always 0 (the chosen index is not stored). Envelope: domain/QuizResult.cs.
// Row cap: 5000 answers (a quiz has one per question).

internal static class QuizMyScoreSlice
{
    private const int MaxAnswers = 5000;

    private sealed record Row(int QuestionId, string? QuestionText, string? SelectedText, string? CorrectText, int? IsCorrect);

    public static IEndpointRouteBuilder MapQuizMyScore(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/mcq/quizzes/{quiz_id}/my-score", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string quiz_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "quizzes:take", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        if (!await QuizAccess.HasNumericGenderAsync(source, caller, ct))
        {
            return Refusals.GenderNotSet();
        }

        var quizId = PhpValue.IntOfText(quiz_id);
        if (await QuizAccess.VisibleAsync(source, quizId, caller.Token, ct) is null)
        {
            return Refusals.QuizNotFound();
        }

        var total = await QuizAccess.CountQuestionsAsync(source, quizId, ct);
        var rows = await source.ListAsync(
            $"""
                select r.spot_quiz_question_id as "QuestionId", q.question::text as "QuestionText", r.response::text as "SelectedText",
                       r.correct_response::text as "CorrectText", r.is_correct::int as "IsCorrect"
                from assessment.spot_quiz_responses r
                left join assessment.spot_quiz_questions q on q.id = r.spot_quiz_question_id
                where r.spot_quiz_id = {quizId} and r.token = {caller.Token}
                order by r.spot_quiz_question_id
                limit {MaxAnswers}
                """,
            row => new Row(row.Int("QuestionId"), row.TextOrNull("QuestionText"), row.TextOrNull("SelectedText"), row.TextOrNull("CorrectText"), row.IntOrNull("IsCorrect")),
            ct);
        if (rows.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "No attempt found");
        }

        var details = rows
            .Select(r => new QuizResult.Detail(
                r.QuestionId, QuizResult.TextOrNull(r.QuestionText), 0, QuizResult.TextOrNull(r.SelectedText), QuizResult.TextOrNull(r.CorrectText), r.IsCorrect ?? 0))
            .ToList();
        return Results.Json(QuizResult.Of(total, details), AssessmentJson.Answers.QuizResult);
    }
}
