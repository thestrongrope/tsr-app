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
// the rules of domain/QuizEdit.cs (422: name, topic, each row), then ONE transaction: update the quiz row (modified_by, modified_at; restrict_to_class only when sent), DELETE all its questions, INSERT the new ones, one outbox row.
// The questions are inserted with answer = 1 (the correct option is option1), is_arabic and option_display_order null. Updating the quiz row first takes its row lock, so two simultaneous edits run one after the other and a quiz never ends with both sets.
// FLAGGED, COPIED FROM PHP: there is no check for a published quiz or for students' answers. Deleting the questions leaves every stored answer (spot_quiz_responses) pointing at a question id that no longer exists
// (the table has no foreign key, as in PHP): a student who answered keeps their correct flags, but their score is now measured against the NEW question count, their old questions read back with no text, and (when their score is above zero)
// they are still locked out of the new questions. The reset of option_display_order and is_arabic is PHP's too. The only guard here is the permission; the decision to refuse edits of a published quiz is the owner's.
// Event assessment.quiz_updated {quizId, classId, token} (no text, no answers). PHP answers 500 "Failed to save quiz" when the database fails; here a database failure is the host's generic 500 (the rolled back transaction leaves the quiz as it was).
// Deviations: a text over its column or with a NUL, and more than 500 rows, are 422 (QuizEdit); warnings PHP prints into the body for a wrong JSON type are not printed.

internal static class ManageUpdateSlice
{
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
        return await SaveAsync(db, clock, quiz, caller.Token, edit, ct) ? Results.Json(new Body(quiz.Id, edit.QuestionCount)) : Refusals.QuizNotFound();
    }

    private static async Task<bool> SaveAsync(AssessmentContext db, TimeProvider clock, ManageAccess.QuizRow quiz, int token, QuizEdit.Edit edit, CancellationToken ct)
    {
        var at = ManageAccess.NowToSecond(clock);
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var updated = await db.Database.ExecuteSqlAsync(
            $"""
            update assessment.spot_quizzes
            set name = {edit.Name}, topic = {edit.Topic}, restrict_to_class = coalesce({edit.RestrictToClass}::smallint, restrict_to_class), modified_by = {token}, modified_at = {at}
            where id = {quiz.Id}
            """,
            ct);
        if (updated == 0)
        {
            return false;
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
        return true;
    }
}
