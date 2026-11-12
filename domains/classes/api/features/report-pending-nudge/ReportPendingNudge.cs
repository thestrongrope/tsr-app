using System.Globalization;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Notifications.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportPendingNudge;

// Slice: POST /reports/pending/nudge {teacher, send?, from?, to?} -> {teacherToken, teacher, title, body, alreadyReminded, lastReminded, sent, deviceCount}: a coordinator reminds a teacher of the class forms and MCQs pending. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_pending_nudge (:910), models/pendingnudge.php (message, recordedCriteria, lastReminded, record), mobilenotifications.php (create, fanOut).
// Order as PHP: sign-in, reports:read for the gender (403), teacher a JSON integer above 0 (422 "teacher must be a member token"), send only when exactly true, months (default last month to this month; 422), the teacher must be in the
// caller's own pending report (the reach, the gender lock and the assigned-classes rule of that report; outside the reach or nothing pending: the same 422), then the answer for a dry run. With send: 429 when reminded in the last 24 hours,
// 429 over 30 reminders an hour per sender (in memory, bucket cc_nudge), then ONE transaction: advisory lock on the teacher, the 24 hours checked again, the notification recorded with criteria {"type":"CC_NUDGE","teacher","classes"}
// and put in the teacher's inbox, and one queued push per device (notifications' published AnnounceAsync); the outbox event classes.teacher_nudged. Nothing is sent: sent:true means "recorded and queued", deviceCount the devices queued for
// (a demo member has none). Deviation: the months span at most 12 (PHP's nudge has no limit; its pending report does), so the report query stays bounded.

internal static class ReportPendingNudgeSlice
{
    private const int LockClass = 7_300_001;
    private const int WindowHours = 24;
    private const int MaxPerHour = 30;
    private const int BodyLimit = 500;
    internal const string Title = "Reminder from the class coordination team";

    internal sealed record Answer(int TeacherToken, string Teacher, string Title, string Body, bool AlreadyReminded, string? LastReminded, bool Sent, int DeviceCount);

    private sealed record TeacherNudged(int TeacherToken, int SenderToken, IReadOnlyList<int> ClassIds);

    public static IEndpointRouteBuilder MapReportPendingNudge(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/reports/pending/nudge", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, MemberRateLimit limit, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (scope, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        if (!PhpValue.IsInt(body!.Get("teacher"), out var teacherToken) || teacherToken <= 0)
        {
            return Unprocessable("teacher must be a member token");
        }

        var send = body.Get("send").ValueKind == JsonValueKind.True;
        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var from = MonthOf(body.Get("from")) ?? PendingReport.Month(new DateOnly(today.Year, today.Month, 1).AddMonths(-1));
        var to = MonthOf(body.Get("to")) ?? PendingReport.Month(today);
        var invalid = ReportMonths.Check(from, to, limitToTwelve: true);
        if (invalid is not null)
        {
            return Unprocessable(invalid);
        }

        var report = await PendingReport.LoadAsync(scope!, from, to, string.Empty, db, permissions, caller, today, ct);
        var teacher = report.Teachers.FirstOrDefault(t => t.TeacherToken == teacherToken);
        if (teacher is null)
        {
            return Unprocessable("Nothing is pending for this teacher");
        }

        var (title, text) = Message(teacher);
        var last = await NotificationsCommands.LastNudgeAsync(db, teacher.TeacherToken, WindowHours, ct);
        var answer = new Answer(teacher.TeacherToken, teacher.Teacher, title, text, last is not null, Stamp(last), false, 0);
        if (!send)
        {
            return Results.Json(answer);
        }

        if (last is not null)
        {
            return Problem.Detail(StatusCodes.Status429TooManyRequests, AlreadyReminded);
        }

        if (!limit.Allow("cc_nudge", caller.Token, MaxPerHour, 3600))
        {
            return Problem.Detail(StatusCodes.Status429TooManyRequests, "Too many reminders; try again later");
        }

        var now = clock.GetUtcNow();
        var classIds = teacher.Classes.Select(c => c.ClassId).Distinct().ToList();
        var devices = await RecordAsync(db, clock, caller.Token, teacher.TeacherToken, answer, classIds, now, ct);
        if (devices is null)
        {
            return Problem.Detail(StatusCodes.Status429TooManyRequests, AlreadyReminded);
        }

        return Results.Json(answer with { Sent = true, DeviceCount = devices.Value, LastReminded = Stamp(now) });
    }

    private const string AlreadyReminded = "This teacher was already reminded in the last 24 hours";

    private static IResult Unprocessable(string detail) => Problem.Detail(StatusCodes.Status422UnprocessableEntity, detail);

    // PHP (string) ($body['from'] ?? default): null when missing or null (the default applies), else the value as text.
    private static string? MonthOf(JsonElement value) =>
        value.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined ? null : PhpValue.Text(value);

    private static string? Stamp(DateTimeOffset? when) =>
        when?.UtcDateTime.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);

    // Null when the teacher was reminded meanwhile; else the devices queued for.
    private static async Task<int?> RecordAsync(ClassesContext db, TimeProvider clock, int sender, int teacher, Answer message, List<int> classIds, DateTimeOffset now, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlAsync($"set local lock_timeout = '5s'", ct);
        await db.Database.ExecuteSqlAsync($"select pg_advisory_xact_lock({LockClass}, {teacher})", ct);
        if (await NotificationsCommands.LastNudgeAsync(db, teacher, WindowHours, ct) is not null)
        {
            return null;
        }

        var criteria = JsonSerializer.Serialize(new { type = "CC_NUDGE", teacher, classes = classIds });
        var data = new Dictionary<string, string>
        {
            ["sent_at"] = now.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss.ffffff", CultureInfo.InvariantCulture),
            ["class_ids"] = string.Join(',', classIds),
        };
        var extras = new AnnouncementExtras(criteria, sender, data, SkipDemoDevices: true);
        var key = $"cc_nudge:{teacher}:{now.ToUnixTimeSeconds()}";
        var announcement = new Announcement(message.Title, message.Body, null, "cc_reminder", key, [teacher], extras);
        var devices = await NotificationsCommands.AnnounceAsync(db, announcement, ct);
        await Outbox.WriteAsync(db, "classes.teacher_nudged", new TeacherNudged(teacher, sender, classIds), clock, ct);
        await transaction.CommitAsync(ct);
        return devices;
    }

    /// <summary>PHP PendingNudgeModel::message: a fixed template, one line per class, cut so the body is at most 500 characters, with "and N more classes" for what does not fit.</summary>
    internal static (string Title, string Body) Message(PendingRules.PendingTeacher teacher)
    {
        ArgumentNullException.ThrowIfNull(teacher);
        var lines = teacher.Classes.Select(Line).ToList();
        const string head = "Assalamu Alaikum. Please complete the following for your classes:\n";
        const string tail = "\nJazakallah khair.";
        var shown = new List<string>();
        for (var i = 0; i < lines.Count; i++)
        {
            var more = lines.Count - i;
            var candidate = head + string.Join('\n', shown.Append(lines[i])) + tail;
            var reserve = more > 1 ? PhpText.CodePointCount($"\n…and {more} more classes") : 0;
            if (PhpText.CodePointCount(candidate) + reserve > BodyLimit)
            {
                break;
            }

            shown.Add(lines[i]);
        }

        var rest = lines.Count - shown.Count;
        var body = new StringBuilder(head).Append(string.Join('\n', shown));
        if (rest > 0)
        {
            body.Append(CultureInfo.InvariantCulture, $"\n…and {rest} more ").Append(rest == 1 ? "class" : "classes");
        }

        return (Title, body.Append(tail).ToString());
    }

    private static string Line(PendingRules.PendingClass c)
    {
        var parts = new List<string>();
        if (c.NotFilled > 0)
        {
            parts.Add($"{c.NotFilled} " + (c.NotFilled == 1 ? "class form" : "class forms"));
        }

        if (c.McqPending > 0)
        {
            parts.Add($"{c.McqPending} " + (c.McqPending == 1 ? "MCQ" : "MCQs") + " to conduct");
        }

        return $"• {c.Class}: {string.Join(", ", parts)}";
    }
}
