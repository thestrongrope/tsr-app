using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageCreate;

// Slice: POST /classes/{class_id}/mcq -> a new, empty quiz (a draft with no questions); 201 {id}. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_create (:118), McqModel insertQuiz (:658). Order: caller (401), class found and active (404 "Class not found"), mcqs:manage on the class (403), body (422 "Invalid JSON body"),
// name then topic (trimmed, required: 422 "name is required", "topic is required"), then ONE transaction: the insert (code from domain/NewQuiz.cs) and one outbox row assessment.quiz_created {quizId, classId, token, source: "new"}.
// restrict_to_class is 0 only when restrictToClass is sent and (int) of it is 0, else 1; created_by is the caller's token.
// Deviations (422): a name or topic over 300 characters or holding a NUL byte (QuizEdit.ParseHeader; PHP would answer 500 on a strict database).

internal static class ManageCreateSlice
{
    internal sealed record Body(int Id);

    internal sealed record QuizCreated(int QuizId, int ClassId, int Token, string Source);

    public static IEndpointRouteBuilder MapManageCreate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/{class_id}/mcq", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
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

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var header = QuizEdit.ParseHeader(body!);
        if (!header.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, header.Error!);
        }

        var restrict = QuizEdit.Restriction(body!.Get("restrictToClass")) ?? 1;
        var fields = new NewQuiz.Fields(target.Id, header.Value.Name, header.Value.Topic, null, restrict, caller.Token);
        await using var tx = await source.BeginAsync(ct);
        var id = await NewQuiz.InsertAsync(tx, fields, ManageAccess.NowToSecond(clock), ct);
        await Outbox.WriteAsync(tx, "assessment.quiz_created", new QuizCreated(id, target.Id, caller.Token, "new"), AssessmentJson.Default.QuizCreatedNew, clock, ct);
        await tx.CommitAsync(ct);
        return Results.Json(new Body(id), AssessmentJson.Answers.ManageCreate, contentType: null, statusCode: StatusCodes.Status201Created);
    }
}
