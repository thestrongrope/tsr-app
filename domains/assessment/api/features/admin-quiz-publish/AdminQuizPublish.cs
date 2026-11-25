using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.AdminQuizPublish;

// Slice: POST /admin/quiz/publish {what: scoreboard|winners|mega|mega_student} -> write the stored scoreboard or winners into the public Google sheet (Mega quizzes only). Contract: spec/api.yaml.
// PHP: routes/quiz_admin.php route_admin_quiz_publish (:302), QuizAdminModel publish / pushScores / pushDailyWinners / pushMegaWinner / pushMegaStudentWinner (models/quizadmin.php:~690, 2108-2290). Order: quiz:admin (403); body (422 "Invalid JSON body");
// what (422 "Unknown target."); settings loaded (409); a Mega quiz (404 "This quiz has nothing to publish from here."); the lock (409). Writes ranges of the spreadsheet named by <mode>scores_sheet_id (mode live: no prefix, else "<mode>_"), values RAW:
// scoreboard: scores_range gets the scoreboard rows, then updatedon_range gets "Last updated on dd-MMMM-yyyy HH:mm AM IST" (24-hour hours as PHP's "H"); winners: winners_range gets one row [episode, label, token, name, city] per drawn winner;
// mega: mega_winner_range gets [MEGA, MEGA, token, name, city] (409 "No overall Mega winner has been drawn yet, so there is nothing to publish." when none); mega_student: the same into mega_student_winner_range, nothing (rows 0, changed false) when that range is not set,
// 409 "No TSR student Mega winner has been drawn yet, so there is nothing to publish." when none. A sheet failure is 502 "The sheet could not be reached. Nothing was changed or published."; a failure of the scoreboard's second write is
// 502 "The scoreboard was published but its \"last updated\" line was not. Publish again to finish.". Only a fully published change saves its timestamp (<what>_updated_at / _by) and writes the event assessment.quiz_state_changed {action: publish}. No other database write.

internal static partial class AdminQuizPublishSlice
{
    private const string Unreachable = "The sheet could not be reached.";
    private const string PartlyDone = "The scoreboard was published but its \"last updated\" line was not. Publish again to finish.";

    private sealed record Written(int Rows, string StampPrefix);

    public static IEndpointRouteBuilder MapAdminQuizPublish(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/quiz/publish", HandleAsync).RequireMember(createsMember: true);
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

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var value = body!.Get("what");
        var what = value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;
        if (what is not ("scoreboard" or "winners" or "mega" or "mega_student"))
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Unknown target.");
        }

        var settings = await QuizAdmin.SettingsAsync(source, ct);
        if (QuizAdmin.RequireSettings(settings) is { } blocked)
        {
            return blocked;
        }

        if (!settings.IsMega)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "This quiz has nothing to publish from here.");
        }

        await using var tx = await source.BeginAsync(ct);
        if (!await AssessmentLocks.TryTakeAsync(tx, AssessmentLocks.QuizAdmin, ct))
        {
            return QuizAdmin.Busy();
        }

        var log = loggers.CreateLogger("Tsr.Assessment.Api.AdminQuizPublish");
        var timestamps = await QuizStateStore.LoadObjectAsync(tx, QuizStateStore.Timestamps, ct);
        var actor = await QuizAdmin.ActorLabelAsync(tx, caller!, ct);
        Written written;
        try
        {
            var result = await PublishAsync(tx, sheets, settings, what, timestamps, actor, clock, ct);
            if (result is { Refusal: { } publishRefusal })
            {
                return publishRefusal;
            }

            written = result.Written!;
        }
        catch (SheetsException e)
        {
            LogSheetFailed(log, e.Message);
            var partly = e.Data.Contains("partly");
            return Problem.Detail(StatusCodes.Status502BadGateway, partly ? PartlyDone : Unreachable + " Nothing was changed or published.");
        }

        // PHP: published is false only for the student winner with no range set; an empty scoreboard or winners list was written (one empty row) and is "Published 0 rows.".
        if (written.Rows == 0 && what == "mega_student")
        {
            return Results.Json(Answer("Nothing was published: the sheet range for this winner is not set in the quiz settings.", changed: false, rows: 0), AssessmentJson.Answers.JsonObject);
        }

        await QuizStateStore.SaveAsync(tx, QuizStateStore.Timestamps, timestamps, clock, ct);
        await QuizAdmin.EventAsync(tx, "publish", clock, ct);
        await tx.CommitAsync(ct);
        return Results.Json(Answer("Published " + written.Rows + (written.Rows == 1 ? " row." : " rows."), changed: true, rows: written.Rows), AssessmentJson.Answers.JsonObject);
    }

    private sealed record Published(Written? Written, IResult? Refusal);

    private static async Task<Published> PublishAsync(
        DbTx tx, ISheets sheets, QuizSettings settings, string what, JsonObject timestamps, string actor, TimeProvider clock, CancellationToken ct)
    {
        var sheetId = settings.Str(settings.ModePrefix() + "scores_sheet_id");
        var winners = await QuizStateStore.LoadObjectAsync(tx, QuizStateStore.Winners, ct);
        if (what == "scoreboard")
        {
            var rows = await PushScoreboardAsync(tx, sheets, settings, sheetId, timestamps, actor, clock, ct);
            return new Published(new Written(rows, "scoreboard_updated"), null);
        }

        if (what == "winners")
        {
            var rows = DailyWinnerRows(winners, settings);
            await WriteAsync(sheets, sheetId, settings.Str("winners_range"), rows, partly: false, ct);
            Stamp(timestamps, "winners_updated", actor, clock);
            return new Published(new Written(rows.Count, "winners_updated"), null);
        }

        return await PushMegaAsync(sheets, settings, sheetId, winners, what, timestamps, actor, clock, ct);
    }

    private static async Task<Published> PushMegaAsync(
        ISheets sheets, QuizSettings settings, string? sheetId, JsonObject winners, string what, JsonObject timestamps, string actor, TimeProvider clock, CancellationToken ct)
    {
        var student = what == "mega_student";
        var range = student ? (settings.Str("mega_student_winner_range") ?? string.Empty).Trim() : settings.Str("mega_winner_range");
        if (student && range!.Length == 0)
        {
            return new Published(new Written(0, string.Empty), null);
        }

        var winner = winners[student ? "mega_student" : "mega"] as JsonObject;
        if (winner is null || winner.Count == 0)
        {
            var who = student ? "TSR student Mega" : "overall Mega";
            return new Published(null, Problem.Detail(StatusCodes.Status409Conflict, $"No {who} winner has been drawn yet, so there is nothing to publish."));
        }

        var row = new List<IReadOnlyList<object?>> { new object?[] { "MEGA", "MEGA", Cell(winner["token"]), Cell(winner["name"]), Cell(winner["city"]) } };
        await WriteAsync(sheets, sheetId, range, row, partly: false, ct);
        var prefix = student ? "mega_student_winner_updated" : "mega_winner_updated";
        Stamp(timestamps, prefix, actor, clock);
        return new Published(new Written(1, prefix), null);
    }

    private static async Task<int> PushScoreboardAsync(
        DbTx tx, ISheets sheets, QuizSettings settings, string? sheetId, JsonObject timestamps, string actor, TimeProvider clock, CancellationToken ct)
    {
        var curTime = QuizAdmin.NowOrOverride(settings, clock);
        timestamps["scoreboard_updated_by"] = actor;
        var scoreboard = await QuizStateStore.LoadArrayAsync(tx, QuizStateStore.Scoreboard, ct);
        timestamps["scoreboard_generated_at"] = QuizAdmin.Stamp(curTime);
        var rows = scoreboard.OfType<JsonArray>().Select(r => (IReadOnlyList<object?>)r.Select(Cell).ToList()).ToList();
        await WriteAsync(sheets, sheetId, settings.Str("scores_range"), rows, partly: false, ct);
        var updatedOn = "Last updated on " + curTime.ToString("dd-MMMM-yyyy HH:mm tt", CultureInfo.InvariantCulture) + " IST";
        await WriteAsync(sheets, sheetId, settings.Str("updatedon_range"), [[updatedOn]], partly: true, ct);
        timestamps["scoreboard_updated_at"] = QuizAdmin.Stamp(curTime);
        return scoreboard.Count;
    }

    /// <summary>PHP pushDailyWinners: [episode, label, token, name, city] for every drawn winner with a token; the label is the prize's entry of winner_labels (not trimmed).</summary>
    private static List<IReadOnlyList<object?>> DailyWinnerRows(JsonObject winners, QuizSettings settings)
    {
        var labels = (settings.Str("winner_labels") ?? string.Empty).Split(',');
        var rows = new List<IReadOnlyList<object?>>();
        foreach (var winner in winners.Select(e => e.Value).OfType<JsonArray>().SelectMany(list => list.OfType<JsonObject>()))
        {
            var token = Cell(winner["token"]);
            var prize = (int)Math.Clamp(PhpValue.IntOfText(QuizOverview.Text(winner["prize"]) ?? string.Empty), int.MinValue, int.MaxValue);
            if (token is null or 0L)
            {
                continue;
            }

            rows.Add(new object?[] { Cell(winner["episode"]), prize >= 1 && prize <= labels.Length ? labels[prize - 1] : null, token, Cell(winner["name"]), Cell(winner["city"]) });
        }

        return rows;
    }

    private static async Task WriteAsync(ISheets sheets, string? sheetId, string? range, List<IReadOnlyList<object?>> rows, bool partly, CancellationToken ct)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(sheetId) || string.IsNullOrWhiteSpace(range))
            {
                throw new SheetsException("The sheet or the range is not set in the quiz settings");
            }

            if (rows.Count == 0)
            {
                rows.Add([]);
            }

            await sheets.WriteAsync(sheetId, range, rows, ct);
        }
        catch (SheetsException e) when (partly)
        {
            e.Data["partly"] = true;
            throw;
        }
    }

    private static void Stamp(JsonObject timestamps, string prefix, string actor, TimeProvider clock)
    {
        timestamps[prefix + "_at"] = QuizAdmin.Stamp(QuizAdmin.Wall(clock));
        timestamps[prefix + "_by"] = actor;
    }

    /// <summary>A JSON value as a sheet cell: text stays text, a whole number a number, null null.</summary>
    private static object? Cell(JsonNode? node) => node is not JsonValue value
        ? null
        : value.TryGetValue<string>(out var text) ? text : value.TryGetValue<long>(out var number) ? number : value.ToJsonString();

    private static JsonObject Answer(string message, bool changed, int rows) => new()
    {
        ["outcome"] = "complete",
        ["message"] = message,
        ["changed"] = changed,
        ["rows"] = rows,
    };

    [LoggerMessage(Level = LogLevel.Warning, Message = "Quiz publish: sheet write failed: {Reason}")]
    private static partial void LogSheetFailed(ILogger logger, string reason);
}
