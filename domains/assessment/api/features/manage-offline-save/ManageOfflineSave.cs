using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageOfflineSave;

// Slice: POST /mcq/manage/{quiz_id}/offline body {students: [{token, correct: [questionId]}]} -> records answers students gave on paper, ALL STUDENTS OR NONE; 200 {saved}. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_offline_save (:463), McqModel saveOfflineBatch (:1348), saveOfflineSubmission (:1438). Order: caller (401), quiz found (404), its class active (404), mcqs:manage on the class (403), body (422 "Invalid JSON body"),
// then the rules of domain/OfflineBatch.cs (422 students / each student; 400 malformed token; 403 "Student N is not enrolled in this class."; 400 "Question N does not belong to this quiz."), then the conflicts, then the write.
// Conflict (PHP's definition): a student of the batch who already has a row in spot_quiz_submissions for this quiz: 409 {detail: "One or more students already have submissions.", conflicts: [token, ...]} in the order sent, nothing written.
// The write is ONE transaction: per student (in the order sent) a submission row and one response row per question of the quiz in id order: is_correct 1 and the response the text of option1 when the question is listed in `correct`, else 0 and no response;
// correct_response is always option1 ('' when it is empty). The right answer comes from the database, never from the caller. Scoring is PHP's: a listed question is correct, whatever its text (the online rule would call a blank answer wrong).
// A student who answered on their phone has responses but no submission row (only this route writes one): the unique index on the responses (domain/DuplicateAnswer.cs) refuses the second set, the transaction rolls back and the answer is 409 {detail}
// with NO conflicts list, as PHP's. A submission found inside the transaction (a race with another offline save) is a 409 with that student in the list. Event (in the same transaction, none on a refusal):
// assessment.offline_answers_recorded {quizId, classId, token, count}: ids and a count only (PHP logged the conflicting tokens; not copied).

internal static class ManageOfflineSaveSlice
{
    private const string ConflictText = "One or more students already have submissions.";

    internal sealed record Body(int Saved);

    internal sealed record OfflineRecorded(int QuizId, int ClassId, int Token, int Count);

    private sealed record Question(int Id, string? Option1);

    private sealed record Conflict(string Detail, IReadOnlyList<int> Conflicts);

    public static IEndpointRouteBuilder MapManageOfflineSave(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/mcq/manage/{quiz_id}/offline", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string quiz_id, HttpContext context, AssessmentContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (quiz, refusal) = await ManageAccess.ResolveQuizAsync(db, PhpValue.IntOfText(quiz_id), ct);
        if (refusal is not null)
        {
            return refusal;
        }

        if (!await ManageAccess.CanAsync(permissions, caller, "mcqs:manage", quiz!.ClassId, ct))
        {
            return ManageAccess.NotPermitted();
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var (entries, readRefusal) = OfflineBatch.Read(body!);
        if (readRefusal is not null)
        {
            return Problem.Detail(readRefusal.Status, readRefusal.Message);
        }

        var questions = await db.Database
            .SqlQuery<Question>($"""select id as "Id", option1::text as "Option1" from assessment.spot_quiz_questions where spot_quiz_id = {quiz.Id} order by id limit 5000""")
            .ToListAsync(ct);
        var enrolled = (await ClassStudents.ListAsync(db, quiz.ClassId, ct)).Select(s => (long)s.Token).ToHashSet();
        var (students, planRefusal) = OfflineBatch.Plan(entries!, questions.Select(q => (long)q.Id).ToHashSet(), enrolled);
        if (planRefusal is not null)
        {
            return Problem.Detail(planRefusal.Status, planRefusal.Message);
        }

        var tokens = students!.Select(s => s.Token).ToArray();
        var submitted = (await db.Database
            .SqlQuery<int>($"""select distinct token as "Value" from assessment.spot_quiz_submissions where spot_quiz_id = {quiz.Id} and token = any({tokens})""")
            .ToListAsync(ct)).ToHashSet();
        var conflicts = tokens.Where(submitted.Contains).ToList();
        if (conflicts.Count > 0)
        {
            return Conflicts(conflicts);
        }

        return await SaveAsync(db, clock, quiz, caller.Token, questions, students!, ct);
    }

    private static IResult Conflicts(List<int> tokens) =>
        tokens.Count == 0
            ? Problem.Detail(StatusCodes.Status409Conflict, ConflictText)
            : Results.Json(new Conflict(ConflictText, tokens), statusCode: StatusCodes.Status409Conflict);

    private static async Task<IResult> SaveAsync(
        AssessmentContext db, TimeProvider clock, ManageAccess.QuizRow quiz, int token, IReadOnlyList<Question> questions, IReadOnlyList<OfflineBatch.Student> students, CancellationToken ct)
    {
        var at = ManageAccess.NowToSecond(clock);
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        try
        {
            if (!await QuizLock.ShareUnchangedAsync(db, quiz.Id, questions.Select(q => (long)q.Id).ToList(), ct))
            {
                return Problem.Detail(StatusCodes.Status409Conflict, "This quiz was edited while the answers were being entered. Reload it and enter them again");
            }

            foreach (var student in students)
            {
                var already = await db.Database
                    .SqlQuery<int>($"""select id as "Value" from assessment.spot_quiz_submissions where spot_quiz_id = {quiz.Id} and token = {student.Token} limit 1""")
                    .ToListAsync(ct);
                if (already.Count > 0)
                {
                    return Conflicts([student.Token]);
                }

                await WriteStudentAsync(db, quiz.Id, student, questions, at, ct);
            }

            await Outbox.WriteAsync(db, "assessment.offline_answers_recorded", new OfflineRecorded(quiz.Id, quiz.ClassId, token, students.Count), clock, ct);
            await transaction.CommitAsync(ct);
            return Results.Json(new Body(students.Count));
        }
        catch (Exception e) when (DuplicateAnswer.IsViolation(e))
        {
            return Conflicts([]);
        }
    }

    private static async Task WriteStudentAsync(AssessmentContext db, int quizId, OfflineBatch.Student student, IReadOnlyList<Question> questions, DateTimeOffset at, CancellationToken ct)
    {
        await db.Database.ExecuteSqlAsync(
            $"insert into assessment.spot_quiz_submissions (spot_quiz_id, token, created_at, modified_at) values ({quizId}, {student.Token}, {at}, {at})", ct);
        foreach (var question in questions)
        {
            var text = question.Option1 ?? string.Empty;
            var correct = student.Correct.Contains(question.Id);
            string? response = correct ? text : null;
            var flag = correct ? 1 : 0;
            await db.Database.ExecuteSqlAsync(
                $"""
                insert into assessment.spot_quiz_responses (spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct, created_at)
                values ({quizId}, {question.Id}, {student.Token}, {response}, {text}, {flag}::smallint, {at})
                """,
                ct);
        }
    }
}
