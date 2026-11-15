using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.QuizDetail;

// Slice: GET /mcq/quizzes/{quiz_id} -> one quiz the caller may see, with their own attempt. Contract: spec/api.yaml.
// PHP: routes/mcq.php route_quiz_detail (:196), McqModel getForStudent, getStudentAttempt, countQuestions. Order: quizzes:take (403), gender (400), visible quiz (404 "Quiz not found").
// Visible: published, and the caller is an enrolled student of its class (status A, not removed). A deactivated quiz is visible. Exposes no question and no answer.

internal static class QuizDetailSlice
{
    internal sealed record Body(int Id, string Code, string Name, string? Topic, int ClassId, string? PublishedAt, int QuestionCount, bool Attempted, int? Score);

    public static IEndpointRouteBuilder MapQuizDetail(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/mcq/quizzes/{quiz_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string quiz_id, HttpContext context, AssessmentContext db, Permissions permissions, CancellationToken ct)
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

        if (!await QuizAccess.HasNumericGenderAsync(db, caller, ct))
        {
            return Refusals.GenderNotSet();
        }

        var quizId = PhpValue.IntOfText(quiz_id);
        var quiz = await QuizAccess.VisibleAsync(db, quizId, caller.Token, ct);
        if (quiz is null)
        {
            return Refusals.QuizNotFound();
        }

        var attempt = await QuizAccess.AttemptAsync(db, quizId, caller.Token, ct);
        var questions = await QuizAccess.CountQuestionsAsync(db, quizId, ct);
        return Results.Json(new Body(
            quiz.Id, quiz.Code ?? string.Empty, quiz.Name ?? string.Empty, string.IsNullOrEmpty(quiz.Topic) ? null : quiz.Topic, quiz.ClassId,
            QuizAccess.Stamp(quiz.PublishedAt), questions, attempt.Attempted, attempt.Score));
    }
}
