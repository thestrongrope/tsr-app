using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Http;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The winners draw as an action, shared by the generate and regenerate slices (domain/CLAUDE rule 1: shared rules live in domain/). PHP routes/quiz_admin.php api_quiz_draw (:~175) over QuizAdminModel draw and its generate methods
/// (models/quizadmin.php:~640, 1882-2105). Order: quiz:admin (403); body (422 "Invalid JSON body"); kind (422 "Unknown kind."); settings loaded (409); the kind offered by this quiz (404 "This quiz has no <kind> draw."); the lock (409);
/// the draw (<see cref="QuizDraw"/>); a draw that could draw nobody is 409 with the reason and changes nothing. Otherwise the replaced winners are appended to the replaced-winners record, the winners and the timestamps are saved and the event
/// assessment.quiz_state_changed {action: generate|regenerate} is written, all in one transaction. A Grand quiz offers grand; a Mega quiz offers daily, mega and mega_student.
/// </summary>
internal static class QuizDrawFlow
{
    private const int MaxWinnersPerEpisode = 10_000;

    public static async Task<IResult> RunAsync(
        HttpContext context, AssessmentContext db, Permissions permissions, TimeProvider clock, IQuizRandom random, bool reset, CancellationToken ct)
    {
        var (caller, refusal) = await QuizAdmin.GuardAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var kindValue = body!.Get("kind");
        var kind = kindValue.ValueKind == System.Text.Json.JsonValueKind.String ? kindValue.GetString() ?? string.Empty : string.Empty;
        if (kind is not ("daily" or "grand" or "mega" or "mega_student"))
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Unknown kind.");
        }

        var settings = await QuizAdmin.SettingsAsync(db, ct);
        if (QuizAdmin.RequireSettings(settings) is { } blocked)
        {
            return blocked;
        }

        if ((settings.IsMega ? kind == "grand" : kind != "grand"))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, $"This quiz has no {kind} draw.");
        }

        var counts = QuizEligibility.WinnerCounts(settings);
        if (counts.Any(c => c < 0) || counts.Sum(c => (long)c) > MaxWinnersPerEpisode)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "The winner counts in the quiz settings are not usable.");
        }

        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        if (!await AssessmentLocks.TryTakeAsync(db, AssessmentLocks.QuizAdmin, ct))
        {
            return QuizAdmin.Busy();
        }

        var winners = await QuizStateStore.LoadObjectAsync(db, QuizStateStore.Winners, ct);
        var feasibility = await QuizAdmin.FeasibilityAsync(db, settings, ct);
        var info = await QuizAdmin.ParticipantInfoAsync(db, ct);
        var result = kind switch
        {
            "grand" or "daily" => QuizDraw.Episodes(counts, feasibility, winners, await QuizStateStore.LoadQuizDayAsync(db, ct), info, reset, kind == "grand", random),
            "mega" => OverallMega(settings, feasibility, winners, info, reset, random),
            _ => QuizDraw.Mega("mega_student", reset, feasibility.MegaStudent, winners, info, random),
        };
        if (result.Report.Outcome == "blocked")
        {
            return Problem.Detail(StatusCodes.Status409Conflict, result.Report.Message);
        }

        if (result.Report.Changed)
        {
            await SaveAsync(db, caller!, clock, kind, reset, feasibility, result, ct);
            await QuizAdmin.EventAsync(db, reset ? "regenerate" : "generate", clock, ct);
        }

        await transaction.CommitAsync(ct);
        return Results.Json(Answer(result.Report));
    }

    /// <summary>PHP drawOverallMega: offered only once every episode has winners.</summary>
    private static DrawResult OverallMega(QuizSettings settings, Feasibility feasibility, JsonObject winners, IReadOnlyDictionary<int, ParticipantInfo> info, bool reset, IQuizRandom random) =>
        QuizDraw.EpisodesWithWinners(winners) < settings.TotalQuizzes
            ? new DrawResult(QuizDraw.Report([new DrawCell(null, 0, 0, 1)], "the overall Mega winner needs winners for every episode first"), winners, [])
            : QuizDraw.Mega("mega", reset, feasibility.Mega, winners, info, random);

    private static async Task SaveAsync(AssessmentContext db, Caller caller, TimeProvider clock, string kind, bool reset, Feasibility feasibility, DrawResult result, CancellationToken ct)
    {
        var actor = await QuizAdmin.ActorLabelAsync(db, caller, ct);
        var at = QuizAdmin.Stamp(QuizAdmin.Wall(clock));
        if (result.Replaced.Count > 0)
        {
            var record = await QuizStateStore.LoadArrayAsync(db, QuizStateStore.WinnersReplaced, ct);
            foreach (var replaced in result.Replaced)
            {
                record.Add(new JsonObject { ["at"] = at, ["by"] = actor, ["kind"] = replaced.Kind, ["episode"] = replaced.Episode.DeepClone(), ["winners"] = replaced.Winners.DeepClone() });
            }

            await QuizStateStore.SaveAsync(db, QuizStateStore.WinnersReplaced, record, clock, ct);
        }

        var timestamps = await QuizStateStore.LoadObjectAsync(db, QuizStateStore.Timestamps, ct);
        var prefix = kind switch { "mega" => "mega_winner", "mega_student" => "mega_student_winner", _ => "winners" };
        timestamps[prefix + "_generated_at"] = at;
        timestamps[prefix + "_generated_by"] = actor;
        if (kind != "mega_student")
        {
            timestamps["min_score_percent_used"] = feasibility.MinScorePercent;
        }

        if (reset)
        {
            timestamps[prefix + "_reset_at"] = at;
            timestamps[prefix + "_reset_by"] = actor;
        }

        await QuizStateStore.SaveAsync(db, QuizStateStore.Winners, result.Winners, clock, ct);
        await QuizStateStore.SaveAsync(db, QuizStateStore.Timestamps, timestamps, clock, ct);
    }

    /// <summary>The wire shape of a draw report (api_quiz_draw): one row per episode and prize; Mega rows have a null episode and prize 0.</summary>
    private static JsonObject Answer(DrawReport report) => new()
    {
        ["outcome"] = report.Outcome,
        ["message"] = report.Message,
        ["changed"] = report.Changed,
        ["drawn"] = report.Drawn,
        ["missing"] = report.Missing,
        ["episodes"] = new JsonArray(report.Cells.Select(c => (JsonNode?)new JsonObject { ["episode"] = c.Episode, ["prize"] = c.Prize, ["drawn"] = c.Drawn, ["missing"] = c.Missing }).ToArray()),
    };
}
