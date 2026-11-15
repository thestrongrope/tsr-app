using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageUpdate;

// Slice: PUT /mcq/manage/{quiz_id} -> save the quiz's name, topic and restriction and REPLACE its questions; {id, questionCount}. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_update (:193), McqModel update (:682) and addQuestions (:728). Order: caller (401), quiz found (404), its class active (404), mcqs:manage on the class (403), body (422 "Invalid JSON body"),
// the rules of domain/QuizEdit.cs (422: name, topic, each row), then ONE transaction: lock the quiz row and refuse when answered, update the quiz row (modified_by, modified_at; restrict_to_class only when sent), DELETE all its questions, INSERT the new ones, one outbox row.
// The questions are inserted with answer = 1 (the correct option is option1), is_arabic and option_display_order null. The row lock also makes two simultaneous edits run one after the other and a quiz never ends with both sets.
// DEVIATION FROM PHP (owner's decision, 12 Nov 2026): a quiz with at least one answer (a row in spot_quiz_responses or spot_quiz_submissions) is NOT edited: 409 "This quiz has answers and can no longer be edited", no write, no event.
// PHP replaced the questions anyway and orphaned the answers. Order: ... 403, body 422, THEN this 409 (chosen: the check needs the transaction). It runs after the row lock (domain/QuizLock.cs, select ... for update); every answer writer
// takes the same row for share first, so an edit and an answer never interleave. The reset of option_display_order and is_arabic is PHP's.
// Event assessment.quiz_updated {quizId, classId, token} (no text, no answers). PHP answers 500 "Failed to save quiz" when the database fails; here a database failure is the host's generic 500 (the rolled back transaction leaves the quiz as it was).
// Deviations: a text over its column or with a NUL, and more than 500 rows, are 422 (QuizEdit); warnings PHP prints into the body for a wrong JSON type are not printed.

internal static class ManageUpdateSlice
{
    private const string AnsweredText = "This quiz has answers and can no longer be edited";

    internal sealed record Body(int Id, int QuestionCount);

    internal sealed record QuizUpdated(int QuizId, int ClassId, int Token);

    public static IEndpointRouteBuilder MapManageUpdate(this IEndpointRouteBuilder routes)
    {
        routes.MapPut("/mcq/manage/{quiz_id}", HandleAsync).RequireMember(createsMember: true);
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

        var parsed = QuizEdit.Parse(body!);
        if (!parsed.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, parsed.Error!);
        }

        var edit = parsed.Value!;
        return await SaveAsync(db, clock, quiz, caller.Token, edit, ct) switch
        {
            SaveOutcome.Saved => Results.Json(new Body(quiz.Id, edit.QuestionCount)),
            SaveOutcome.Answered => Problem.Detail(StatusCodes.Status409Conflict, AnsweredText),
            _ => Refusals.QuizNotFound(),
        };
    }

    private enum SaveOutcome
    {
        Saved,
        Answered,
        Gone,
    }

    private static async Task<SaveOutcome> SaveAsync(AssessmentContext db, TimeProvider clock, ManageAccess.QuizRow quiz, int token, QuizEdit.Edit edit, CancellationToken ct)
    {
        var at = ManageAccess.NowToSecond(clock);
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var answered = await QuizLock.LockAndCheckAnsweredAsync(db, quiz.Id, ct);
        if (answered is null)
        {
            return SaveOutcome.Gone;
        }

        if (answered.Value)
        {
            return SaveOutcome.Answered;
        }

        var updated = await db.Database.ExecuteSqlAsync(
            $"""
            update assessment.spot_quizzes
            set name = {edit.Name}, topic = {edit.Topic}, restrict_to_class = coalesce({edit.RestrictToClass}::smallint, restrict_to_class), modified_by = {token}, modified_at = {at}
            where id = {quiz.Id}
            """,
            ct);
        if (updated == 0)
        {
            return SaveOutcome.Gone;
        }

        await db.Database.ExecuteSqlAsync($"delete from assessment.spot_quiz_questions where spot_quiz_id = {quiz.Id}", ct);
        foreach (var q in edit.Insert)
        {
            await db.Database.ExecuteSqlAsync(
                $"""
                insert into assessment.spot_quiz_questions (spot_quiz_id, question, option1, option2, option3, option4, option5, answer, created_at)
                values ({quiz.Id}, {q.Text}, {q.Option1}, {q.Option2}, {q.Option3}, {q.Option4}, {q.Option5}, 1, {at})
                """,
                ct);
        }

        await Outbox.WriteAsync(db, "assessment.quiz_updated", new QuizUpdated(quiz.Id, quiz.ClassId, token), clock, ct);
        await transaction.CommitAsync(ct);
        return SaveOutcome.Saved;
    }
}
