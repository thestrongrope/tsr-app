using System.Globalization;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.AdminQuizReset;

// Slice: POST /admin/quiz/reset -> delete the cycle's data: the scoreboard, quiz day, timestamps, winners and participants documents. Contract: spec/api.yaml.
// PHP: routes/quiz_admin.php route_admin_quiz_reset (:332), QuizAdminModel deleteAll / archiveWinners / recordReplacedMany (models/quizadmin.php:~360-400). Order: quiz:admin (403), then quiz:reset
// (403 "Deleting all quiz data needs the quiz reset permission."), the lock (409 "Another quiz admin action is running. Try again in a moment."). Every winner about to be deleted (daily and Grand episodes, Mega, TSR Mega) is first appended to
// the replaced-winners record as kind "delete_all" (a Mega entry as a one-element list); that record and the settings survive. All in one transaction, so a failed archive deletes nothing. Event: assessment.quiz_state_changed {action: reset}.

internal static class AdminQuizResetSlice
{
    public static IEndpointRouteBuilder MapAdminQuizReset(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/quiz/reset", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, AssessmentContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var (caller, refusal) = await QuizAdmin.GuardAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        if (!await permissions.CanAsync(caller!, "quiz:reset", AccessTarget.None, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "Deleting all quiz data needs the quiz reset permission.");
        }

        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        if (!await AssessmentLocks.TryTakeAsync(db, AssessmentLocks.QuizAdmin, ct))
        {
            return QuizAdmin.Busy();
        }

        await ArchiveWinnersAsync(db, caller!, clock, ct);
        await QuizStateStore.DeleteAsync(db, QuizStateStore.CycleDocuments, ct);
        await QuizAdmin.EventAsync(db, "reset", clock, ct);
        await transaction.CommitAsync(ct);
        return Results.Json(new JsonObject { ["outcome"] = "complete", ["message"] = "All quiz data was deleted.", ["changed"] = true });
    }

    private static async Task ArchiveWinnersAsync(AssessmentContext db, Caller caller, TimeProvider clock, CancellationToken ct)
    {
        var winners = await QuizStateStore.LoadObjectAsync(db, QuizStateStore.Winners, ct);
        var entries = winners.Where(e => e.Value is JsonArray { Count: > 0 } or JsonObject { Count: > 0 }).ToList();
        if (entries.Count == 0)
        {
            return;
        }

        var at = QuizAdmin.Stamp(QuizAdmin.Wall(clock));
        var actor = await QuizAdmin.ActorLabelAsync(db, caller, ct);
        var record = await QuizStateStore.LoadArrayAsync(db, QuizStateStore.WinnersReplaced, ct);
        foreach (var (key, entry) in entries)
        {
            JsonNode episode = int.TryParse(key, NumberStyles.None, CultureInfo.InvariantCulture, out var number) ? number : key;
            JsonNode kept = entry is JsonObject ? new JsonArray(entry.DeepClone()) : entry!.DeepClone();
            record.Add(new JsonObject { ["at"] = at, ["by"] = actor, ["kind"] = "delete_all", ["episode"] = episode, ["winners"] = kept });
        }

        await QuizStateStore.SaveAsync(db, QuizStateStore.WinnersReplaced, record, clock, ct);
    }
}
