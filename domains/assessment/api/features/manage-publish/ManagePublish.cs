using System.Data.Common;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Notifications.Api;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManagePublish;

// Slice: POST /mcq/manage/{quiz_id}/publish -> release the quiz to the class and tell its students; {success, publishedAt, deviceCount, successCount, failureCount}. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_publish (:272), McqModel publish (:566) and fillMissingOptionOrders, functions.php quiz_publish_payload (:1400) and queue_message (:472), MobileNotificationsModel create and fanOut.
// Order: caller (401), quiz found (404), its class active (404), mcqs:manage on the class (403), then: (1) the option order of every question is fixed and stored (domain/OptionOrder.cs: option1 is the right answer, so an unfixed order would print it first),
// (2) ONE transaction: published_at (now) and published_by (the caller) are set and the event assessment.quiz_published {quizId, classId, token} is written, (3) a SECOND transaction, best effort as PHP's (a failure there is logged without data, the publish stands and the counts are 0):
// notifications' published command AnnounceCountedAsync with the class's current students' TOKENS (assessment never reads device rows): a push queued per device (dedupe key quiz-<id>, created by the caller, payload {title, body, data: {type quiz_released, quiz_id, class_id, title, body, url}}),
// a NEW notification every time (criteria {"type":"CLASS","value":["<class id>"]}, link /quizzes/<id>, device, success (queued) and failure (refused) counts) and its inbox row per student. Nothing is sent: no worker reads the queue yet.
// Title "MCQ for <class code> [<name>]"; body "MCQ for <class code> for the Topic - <topic, or General when empty> - <name>"; url = TSR_PUBLIC_WEB_BASE + /mcq/<code> (empty when the setting or the code is empty, PHP's public_web_base; the manage list falls back to a fixed host, the push does not).
// Counts: deviceCount the devices found, successCount the push rows queued (a repeat of the same publish queues none: PHP's dedupe), failureCount the difference.
// COPIED FROM PHP: no check that the quiz has questions, is already published or is deactivated: publishing again moves published_at forward and writes a second notification and inbox row (but no second push to a device).

internal static partial class ManagePublishSlice
{
    internal sealed record Body(bool Success, string? PublishedAt, int DeviceCount, int SuccessCount, int FailureCount);

    internal sealed record QuizPublished(int QuizId, int ClassId, int Token);

    public static IEndpointRouteBuilder MapManagePublish(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/mcq/manage/{quiz_id}/publish", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string quiz_id, HttpContext context, AssessmentContext db, Permissions permissions, TimeProvider clock, IQuizRandom random, IConfiguration configuration, ILoggerFactory loggers, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (quiz, refusal) = await ManageAccess.ResolveQuizAsync(db, PhpValue.IntOfText(quiz_id), ct);
        if (refusal is not null)
        {
            return refusal;
        }

        if (!await ManageAccess.CanAsync(permissions, caller, "mcqs:manage", quiz!.ClassId, ct))
        {
            return ManageAccess.NotPermitted();
        }

        await OptionOrder.FillMissingAsync(db, quiz.Id, random, ct);
        var at = ManageAccess.NowToSecond(clock);
        if (!await PublishAsync(db, clock, quiz, caller.Token, at, ct))
        {
            return Refusals.QuizNotFound();
        }

        var result = await AnnounceAsync(db, quiz, caller.Token, configuration, loggers.CreateLogger("Tsr.Assessment.ManagePublish"), ct);
        return Results.Json(new Body(true, QuizAccess.Stamp(at), result.Devices, result.Queued, result.Devices - result.Queued));
    }

    private static async Task<bool> PublishAsync(AssessmentContext db, TimeProvider clock, ManageAccess.QuizRow quiz, int token, DateTimeOffset at, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var updated = await db.Database.ExecuteSqlAsync($"update assessment.spot_quizzes set published_at = {at}, published_by = {token} where id = {quiz.Id}", ct);
        if (updated == 0)
        {
            return false;
        }

        await Outbox.WriteAsync(db, "assessment.quiz_published", new QuizPublished(quiz.Id, quiz.ClassId, token), clock, ct);
        await transaction.CommitAsync(ct);
        return true;
    }

    private static async Task<AnnounceResult> AnnounceAsync(AssessmentContext db, ManageAccess.QuizRow quiz, int token, IConfiguration configuration, ILogger logger, CancellationToken ct)
    {
        try
        {
            var students = await ClassStudents.ListAsync(db, quiz.ClassId, ct);
            var announcement = Announce(quiz, token, students.Select(s => s.Token).ToList(), configuration);
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            var result = await NotificationsCommands.AnnounceCountedAsync(EfTransaction.Join(db), announcement, ct);
            await transaction.CommitAsync(ct);
            return result;
        }
        catch (DbException e)
        {
            LogAnnounceFailed(logger, quiz.Id, e.GetType().Name);
            return new AnnounceResult(0, 0);
        }
    }

    private static Announcement Announce(ManageAccess.QuizRow quiz, int token, IReadOnlyList<int> students, IConfiguration configuration)
    {
        var classCode = quiz.ClassCode ?? string.Empty;
        var name = quiz.Name ?? string.Empty;
        var title = $"MCQ for {classCode} [{name}]";
        var body = $"MCQ for {classCode} for the Topic - {(string.IsNullOrEmpty(quiz.Topic) ? "General" : quiz.Topic)} - {name}";
        var data = new Dictionary<string, string>
        {
            ["type"] = "quiz_released",
            ["quiz_id"] = quiz.Id.ToString(System.Globalization.CultureInfo.InvariantCulture),
            ["class_id"] = quiz.ClassId.ToString(System.Globalization.CultureInfo.InvariantCulture),
            ["title"] = title,
            ["body"] = body,
            ["url"] = Url(configuration, quiz.Code),
        };
        var criteria = JsonSerializer.Serialize(new { type = "CLASS", value = new[] { quiz.ClassId.ToString(System.Globalization.CultureInfo.InvariantCulture) } });
        return new Announcement(
            title, body, $"/quizzes/{quiz.Id}", "quiz_released", $"quiz-{quiz.Id}", students, token, criteria, data, ReuseExisting: false, CountsFromQueue: true);
    }

    private static string Url(IConfiguration configuration, string? code)
    {
        var configured = (configuration["TSR_PUBLIC_WEB_BASE"] ?? string.Empty).TrimEnd('/');
        return configured.Length > 0 && !string.IsNullOrEmpty(code) ? configured + "/mcq/" + Uri.EscapeDataString(code) : string.Empty;
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "The announcement of published quiz {QuizId} was not written ({ErrorType}); the quiz stays published")]
    private static partial void LogAnnounceFailed(ILogger logger, int quizId, string errorType);
}
