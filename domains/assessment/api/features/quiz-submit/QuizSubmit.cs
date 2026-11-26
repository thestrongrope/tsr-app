using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.QuizSubmit;

// Slice: POST /mcq/quizzes/{quiz_id}/responses -> score the caller's answers on the server and store them (200 with the result). Contract: spec/api.yaml.
// PHP: routes/mcq.php route_quiz_submit (:283), McqModel scoreResponse, correctAnswerFor, saveStudentResponses. Order: quizzes:take (403), gender (400), any response of the caller (409 "Already attempted"), visible (404 "Quiz not found"),
// deactivated (409 "This quiz is not currently available"), no questions (400 "Quiz has no questions"), body (422 "Invalid JSON body"), responses missing or empty (400 "Payload requires non-empty responses"),
// ids missing or not in the quiz (400 with detail {missing, extra}: missing in question order, extra in the order sent), then the write.
// Scoring (domain/QuizRules.cs): the selected TEXT against option{answer}, trimmed and case-folded. The write: one transaction, one row per question in question-id order (so two simultaneous submits wait on the same first row, never deadlock),
// and one outbox row assessment.quiz_answered {quizId, classId, token} (never the answers). The "already answered" rule holds under two simultaneous submissions through the unique index
// spot_quiz_responses_question_token: the loser's insert fails, its transaction rolls back (no rows, no event) and it answers 409 "You have already submitted this quiz".
// Deviations: a NUL in selectedText is dropped (PostgreSQL text cannot hold it); a selectedText over 1000 characters is 400 "selectedText is too long" (PHP: 500 "Failed to save responses"); an array selectedText is stored as "Array" without PHP's warning text in the body.
// Row cap: 5000 questions.

internal static class QuizSubmitSlice
{
    private const int MaxQuestions = 5000;
    private const int MaxTextLength = 1000;

    internal sealed record Answered(int QuizId, int ClassId, int Token);

    private sealed record Question(int Id, string? Text, string? Option1, string? Option2, string? Option3, string? Option4, string? Option5, int? Answer);

    private sealed record Scored(Question Question, string Correct, AnswerBody.Answer Answer, bool IsCorrect);

    public static IEndpointRouteBuilder MapQuizSubmit(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/mcq/quizzes/{quiz_id}/responses", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string quiz_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
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
        if ((await QuizAccess.AttemptAsync(source, quizId, caller.Token, ct)).Attempted)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "Already attempted");
        }

        var quiz = await QuizAccess.VisibleAsync(source, quizId, caller.Token, ct);
        if (quiz is null)
        {
            return Refusals.QuizNotFound();
        }

        if (quiz.DeactivatedAt is not null)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "This quiz is not currently available");
        }

        var questions = await LoadQuestionsAsync(source, quizId, ct);
        if (questions.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status400BadRequest, "Quiz has no questions");
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var answers = AnswerBody.Parse(body!);
        if (answers is null)
        {
            return Problem.Detail(StatusCodes.Status400BadRequest, "Payload requires non-empty responses");
        }

        var expected = questions.Select(q => (long)q.Id).ToList();
        var missing = expected.Where(id => answers.All(a => a.QuestionId != id)).ToList();
        var extra = answers.Select(a => a.QuestionId).Where(id => !expected.Contains(id)).ToList();
        if (missing.Count > 0 || extra.Count > 0)
        {
            return Results.Json(new AnswerMismatch(new AnswerMismatch.Ids(missing, extra)), AssessmentJson.Answers.AnswerMismatch, contentType: null, statusCode: StatusCodes.Status400BadRequest);
        }

        if (answers.Any(a => a.SelectedText is not null && PhpText.CodePointCount(a.SelectedText) > MaxTextLength))
        {
            return Problem.Detail(StatusCodes.Status400BadRequest, "selectedText is too long");
        }

        var byId = answers.ToDictionary(a => a.QuestionId);
        var scored = questions.Select(q => Score(q, byId[q.Id])).ToList();
        var saved = await SaveAsync(source, clock, quizId, quiz.ClassId, caller.Token, scored, ct);
        if (saved == SaveOutcome.QuizChanged)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "This quiz was edited while you were answering it. Reload it and answer again");
        }

        if (saved == SaveOutcome.AlreadyAnswered)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "You have already submitted this quiz");
        }

        var details = scored
            .Select(s => new QuizResult.Detail(
                s.Question.Id, QuizResult.TextOrNull(s.Question.Text), s.Answer.Selected, QuizResult.TextOrNull(s.Answer.SelectedText), QuizResult.TextOrNull(s.Correct), s.IsCorrect ? 1 : 0))
            .ToList();
        return Results.Json(QuizResult.Of(questions.Count, details), AssessmentJson.Answers.QuizResult);
    }

    private static async Task<List<Question>> LoadQuestionsAsync(NpgsqlDataSource source, long quizId, CancellationToken ct) =>
        await source.ListAsync(
            $"""
                select id as "Id", question::text as "Text", option1::text as "Option1", option2::text as "Option2", option3::text as "Option3",
                       option4::text as "Option4", option5::text as "Option5", answer as "Answer"
                from assessment.spot_quiz_questions where spot_quiz_id = {quizId} order by id limit {MaxQuestions}
                """,
            row => new Question(
                row.Int("Id"), row.TextOrNull("Text"), row.TextOrNull("Option1"), row.TextOrNull("Option2"), row.TextOrNull("Option3"), row.TextOrNull("Option4"),
                row.TextOrNull("Option5"), row.IntOrNull("Answer")),
            ct);

    private static Scored Score(Question question, AnswerBody.Answer answer)
    {
        var correct = QuizRules.CorrectAnswerFor(question.Answer, [question.Option1, question.Option2, question.Option3, question.Option4, question.Option5]);
        return new Scored(question, correct ?? string.Empty, answer, QuizRules.Score(answer.SelectedText, correct));
    }

    private enum SaveOutcome
    {
        Saved,
        AlreadyAnswered,
        QuizChanged,
    }

    /// <summary>One transaction: the quiz row locked for share (an edit of the quiz waits for it, and a quiz edited since the questions were read is refused: QuizChanged), the rows in question order, then the event. AlreadyAnswered when the unique index says the caller already answered (nothing is kept).</summary>
    private static async Task<SaveOutcome> SaveAsync(NpgsqlDataSource source, TimeProvider clock, long quizId, int classId, int token, IReadOnlyList<Scored> scored, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        var at = new DateTimeOffset(now.Year, now.Month, now.Day, now.Hour, now.Minute, now.Second, TimeSpan.Zero);
        await using var tx = await source.BeginAsync(ct);
        try
        {
            if (!await QuizLock.ShareUnchangedAsync(tx, quizId, scored.Select(s => (long)s.Question.Id).ToList(), ct))
            {
                return SaveOutcome.QuizChanged;
            }

            foreach (var s in scored)
            {
                var flag = s.IsCorrect ? 1 : 0;
                await tx.ExecuteAsync(
                    $"""
                    insert into assessment.spot_quiz_responses (spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct, created_at)
                    values ({quizId}, {s.Question.Id}, {token}, {s.Answer.SelectedText}, {s.Correct}, {flag}, {at})
                    """,
                    ct);
            }

            await Outbox.WriteAsync(tx, "assessment.quiz_answered", new Answered((int)quizId, classId, token), AssessmentJson.Default.Answered, clock, ct);
            await tx.CommitAsync(ct);
            return SaveOutcome.Saved;
        }
        catch (Exception e) when (DuplicateAnswer.IsViolation(e))
        {
            return SaveOutcome.AlreadyAnswered;
        }
    }
}
