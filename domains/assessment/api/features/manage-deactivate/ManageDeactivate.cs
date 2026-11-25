using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageDeactivate;

// Slice: POST /mcq/manage/{quiz_id}/deactivate -> deactivate (default) or reactivate a quiz; {success, deactivated, deactivatedAt}. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_deactivate (:349), McqModel deactivate (:576). Order: caller (401), quiz found (404), its class active (404), mcqs:manage on the class (403), body (422 "Invalid JSON body"), then the write.
// The flag: filter_var($body['deactivate'] ?? true, FILTER_VALIDATE_BOOLEAN), so a missing or null value deactivates and anything other than 1, true, on, yes (a number only when it is 1) REACTIVATES ("abc", 2, a list).
// PHP writes: deactivate sets deactivated_at and deactivated_by (not modified_*); reactivate clears both and sets modified_at and modified_by. Both are copied, also on a quiz already in that state (deactivating again moves the time forward).
// Assumption: the event assessment.quiz_deactivated {quizId, classId, token, deactivated} is written only when the state CHANGES (a repeat is a no-op for the event); the row is locked while it is decided.
// "Who did it" is the caller's token (PHP read it from $_SESSION). A draft may be deactivated (PHP does not look at publishing).

internal static class ManageDeactivateSlice
{
    internal sealed record Body(bool Success, bool Deactivated, string? DeactivatedAt);

    internal sealed record QuizDeactivated(int QuizId, int ClassId, int Token, bool Deactivated);

    public static IEndpointRouteBuilder MapManageDeactivate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/mcq/manage/{quiz_id}/deactivate", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string quiz_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
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

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var deactivate = PhpValue.Truthy(body!.Get("deactivate"), whenMissing: true);
        var at = ManageAccess.NowToSecond(clock);
        await SaveAsync(source, clock, quiz, caller.Token, deactivate, at, ct);
        return Results.Json(new Body(true, deactivate, deactivate ? QuizAccess.Stamp(at) : null), AssessmentJson.Answers.ManageDeactivate);
    }

    private static async Task SaveAsync(NpgsqlDataSource source, TimeProvider clock, ManageAccess.QuizRow quiz, int token, bool deactivate, DateTimeOffset at, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        var was = await tx.ListAsync(
            $"""select deactivated_at is not null as "Value" from assessment.spot_quizzes where id = {quiz.Id} for update""",
            row => row.Bool("Value"),
            ct);
        if (was.Count == 0)
        {
            return;
        }

        if (deactivate)
        {
            await tx.ExecuteAsync($"update assessment.spot_quizzes set deactivated_at = {at}, deactivated_by = {token} where id = {quiz.Id}", ct);
        }
        else
        {
            await tx.ExecuteAsync(
                $"update assessment.spot_quizzes set deactivated_at = null, deactivated_by = null, modified_at = {at}, modified_by = {token} where id = {quiz.Id}", ct);
        }

        if (was[0] != deactivate)
        {
            await Outbox.WriteAsync(tx, "assessment.quiz_deactivated", new QuizDeactivated(quiz.Id, quiz.ClassId, token, deactivate), AssessmentJson.Default.QuizDeactivated, clock, ct);
        }

        await tx.CommitAsync(ct);
    }
}
