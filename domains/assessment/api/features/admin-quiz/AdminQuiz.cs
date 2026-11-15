using System.Data.Common;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.AdminQuiz;

// Slice: GET /admin/quiz -> the quiz competition overview for the admin screen. Contract: spec/api.yaml.
// PHP: routes/quiz_admin.php route_admin_quiz (:233), QuizAdminModel overview (models/quizadmin.php:~560) and its views. Order: quiz:admin (403). Reads only: no sheet, no lock.
// Reads: the state documents (settings, quiz_day, timestamps, winners, participants), and, once a download stored participants, the feasibility read of member data (membership.v_members) and enrolments
// (classes.v_enrolments, classes.v_classes) for the funnel counts and the draw gates. A failure of that read leaves eligibility empty and the gates asking for the scoreboard (PHP logs the class only).
// can_reset: whether the caller holds quiz:reset. The replaced-winners record, sheet ids and token lists are never sent. Shape: domain/QuizOverview.cs.

internal static partial class AdminQuizSlice
{
    public static IEndpointRouteBuilder MapAdminQuiz(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/quiz", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, AssessmentContext db, Permissions permissions, ILoggerFactory loggers, CancellationToken ct)
    {
        var (caller, refusal) = await QuizAdmin.GuardAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var settings = await QuizAdmin.SettingsAsync(db, ct);
        var timestamps = await QuizStateStore.LoadObjectAsync(db, QuizStateStore.Timestamps, ct);
        var winners = await QuizStateStore.LoadObjectAsync(db, QuizStateStore.Winners, ct);
        var quizDay = await QuizStateStore.LoadQuizDayAsync(db, ct);
        var feasibility = await FeasibilityOrNullAsync(db, settings, loggers.CreateLogger("Tsr.Assessment.Api.AdminQuiz"), ct);
        var canReset = await permissions.CanAsync(caller!, "quiz:reset", AccessTarget.None, ct);
        return Results.Json(QuizOverview.Build(settings, winners, timestamps, quizDay, feasibility, canReset));
    }

    private static async Task<Feasibility?> FeasibilityOrNullAsync(AssessmentContext db, QuizSettings settings, ILogger log, CancellationToken ct)
    {
        if (!settings.Loaded || settings.TotalQuizzes > QuizSettings.MaxEpisodes || !await QuizStateStore.ExistsAsync(db, QuizStateStore.Participants, ct))
        {
            return null;
        }

        try
        {
            return await QuizAdmin.FeasibilityAsync(db, settings, ct);
        }
        catch (DbException e)
        {
            LogEligibilityFailed(log, e.GetType().Name);
            return null;
        }
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "Quiz eligibility could not be computed ({ErrorType})")]
    private static partial void LogEligibilityFailed(ILogger logger, string errorType);
}
