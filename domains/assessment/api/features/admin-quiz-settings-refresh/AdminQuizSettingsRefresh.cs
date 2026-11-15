using System.Data.Common;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Notifications.Api;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.AdminQuizSettingsRefresh;

// Slice: POST /admin/quiz/settings/refresh -> read the settings sheet (tabs Technical!A1:B and Functional!A1:D) into the settings document and announce a quiz that just went live. Contract: spec/api.yaml.
// PHP: routes/quiz_admin.php route_admin_quiz_settings_refresh (:241), QuizAdminModel refreshSettings / fetchSettings / announceSwitchOn (models/quizadmin.php:~800-960). Order: quiz:admin (403); the lock (409 "Another quiz admin action is running. Try again in a moment.");
// both tabs are read before anything is written; no settings sheet configured, no credential or a sheet failure is 502 "The settings sheet could not be read. The settings are unchanged." (an empty settings document is created when there is none, as PHP's empty cache file).
// Announcing: only the move from a mode that is not live to a live one (a document that never held a mode announces nothing) writes the inbox copy and queues one push per device, through NotificationsCommands.AnnounceAsync in a savepoint:
// a failure there is logged and never fails the refresh (PHP). Nothing is sent: no worker reads the queue yet. Event: assessment.quiz_state_changed {action: settings_refresh}.
// Deviation: the settings sheet id is the setting TSR_QUIZ_SETTINGS_SHEET_ID (PHP: QUIZ_SETTINGS_GOOGLE_SHEET_ID); PHP's force_quiz_mode override is not ported.

internal static partial class AdminQuizSettingsRefreshSlice
{
    private const string SavePoint = "quiz_announce";
    private const string Unreadable = "The settings sheet could not be read. The settings are unchanged.";

    public static IEndpointRouteBuilder MapAdminQuizSettingsRefresh(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/quiz/settings/refresh", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        HttpContext context, AssessmentContext db, Permissions permissions, ISheets sheets, IOptions<GoogleSheetsSettings> options, TimeProvider clock, ILoggerFactory loggers, CancellationToken ct)
    {
        var (_, refusal) = await QuizAdmin.GuardAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var log = loggers.CreateLogger("Tsr.Assessment.Api.AdminQuizSettingsRefresh");
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        if (!await AssessmentLocks.TryTakeAsync(db, AssessmentLocks.QuizAdmin, ct))
        {
            return QuizAdmin.Busy();
        }

        var old = await QuizStateStore.LoadAsync(db, QuizStateStore.Settings, ct) as JsonObject;
        var fetched = await FetchAsync(sheets, options.Value.QuizSettingsSheetId, log, ct);
        if (fetched is null)
        {
            if (old is null)
            {
                await QuizStateStore.SaveAsync(db, QuizStateStore.Settings, new JsonObject(), clock, ct);
            }

            await transaction.CommitAsync(ct);
            return Problem.Detail(StatusCodes.Status502BadGateway, Unreadable);
        }

        await QuizStateStore.SaveAsync(db, QuizStateStore.Settings, fetched.Values, clock, ct);
        await AnnounceAsync(db, transaction, old, fetched, log, ct);
        await QuizAdmin.EventAsync(db, "settings_refresh", clock, ct);
        await transaction.CommitAsync(ct);
        return Results.Json(new JsonObject
        {
            ["outcome"] = "complete",
            ["message"] = "The settings were refreshed.",
            ["changed"] = true,
            ["settings"] = QuizOverview.Settings(fetched),
        });
    }

    private static async Task<QuizSettings?> FetchAsync(ISheets sheets, string? sheetId, ILogger log, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(sheetId))
        {
            LogNoSheet(log);
            return null;
        }

        try
        {
            var technical = await sheets.ReadAsync(sheetId, "Technical!A1:B", ct);
            var functional = await sheets.ReadAsync(sheetId, "Functional!A1:D", ct);
            return QuizSettings.FromSheets(technical, functional);
        }
        catch (SheetsException e)
        {
            LogSheetFailed(log, e.Message);
            return null;
        }
    }

    /// <summary>PHP announceSwitchOn, never failing the refresh: the push and inbox rows are written in a savepoint that a database error rolls back.</summary>
    private static async Task AnnounceAsync(
        AssessmentContext db, Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction transaction, JsonObject? old, QuizSettings fresh, ILogger log, CancellationToken ct)
    {
        var announcement = AnnouncementFor(old, fresh);
        if (announcement is null)
        {
            return;
        }

        await transaction.CreateSavepointAsync(SavePoint, ct);
        try
        {
            await NotificationsCommands.AnnounceAsync(db, announcement, ct);
            await transaction.ReleaseSavepointAsync(SavePoint, ct);
        }
        catch (Exception e) when (e is DbException or Microsoft.EntityFrameworkCore.DbUpdateException)
        {
            LogAnnounceFailed(log, e.GetType().Name);
            await transaction.RollbackToSavepointAsync(SavePoint, ct);
        }
    }

    /// <summary>
    /// The announcement when the quiz went from not live to live (null otherwise): title from the settings, "Grand|Mega Quiz: registration opens R, starts S." (", starts S" only with a first episode start),
    /// link /home/quiz, dedupe key "quiz-announce:series:title:start" so a repeat of the same quiz announces once.
    /// </summary>
    internal static Announcement? AnnouncementFor(JsonObject? old, QuizSettings fresh)
    {
        if (old is null || !old.ContainsKey("mode"))
        {
            return null;
        }

        var wasLive = QuizSettings.IsLiveMode(QuizOverview.Text(old["mode"]));
        if (wasLive || !QuizSettings.IsLiveMode(fresh.Str("mode")))
        {
            return null;
        }

        var title = fresh.Str("quiz_title") ?? string.Empty;
        var kind = string.Equals(fresh.Str("quiz_type"), "mega", StringComparison.OrdinalIgnoreCase) ? "Mega" : "Grand";
        var start = FirstEpisodeStart(fresh);
        var body = kind + " Quiz: registration opens " + (fresh.Str("quiz_registration") ?? string.Empty) + (start.Length > 0 ? ", starts " + start : string.Empty) + ".";
        return new Announcement(title, body, "/home/quiz", "quiz_announcement", "quiz-announce:" + (fresh.Str("quiz_series") ?? string.Empty) + ":" + title + ":" + start);
    }

    private static string FirstEpisodeStart(QuizSettings settings) =>
        settings.Values["episodes"] is JsonObject { Count: > 0 } episodes
            ? QuizOverview.Text(episodes.First().Value?["start"]) ?? string.Empty
            : string.Empty;

    [LoggerMessage(Level = LogLevel.Warning, Message = "Quiz settings: no settings sheet is configured")]
    private static partial void LogNoSheet(ILogger logger);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Quiz settings sheet read failed: {Reason}")]
    private static partial void LogSheetFailed(ILogger logger, string reason);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Quiz announcement failed ({ErrorType}); the settings were saved without it")]
    private static partial void LogAnnounceFailed(ILogger logger, string errorType);
}
