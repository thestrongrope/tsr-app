using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageStandardCopy;

// Slice: POST /classes/{class_id}/mcq/standard/{mcq_id}/copy -> a new quiz in the class made from a standard MCQ and its questions; 201 {success, id}. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_standard_copy (:658), McqModel standardMcqExists (:1233), copyStandardQuiz (:1240). Order: caller (401), class found and active (404 "Class not found"), mcqs:manage on the TARGET class only (403),
// standard MCQ found (404 "Standard MCQ not found"; PHP does not look at deleted_at, nor at level, language or whether it has questions), then the copy.
// The quiz: mcq_code = the standard's code (the column the copy reports read), name "subject - lesson - name", the class, the standard's topic, restrict_to_class 1, created_by the caller, a draft with a code from domain/NewQuiz.cs.
// Its questions: question, answer, option1, option2, option3 become question, option1, option2, option3, option4 (option5 null, answer 1; so the right answer is option1 as the app expects), in the standard's id order.
// NO duplicate rule (a second copy into the same class is accepted, as in PHP; the manage list then multiplies the question count, see the A2 notes).
// DEVIATIONS: ONE transaction with database-made ids (PHP ran raw statements with no transaction and attached the questions to MAX(id) of the whole table, a race that could put them on another class's quiz);
// the name and the topic are cut to the 300 characters of their columns (the parts can total 1100 characters; PHP's non-strict database cut them too). One outbox row assessment.quiz_created {quizId, classId, token, source: "standard"}.

internal static class ManageStandardCopySlice
{
    internal sealed record Body(bool Success, int Id);

    internal sealed record QuizCreated(int QuizId, int ClassId, int Token, string Source);

    private sealed record Standard(string Code, string Name, string? Topic);

    public static IEndpointRouteBuilder MapManageStandardCopy(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/{class_id}/mcq/standard/{mcq_id}/copy", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, string mcq_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var classId = PhpValue.IntOfText(class_id);
        var target = await ManageAccess.ActiveClassAsync(source, classId, ct);
        if (target is null)
        {
            return ManageAccess.ClassNotFound();
        }

        if (!await ManageAccess.CanAsync(permissions, caller, "mcqs:manage", classId, ct))
        {
            return ManageAccess.NotPermitted();
        }

        var mcqId = PhpValue.IntOfText(mcq_id);
        var standards = await source.ListAsync(
            $"""
                select code::text as "Code", left(subject::text || ' - ' || lesson::text || ' - ' || name::text, 300) as "Name", left(topic::text, 300) as "Topic"
                from assessment.standard_mcqs where id = {mcqId} limit 1
                """,
            row => new Standard(row.Text("Code"), row.Text("Name"), row.TextOrNull("Topic")),
            ct);
        if (standards.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Standard MCQ not found");
        }

        var standard = standards[0];
        var at = ManageAccess.NowToSecond(clock);
        await using var tx = await source.BeginAsync(ct);
        var id = await NewQuiz.InsertAsync(tx, new NewQuiz.Fields(target.Id, standard.Name, standard.Topic, standard.Code, 1, caller.Token), at, ct);
        await tx.ExecuteAsync(
            $"""
            insert into assessment.spot_quiz_questions (spot_quiz_id, question, option1, option2, option3, option4, option5, answer, created_at)
            select {id}, question, answer, option1, option2, option3, null, 1, {at}
            from assessment.standard_mcq_questions where mcq_code = {standard.Code}::citext order by id
            """,
            ct);
        await Outbox.WriteAsync(tx, "assessment.quiz_created", new QuizCreated(id, target.Id, caller.Token, "standard"), AssessmentJson.Default.QuizCreatedStandard, clock, ct);
        await tx.CommitAsync(ct);
        return Results.Json(new Body(true, id), AssessmentJson.Answers.ManageStandardCopy, contentType: null, statusCode: StatusCodes.Status201Created);
    }
}
