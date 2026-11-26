using System.Globalization;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.AdminQuizDownload;

// Slice: POST /admin/quiz/download -> read every episode's responses from the quiz's responses sheet and rebuild the participants, the quiz day, the timestamps and the scoreboard. Contract: spec/api.yaml.
// PHP: routes/quiz_admin.php route_admin_quiz_download (:264), QuizAdminModel downloadAll / download / buildScoreboard (models/quizadmin.php:~620, 997-1087). Order: quiz:admin (403); settings loaded (409 "The quiz settings have not been loaded yet. Refresh them first.");
// the lock (409 "Another quiz admin action is running. Try again in a moment."); then per episode 1..total_quizzes the range "Form Responses <i>!<response_range>" of the sheet named by <mode>responses_sheet_id (mode live: no prefix, else "<mode>_"),
// ALL read before anything is written; a failed read (including no credential) is 502 "Episode <i> could not be read from the sheet. Nothing was changed.". A row counts when it has more cells than response_score_column; its token is the cell
// at response_token_column and its score the cell at response_score_column. quiz_day is the number of episodes with at least one row. With quiz day 0 only the participants, the day and the timestamps are saved; otherwise the scoreboard is rebuilt from the
// feasibility rules (domain/QuizEligibility.cs). A Mega quiz honours today_override for its timestamps, a Grand quiz does not. Event: assessment.quiz_state_changed {action: download}.

internal static partial class AdminQuizDownloadSlice
{
    public static IEndpointRouteBuilder MapAdminQuizDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/quiz/download", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        HttpContext context, NpgsqlDataSource source, Permissions permissions, ISheets sheets, TimeProvider clock, ILoggerFactory loggers, CancellationToken ct)
    {
        var (caller, refusal) = await QuizAdmin.GuardAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var settings = await QuizAdmin.SettingsAsync(source, ct);
        if (QuizAdmin.RequireSettings(settings) is { } blocked)
        {
            return blocked;
        }

        await using var tx = await source.BeginAsync(ct);
        if (!await AssessmentLocks.TryTakeAsync(tx, AssessmentLocks.QuizAdmin, ct))
        {
            return QuizAdmin.Busy();
        }

        var log = loggers.CreateLogger("Tsr.Assessment.Api.AdminQuizDownload");
        var (participants, failedEpisode) = await ReadAllAsync(sheets, settings, log, ct);
        if (failedEpisode > 0)
        {
            return Problem.Detail(StatusCodes.Status502BadGateway, $"Episode {failedEpisode} could not be read from the sheet. Nothing was changed.");
        }

        var curTime = settings.IsMega ? QuizAdmin.NowOrOverride(settings, clock) : QuizAdmin.Wall(clock);
        var timestamps = await QuizStateStore.LoadObjectAsync(tx, QuizStateStore.Timestamps, ct);
        timestamps["scoreboard_downloaded_by"] = await QuizAdmin.ActorLabelAsync(tx, caller!, ct);
        timestamps["last_run"] = QuizAdmin.Stamp(curTime);
        var day = participants.Values.Count(rows => rows.Count > 0);
        var summary = new JsonObject();
        foreach (var (episode, rows) in participants)
        {
            summary[episode.ToString(CultureInfo.InvariantCulture)] = new JsonObject { ["submissions"] = rows.Count };
        }

        timestamps["scoreboard_downloaded_at"] = QuizAdmin.Stamp(curTime);
        timestamps["download_summary"] = new JsonObject { ["by_day"] = summary, ["completed_days"] = day, ["total_quizzes"] = settings.TotalQuizzes };
        await QuizStateStore.SaveAsync(tx, QuizStateStore.Participants, ParticipantsDocument(participants), clock, ct);
        await QuizStateStore.SaveAsync(tx, QuizStateStore.QuizDay, JsonValue.Create(day)!, clock, ct);
        if (day > 0)
        {
            var feasibility = await QuizAdmin.FeasibilityAsync(tx, settings, ct);
            timestamps["last_validated"] = QuizAdmin.Stamp(curTime);
            await QuizStateStore.SaveAsync(tx, QuizStateStore.Scoreboard, QuizEligibility.BuildScoreboard(feasibility), clock, ct);
            timestamps["scoreboard_generated_at"] = QuizAdmin.Stamp(curTime);
        }

        await QuizStateStore.SaveAsync(tx, QuizStateStore.Timestamps, timestamps, clock, ct);
        await QuizAdmin.EventAsync(tx, "download", clock, ct);
        await tx.CommitAsync(ct);
        return Results.Json(
            new JsonObject
            {
                ["outcome"] = "complete",
                ["message"] = day > 0 ? $"Downloaded the submissions. Quiz day {day}." : "Downloaded the submissions. No episode has started yet.",
                ["changed"] = true,
                ["quiz_day"] = day,
                ["submissions"] = QuizOverview.SubmissionsPerEpisode(timestamps),
            },
            AssessmentJson.Answers.JsonObject);
    }

    private static JsonObject ParticipantsDocument(IReadOnlyDictionary<int, List<Submission>> participants)
    {
        var document = new JsonObject();
        foreach (var (episode, rows) in participants)
        {
            document[episode.ToString(CultureInfo.InvariantCulture)] = new JsonArray(rows.Select(r => (JsonNode?)new JsonObject { ["token"] = r.Token, ["score"] = r.Score }).ToArray());
        }

        return document;
    }

    /// <summary>Every episode's rows, or the first episode that could not be read (nothing is written until all are read).</summary>
    private static async Task<(IReadOnlyDictionary<int, List<Submission>> Participants, int FailedEpisode)> ReadAllAsync(
        ISheets sheets, QuizSettings settings, ILogger log, CancellationToken ct)
    {
        var prefix = settings.ModePrefix();
        var sheetId = settings.Str(prefix + "responses_sheet_id");
        var tokenColumn = (int)Math.Clamp(settings.Int("response_token_column"), 0, int.MaxValue);
        var scoreColumn = (int)Math.Clamp(settings.Int("response_score_column"), 0, int.MaxValue);
        var participants = new SortedDictionary<int, List<Submission>>();
        for (var episode = 1; episode <= settings.TotalQuizzes; episode++)
        {
            if (string.IsNullOrWhiteSpace(sheetId))
            {
                LogNoSheet(log);
                return (participants, episode);
            }

            try
            {
                var values = await sheets.ReadAsync(sheetId, $"Form Responses {episode}!{settings.Str("response_range")}", ct);
                participants[episode] = values
                    .Where(row => row.Count > scoreColumn)
                    .Select(row => new Submission(tokenColumn < row.Count ? row[tokenColumn] : string.Empty, row[scoreColumn]))
                    .ToList();
            }
            catch (SheetsException e)
            {
                LogReadFailed(log, episode, e.Message);
                return (participants, episode);
            }
        }

        return (participants, 0);
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "Quiz download: no responses sheet is set for this mode")]
    private static partial void LogNoSheet(ILogger logger);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Quiz download: episode {Episode} could not be read: {Reason}")]
    private static partial void LogReadFailed(ILogger logger, int episode, string reason);
}
