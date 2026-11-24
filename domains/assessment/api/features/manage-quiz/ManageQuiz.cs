using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageQuiz;

// Slice: GET /mcq/manage/{quiz_id} -> the quiz and ALL its questions WITH the answer, for the teacher or class admin who edits it. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_get (:146), api_find_mcq_quiz (:60), McqModel get and getQuestions. Order: caller (401), quiz found (404 "Quiz not found"), its class active (404 "Class not found"),
// mcqs:manage on the class (403 "You do not have permission to manage MCQs for this class"), then the read. THE ANSWER KEY IS ON THIS WIRE: it is reached only after that permission check
// (the class teacher, a current class admin student, a super admin); the check is a db test for a plain student, a student and a teacher of another class and a removed class admin.
// The correct answer is the column option1, shown as `answer` (the other options are option2 to option5, as stored; an empty text is null). Questions in id order, at most 5000 (PHP: unbounded).
// topic is null only when the column is null (an empty topic stays ""), unlike the list routes' "empty is null".

internal static class ManageQuizSlice
{
    private const int MaxQuestions = 5000;

    private sealed record Row(int Id, string? Question, string? Option1, string? Option2, string? Option3, string? Option4, string? Option5);

    internal sealed record Body(
        int Id, string Code, string Name, string? Topic, int ClassId, string ClassCode, string ClassName, int RestrictToClass, string? PublishedAt, string? DeactivatedAt, string? Link, IReadOnlyList<QuestionWire> Questions);

    internal sealed record QuestionWire(int Id, string Question, string? Answer, string? Option2, string? Option3, string? Option4, string? Option5);

    public static IEndpointRouteBuilder MapManageQuiz(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/mcq/manage/{quiz_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string quiz_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, IConfiguration configuration, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (quiz, refusal) = await ManageAccess.ResolveQuizAsync(source, PhpValue.IntOfText(quiz_id), ct);
        if (refusal is not null)
        {
            return refusal;
        }

        if (!await ManageAccess.CanAsync(permissions, caller, "mcqs:manage", quiz!.ClassId, ct))
        {
            return ManageAccess.NotPermitted();
        }

        var questions = await source.ListAsync(
            $"""
                select id as "Id", question::text as "Question", option1::text as "Option1", option2::text as "Option2", option3::text as "Option3", option4::text as "Option4", option5::text as "Option5"
                from assessment.spot_quiz_questions where spot_quiz_id = {quiz.Id} order by id limit {MaxQuestions}
                """,
            row => new Row(row.Int("Id"), row.TextOrNull("Question"), row.TextOrNull("Option1"), row.TextOrNull("Option2"), row.TextOrNull("Option3"), row.TextOrNull("Option4"), row.TextOrNull("Option5")),
            ct);
        return Results.Json(new Body(
            quiz.Id, quiz.Code ?? string.Empty, quiz.Name ?? string.Empty, quiz.Topic, quiz.ClassId, quiz.ClassCode ?? string.Empty, quiz.ClassName ?? string.Empty, quiz.RestrictToClass,
            QuizAccess.Stamp(quiz.PublishedAt), QuizAccess.Stamp(quiz.DeactivatedAt), ManageAccess.Link(configuration, quiz.Code, quiz.PublishedAt),
            questions.Select(q => new QuestionWire(q.Id, q.Question ?? string.Empty, QuizResult.TextOrNull(q.Option1), QuizResult.TextOrNull(q.Option2), QuizResult.TextOrNull(q.Option3), QuizResult.TextOrNull(q.Option4), QuizResult.TextOrNull(q.Option5))).ToList()), AssessmentJson.Answers.ManageQuiz);
    }
}
