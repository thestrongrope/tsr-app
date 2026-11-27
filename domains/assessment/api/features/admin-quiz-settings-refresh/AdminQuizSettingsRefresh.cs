using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Npgsql;
using Microsoft.Extensions.Options;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.AdminQuizSettingsRefresh;

// Slice: POST /admin/quiz/settings/refresh -> read the settings sheet (tabs Technical!A1:B and Functional!A1:D) into the settings document and announce a quiz that just went live. Contract: spec/api.yaml.
// PHP: routes/quiz_admin.php route_admin_quiz_settings_refresh (:241), QuizAdminModel refreshSettings / fetchSettings / announceSwitchOn (models/quizadmin.php:~800-960). Order: quiz:admin (403); the lock (409 "Another quiz admin action is running. Try again in a moment.");
// both tabs are read before anything is written; no settings sheet configured, no credential or a sheet failure is 502 "The settings sheet could not be read. The settings are unchanged." (an empty settings document is created when there is none, as PHP's empty cache file).
// The sheet read, the save and the announcement are shared with GET /quiz/info: domain/QuizSettingsRefresh.cs. Announcing: only the move from a mode that is not live to a live one (a document that never held a mode announces nothing) writes the inbox copy and queues one push per device, through NotificationsCommands.AnnounceAsync in a savepoint:
// a failure there is logged and never fails the refresh (PHP). Nothing is sent: no worker reads the queue yet. Event: assessment.quiz_state_changed {action: settings_refresh}.
// Deviation: the settings sheet id is the setting TSR_QUIZ_SETTINGS_SHEET_ID (PHP: QUIZ_SETTINGS_GOOGLE_SHEET_ID); PHP's force_quiz_mode override is not ported.

internal static class AdminQuizSettingsRefreshSlice
{
    private const string Unreadable = "The settings sheet could not be read. The settings are unchanged.";

    public static IEndpointRouteBuilder MapAdminQuizSettingsRefresh(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/quiz/settings/refresh", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        HttpContext context, NpgsqlDataSource source, Permissions permissions, ISheets sheets, IOptions<GoogleSheetsSettings> options, TimeProvider clock, ILoggerFactory loggers, CancellationToken ct)
    {
        var (_, refusal) = await QuizAdmin.GuardAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var log = loggers.CreateLogger("Tsr.Assessment.Api.AdminQuizSettingsRefresh");
        await using var tx = await source.BeginAsync(ct);
        if (!await AssessmentLocks.TryTakeAsync(tx, AssessmentLocks.QuizAdmin, ct))
        {
            return QuizAdmin.Busy();
        }

        var old = await QuizStateStore.LoadAsync(tx, QuizStateStore.Settings, ct) as JsonObject;
        var fetched = await QuizSettingsRefresh.FetchAsync(sheets, options.Value.QuizSettingsSheetId, log, ct);
        if (fetched is null)
        {
            if (old is null)
            {
                await QuizStateStore.SaveAsync(tx, QuizStateStore.Settings, new JsonObject(), clock, ct);
            }

            await tx.CommitAsync(ct);
            return Problem.Detail(StatusCodes.Status502BadGateway, Unreadable);
        }

        await QuizSettingsRefresh.SaveAsync(tx, old, fetched, clock, log, ct);
        await QuizAdmin.EventAsync(tx, "settings_refresh", clock, ct);
        await tx.CommitAsync(ct);
        return Results.Json(
            new JsonObject
            {
                ["outcome"] = "complete",
                ["message"] = "The settings were refreshed.",
                ["changed"] = true,
                ["settings"] = QuizOverview.Settings(fetched),
            },
            AssessmentJson.Answers.JsonObject);
    }
}
