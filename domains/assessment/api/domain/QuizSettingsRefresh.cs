using System.Data.Common;
using System.Text.Json.Nodes;
using Microsoft.Extensions.Logging;
using Npgsql;
using Tsr.Notifications.Api;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// Reading the quiz settings sheet into the settings document, shared by the admin refresh (POST /admin/quiz/settings/refresh) and GET /quiz/info, which a slice may not call from the other:
/// <see cref="FetchAsync"/> reads both tabs (PHP QuizAdminModel::fetchSettings, models/quizadmin.php:~815), <see cref="SaveAsync"/> saves the document and announces a quiz that just went live (announceSwitchOn), and
/// <see cref="CurrentAsync"/> is PHP's website path (get_quiz_settings, functions.php:1025): a saved copy under <see cref="MaxAge"/> old is used as it is, an older one is read again under the quiz admin lock
/// (fetch_quiz_settings -> refreshSettings, which also announces; a busy lock keeps the saved copy). Deviations from PHP: the read for a request stops after <see cref="ReadLimit"/> and serves the saved copy;
/// a quiz admin does not bypass the 60 seconds; PHP's force_quiz_mode override is not ported; the read for a request writes no outbox event (the admin action does).
/// </summary>
internal static partial class QuizSettingsRefresh
{
    public static readonly TimeSpan MaxAge = TimeSpan.FromSeconds(60);

    public static readonly TimeSpan ReadLimit = TimeSpan.FromSeconds(5);

    /// <summary>Both tabs of the settings sheet as settings; null (and a log line) when no sheet is configured or Google cannot be read. Nothing is written.</summary>
    public static async Task<QuizSettings?> FetchAsync(ISheets sheets, string? sheetId, ILogger log, CancellationToken ct)
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

    /// <summary>Saves the settings document and announces the quiz when it went from not live to live (<paramref name="old"/> is the document before).</summary>
    public static async Task SaveAsync(DbTx tx, JsonObject? old, QuizSettings fresh, TimeProvider clock, ILogger log, CancellationToken ct)
    {
        await QuizStateStore.SaveAsync(tx, QuizStateStore.Settings, fresh.Values, clock, ct);
        await AnnounceAsync(tx, old, fresh, log, ct);
    }

    /// <summary>
    /// The settings for a request: the saved copy when it is under <see cref="MaxAge"/> old, else one read from the sheet and saved. The saved copy (or no settings) is served, and the reason logged,
    /// when another refresh holds the quiz admin lock, the sheet cannot be read or the read takes over <see cref="ReadLimit"/>. Never fails for the sheet.
    /// </summary>
    public static async Task<QuizSettings> CurrentAsync(NpgsqlDataSource source, ISheets sheets, string? sheetId, TimeProvider clock, ILogger log, SheetReadBackoff backoff, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        var saved = await LoadAsync(tx, ct);
        if (IsFresh(saved, clock))
        {
            return new QuizSettings(saved.Document ?? new JsonObject());
        }

        if (backoff.Waiting)
        {
            return new QuizSettings(saved.Document ?? new JsonObject());
        }

        if (!await AssessmentLocks.TryTakeAsync(tx, AssessmentLocks.QuizAdmin, ct))
        {
            LogBusy(log);
            return new QuizSettings(saved.Document ?? new JsonObject());
        }

        saved = await LoadAsync(tx, ct);
        if (IsFresh(saved, clock))
        {
            return new QuizSettings(saved.Document ?? new JsonObject());
        }

        var fetched = await FetchWithinLimitAsync(sheets, sheetId, log, ct);
        if (fetched is null)
        {
            backoff.Failed();
            return new QuizSettings(saved.Document ?? new JsonObject());
        }

        backoff.Succeeded();
        await SaveAsync(tx, saved.Document, fetched, clock, log, ct);
        await tx.CommitAsync(ct);
        return fetched;
    }

    private sealed record Saved(JsonObject? Document, DateTimeOffset? UpdatedAt);

    private static async Task<Saved> LoadAsync(DbTx tx, CancellationToken ct) =>
        new(await QuizStateStore.LoadAsync(tx, QuizStateStore.Settings, ct) as JsonObject, await QuizStateStore.UpdatedAtAsync(tx, QuizStateStore.Settings, ct));

    private static bool IsFresh(Saved saved, TimeProvider clock) =>
        saved is { Document: not null, UpdatedAt: { } at } && clock.GetUtcNow() - at < MaxAge;

    private static async Task<QuizSettings?> FetchWithinLimitAsync(ISheets sheets, string? sheetId, ILogger log, CancellationToken ct)
    {
        using var limit = CancellationTokenSource.CreateLinkedTokenSource(ct);
        limit.CancelAfter(ReadLimit);
        try
        {
            return await FetchAsync(sheets, sheetId, log, limit.Token);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            LogSheetTimedOut(log, (int)ReadLimit.TotalSeconds);
            return null;
        }
    }

    /// <summary>PHP announceSwitchOn, never failing the refresh: the push and inbox rows are written in a savepoint that a database error rolls back.</summary>
    private static async Task AnnounceAsync(DbTx tx, JsonObject? old, QuizSettings fresh, ILogger log, CancellationToken ct)
    {
        var announcement = AnnouncementFor(old, fresh);
        if (announcement is null)
        {
            return;
        }

        await tx.ExecuteAsync($"savepoint quiz_announce", ct);
        try
        {
            await NotificationsCommands.AnnounceAsync(tx, announcement, ct);
            await tx.ExecuteAsync($"release savepoint quiz_announce", ct);
        }
        catch (DbException e)
        {
            LogAnnounceFailed(log, e.GetType().Name);
            await tx.ExecuteAsync($"rollback to savepoint quiz_announce", ct);
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

    [LoggerMessage(Level = LogLevel.Warning, Message = "Quiz settings sheet read took over {Seconds} seconds; the saved settings are served")]
    private static partial void LogSheetTimedOut(ILogger logger, int seconds);

    [LoggerMessage(Level = LogLevel.Information, Message = "Quiz settings are stale and another refresh is running; the saved settings are served")]
    private static partial void LogBusy(ILogger logger);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Quiz announcement failed ({ErrorType}); the settings were saved without it")]
    private static partial void LogAnnounceFailed(ILogger logger, string errorType);
}
