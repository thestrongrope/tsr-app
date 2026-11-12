using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageCopy;

// Slice: POST /mcq/manage/{quiz_id}/copy body {targetClassId} -> a copy of the quiz and its questions in another class; 201 {success, id}. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_copy (:369), McqModel copy (:94). Order: caller (401), quiz found and its class active (404), mcqs:copy on the SOURCE class (403 "You do not have permission to copy MCQs between these classes"),
// body (422 "Invalid JSON body"), targetClassId (int) above 0 (422 "targetClassId is required"), target class active (404 "Class not found"), mcqs:copy on the target (the same 403), then ONE transaction.
// Duplicate: a quiz of the TARGET class with the same name AND topic (the columns are case-insensitive; a null topic never matches) is 409 "A quiz with the same name & topic already exists in target class".
// The copy is a draft carrying the source's name, topic and restrict_to_class, a new code (domain/NewQuiz.cs), created_by the caller; mcq_code is NOT copied (so the copy reports do not count it as a standard copy);
// the questions come with their five options and answer but not is_arabic or option_display_order (a new order is made when the copy is published or printed). Event assessment.quiz_created {quizId, classId (the target), token, source: "copy"}.
// DEVIATIONS: PHP checked both permissions a second time inside the model (answered 409 "Not authorized...") and returned "Copy failed: <exception text>" on a database error: not copied (the permissions were just checked, a failure is the host's generic 500).
// The duplicate check is not locked, so two copies at the same moment can both pass, as in PHP. MariaDB's collation also ignored accents; citext only ignores case.

internal static class ManageCopySlice
{
    private const string NotPermittedText = "You do not have permission to copy MCQs between these classes";

    internal sealed record Body(bool Success, int Id);

    internal sealed record QuizCreated(int QuizId, int ClassId, int Token, string Source);

    private sealed record Source(string? Name, string? Topic, int RestrictToClass);

    public static IEndpointRouteBuilder MapManageCopy(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/mcq/manage/{quiz_id}/copy", HandleAsync).RequireMember(createsMember: true);
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

        if (!await ManageAccess.CanAsync(permissions, caller, "mcqs:copy", quiz!.ClassId, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, NotPermittedText);
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var targetId = PhpValue.ToInteger(body!.Get("targetClassId"));
        if (targetId <= 0)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "targetClassId is required");
        }

        var target = await ManageAccess.ActiveClassAsync(db, targetId, ct);
        if (target is null)
        {
            return ManageAccess.ClassNotFound();
        }

        if (!await ManageAccess.CanAsync(permissions, caller, "mcqs:copy", targetId, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, NotPermittedText);
        }

        return await CopyAsync(db, clock, quiz.Id, target.Id, caller.Token, ct);
    }

    private static async Task<IResult> CopyAsync(AssessmentContext db, TimeProvider clock, int quizId, int targetClassId, int token, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var sources = await db.Database
            .SqlQuery<Source>($"""select name::text as "Name", topic::text as "Topic", restrict_to_class::int as "RestrictToClass" from assessment.spot_quizzes where id = {quizId}""")
            .ToListAsync(ct);
        if (sources.Count == 0)
        {
            return Refusals.QuizNotFound();
        }

        var source = sources[0];
        var duplicate = await db.Database
            .SqlQuery<bool>($"""
                select exists (select 1 from assessment.spot_quizzes where class_id = {targetClassId} and name = {source.Name} and topic = {source.Topic}) as "Value"
                """)
            .SingleAsync(ct);
        if (duplicate)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "A quiz with the same name & topic already exists in target class");
        }

        var at = ManageAccess.NowToSecond(clock);
        var id = await NewQuiz.InsertAsync(db, new NewQuiz.Fields(targetClassId, source.Name ?? string.Empty, source.Topic, null, source.RestrictToClass, token), at, ct);
        await db.Database.ExecuteSqlAsync(
            $"""
            insert into assessment.spot_quiz_questions (spot_quiz_id, question, option1, option2, option3, option4, option5, answer, created_at)
            select {id}, question, option1, option2, option3, option4, option5, answer, {at}
            from assessment.spot_quiz_questions where spot_quiz_id = {quizId} order by id
            """,
            ct);
        await Outbox.WriteAsync(db, "assessment.quiz_created", new QuizCreated(id, targetClassId, token, "copy"), clock, ct);
        await transaction.CommitAsync(ct);
        return Results.Json(new Body(true, id), statusCode: StatusCodes.Status201Created);
    }
}
