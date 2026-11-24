using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.ClassEventCreate;

// Slice: POST /classes/{class_id}/scheduled-events {message, description?, action_link?, weekdays, send_time, timezone} -> 201 {item}: put a weekly event on the calendar of a class's students.
// Contract: spec/api.yaml. PHP: routes/calendar.php route_class_events_create, MobileCalendarModel::create. Order: notifications:send on the class (403 "You cannot manage events for this
// class"; the class is not looked up, so an unknown class is this 403), the body (422 "Invalid JSON body"), the fields (domain/CalendarEventInput.cs), the sender's IANA zone (422), at most 500
// active events per class (422, counted under a lock on the class so two requests cannot both take the last place), then the write. The event is timed in the creator's zone for good.
// Event notifications.class_event_created (id, classId, createdBy). Deviation: PHP locks the classes row; another domain's row is not ours to lock, so the lock is an advisory one on the class id.

internal static class ClassEventCreateSlice
{
    internal sealed record ClassEventCreated(int Id, int ClassId, int CreatedBy);

    public static IEndpointRouteBuilder MapClassEventCreate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/{class_id}/scheduled-events", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var classId = NotifyGuards.IdOf(class_id);
        var refusal = await ClassEvents.ManageRefusalAsync(permissions, caller, classId, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var values = CalendarEventInput.Parse(body!.Get);
        if (!values.IsSuccess)
        {
            return Unprocessable(values.Error!);
        }

        var zone = CalendarEventInput.Zone(body.Get("timezone"));
        if (zone is null)
        {
            return Unprocessable(CalendarEventInput.ZoneError);
        }

        var id = await CreateAsync(source, clock, classId, caller, values.Value!, zone, ct);
        if (id is null)
        {
            return Unprocessable($"This class already has {ClassEvents.MaxPerClass} scheduled events");
        }

        var row = await ClassEvents.FindAsync(source, classId, id.Value, ct);
        if (row is null)
        {
            return ClassEvents.NotFound();
        }

        var item = await ClassEvents.ManagedPayloadAsync(permissions, caller, row, ct);
        return Results.Json(new Dictionary<string, object?> { ["item"] = item }, NotificationsJson.Answers.Answer, contentType: null, statusCode: StatusCodes.Status201Created);
    }

    private static IResult Unprocessable(string detail) => Problem.Detail(StatusCodes.Status422UnprocessableEntity, detail);

    /// <summary>The new event's id, or null when the class is full.</summary>
    private static async Task<int?> CreateAsync(NpgsqlDataSource source, TimeProvider clock, int classId, Caller caller, CalendarEventValues values, string zone, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        await tx.ExecuteAsync($"select pg_advisory_xact_lock(hashtext('notifications.class_scheduled_events'), {classId})", ct);
        var active = (await tx.ListAsync(
            $"""select count(*) as "Value" from notifications.class_scheduled_events where class_id = {classId} and status = 'active'""",
            row => row.Long("Value"),
            ct))[0];
        if (active >= ClassEvents.MaxPerClass)
        {
            return null;
        }

        var now = clock.GetUtcNow();
        var ids = await tx.ListAsync(
            $"""
            insert into notifications.class_scheduled_events
                (class_id, created_by, created_by_user_id, message, description, action_link, weekdays, send_time, tz, status, created_at, updated_at)
            values ({classId}, {caller.Token}, {caller.UserId}, {values.Message}, {values.Description}, {values.ActionLink}, {values.Weekdays}, {values.SendTime}, {zone}, 'active', {now}, {now})
            returning id
            """,
            row => row.Int("id"),
            ct);
        var id = ids.Single();
        await Outbox.WriteAsync(tx, "notifications.class_event_created", new ClassEventCreated(id, classId, caller.Token), NotificationsJson.Default.ClassEventCreated, clock, ct);
        await tx.CommitAsync(ct);
        return id;
    }
}
