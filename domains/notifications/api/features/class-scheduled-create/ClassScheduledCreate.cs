using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.ClassScheduledCreate;

// Slice: POST /classes/{class_id}/notifications/scheduled {title, body, action_link?, kind, timezone, ...} -> 201 {success: true, item}: schedule a notification for a class. It sends nothing:
// a worker fires it later (not built: lane-notify-core-notes.md). Contract: spec/api.yaml.
// PHP: routes/classes.php route_class_notifications_scheduled_create, ClassScheduledNotificationsModel::create. Order: the class (404 "Class not found"), notifications:send on it (403 "You do not
// have permission to send notifications for this class"), the body, the message (domain/ClassMessage.cs, link rewritten to an in-app path), the kind (422), at most 20 active schedules per class
// (422), the sender's IANA zone, the fields of the kind (domain/ScheduleInput.cs: ONCE a future local date and time, WEEKLY ISO weekdays and HH:MM, REMINDER one of the class's live slots and an
// offset within a week), then the rate limit (20 an hour per member, bucket class_scheduled_create, 429), then the write: invalid attempts never count against the limit.
// Event notifications.class_schedule_created (id, classId, kind, createdBy). Deviation: a NUL character in a text is a 422.

internal static class ClassScheduledCreateSlice
{
    internal sealed record ScheduleCreated(int Id, int ClassId, string Kind, int CreatedBy);

    internal sealed record Slot(int Id, string Timezone);

    public static IEndpointRouteBuilder MapClassScheduledCreate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/{class_id}/notifications/scheduled", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string class_id,
        HttpContext context,
        NpgsqlDataSource source,
        Permissions permissions,
        MemberRateLimit limiter,
        TimeProvider clock,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var classId = NotifyGuards.IdOf(class_id);
        var refusal = await NotifyGuards.ClassAccessAsync(source, permissions, caller, classId, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var message = ClassMessage.Parse(body!, rewriteLink: true);
        if (!message.IsSuccess)
        {
            return Unprocessable(message.Error!);
        }

        var kind = ScheduleInput.Kind(body!);
        if (kind is null)
        {
            return Unprocessable(ScheduleInput.KindError);
        }

        if (await ActiveCountAsync(source, classId, ct) >= ScheduleInput.MaxActivePerClass)
        {
            return Unprocessable($"A class can have at most {ScheduleInput.MaxActivePerClass} active scheduled notifications");
        }

        var now = clock.GetUtcNow();
        var slots = kind == "REMINDER" ? await LiveSlotsAsync(source, classId, ct) : [];
        var draft = ScheduleInput.Parse(body!, kind, now, slots);
        if (!draft.IsSuccess)
        {
            return Unprocessable(draft.Error!);
        }

        if (!limiter.Allow("class_scheduled_create", caller.Token, 20, 3600))
        {
            return Problem.Detail(StatusCodes.Status429TooManyRequests, "Too many scheduled notifications created; try again later");
        }

        var id = await CreateAsync(source, clock, classId, caller, message.Value!, draft.Value!, ct);
        var row = (await ScheduledRows.QueryAsync(source, classId, id, ct))[0];
        var item = ScheduledRows.Item(row, null, now);
        return Results.Json(new Dictionary<string, object?> { ["success"] = true, ["item"] = item }, NotificationsJson.Answers.Answer, contentType: null, statusCode: StatusCodes.Status201Created);
    }

    private static IResult Unprocessable(string detail) => Problem.Detail(StatusCodes.Status422UnprocessableEntity, detail);

    private static async Task<long> ActiveCountAsync(NpgsqlDataSource source, int classId, CancellationToken ct) =>
        (await source.ListAsync(
            $"""select count(*) as "Value" from notifications.class_scheduled_notifications where class_id = {classId} and status = 'active'""",
            row => row.Long("Value"),
            ct))[0];

    private static async Task<Dictionary<int, string>> LiveSlotsAsync(NpgsqlDataSource source, int classId, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"""select id as "Id", coalesce(timezone, '') as "Timezone" from classes.v_class_schedules where class_id = {classId} and deleted_at is null""",
            row => new Slot(row.Int("Id"), row.Text("Timezone")),
            ct);
        return rows.ToDictionary(r => r.Id, r => r.Timezone);
    }

    private static async Task<int> CreateAsync(NpgsqlDataSource source, TimeProvider clock, int classId, Caller caller, ClassMessageText message, ScheduleDraft draft, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        LocalTimestamp? sendAt = draft.SendAt is { } at ? new LocalTimestamp(DateTime.SpecifyKind(at, DateTimeKind.Unspecified)) : null;
        var repeatWeekly = (short)(draft.RepeatWeekly ? 1 : 0);
        // created_at and updated_at are left out: the database's own clock stamps them, as it always has.
        var ids = await tx.ListAsync(
            $"""
            insert into notifications.class_scheduled_notifications
                (class_id, created_by, created_by_user_id, title, body, action_link, kind, send_at, weekdays, send_time, tz, class_schedule_id, offset_minutes, repeat_weekly, status)
            values ({classId}, {caller.Token}, {caller.UserId}, {message.Title}, {message.Body}, {message.ActionLink}, {draft.Kind}, {sendAt}, {draft.Weekdays}, {draft.SendTime}, {draft.Tz},
                    {draft.ClassScheduleId}, {draft.OffsetMinutes}, {repeatWeekly}, 'active')
            returning id
            """,
            row => row.Int("id"),
            ct);
        var id = ids.Single();
        await Outbox.WriteAsync(tx, "notifications.class_schedule_created", new ScheduleCreated(id, classId, draft.Kind, caller.Token), NotificationsJson.Default.ScheduleCreated, clock, ct);
        await tx.CommitAsync(ct);
        return id;
    }
}
