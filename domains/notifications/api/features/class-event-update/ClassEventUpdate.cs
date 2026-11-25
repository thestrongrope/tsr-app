using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.ClassEventUpdate;

// Slice: PATCH /classes/{class_id}/scheduled-events/{event_id} {message?, description?, action_link?, weekdays?, send_time?} -> {item}: change an event of a class. A field the body leaves out
// keeps its value (a field sent as null is checked as null); the zone is the creator's and never changes, whatever the body says. Contract: spec/api.yaml.
// PHP: routes/calendar.php route_class_events_update, MobileCalendarModel::update. Order: notifications:send on the class (403 "You cannot manage events for this class"), the body (422 "Invalid
// JSON body"), the live event of THIS class (404 "Scheduled event not found": another class's id and a deleted event too), the owner rule (403 "Only the owner can change this event while they
// retain access": a sender edits another's event only once its owner lost access, and that take-over does not move ownership), the fields (domain/CalendarEventInput.cs), the stored zone (422).
// Event notifications.class_event_updated (id, classId, updatedBy).

internal static class ClassEventUpdateSlice
{
    internal sealed record ClassEventUpdated(int Id, int ClassId, int UpdatedBy);

    private const string NotOwner = "Only the owner can change this event while they retain access";

    public static IEndpointRouteBuilder MapClassEventUpdate(this IEndpointRouteBuilder routes)
    {
        routes.MapPatch("/classes/{class_id}/scheduled-events/{event_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, string event_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
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

        var id = NotifyGuards.IdOf(event_id);
        var row = await ClassEvents.FindAsync(source, classId, id, ct);
        if (row is null)
        {
            return ClassEvents.NotFound();
        }

        if (!await ClassEvents.EditableAsync(permissions, caller, row, [], ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, NotOwner);
        }

        var values = Merge(body!, row);
        if (!values.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, values.Error!);
        }

        if (WallClock.Zone(row.Tz) is null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, CalendarEventInput.ZoneError);
        }

        if (!await UpdateAsync(source, clock, row, values.Value!, caller.Token, ct))
        {
            return ClassEvents.NotFound();
        }
        var changed = await ClassEvents.FindAsync(source, classId, id, ct);
        if (changed is null)
        {
            return ClassEvents.NotFound();
        }

        return Results.Json(new Dictionary<string, object?> { ["item"] = await ClassEvents.ManagedPayloadAsync(permissions, caller, changed, ct) }, NotificationsJson.Answers.Answer);
    }

    // PHP's `$input + $payload`: the body's field when the body names it (null included), else the event as it is on the wire, checked again by the same rules.
    private static Result<CalendarEventValues> Merge(JsonBody body, ClassEventRow row)
    {
        var stored = JsonSerializer.SerializeToElement(ClassEvents.Payload(row, row.CreatedByUserId, editable: false), NotificationsJson.Default.Answer);
        return CalendarEventInput.Parse(name => body.Has(name) ? body.Get(name) : stored.GetProperty(name));
    }

    // False when the event was deleted since it was read: nothing is written, and no event says it was updated.
    private static async Task<bool> UpdateAsync(NpgsqlDataSource source, TimeProvider clock, ClassEventRow row, CalendarEventValues values, int token, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await using var tx = await source.BeginAsync(ct);
        var changed = await tx.ExecuteAsync(
            $"""
            update notifications.class_scheduled_events
            set message = {values.Message}, description = {values.Description}, action_link = {values.ActionLink}, weekdays = {values.Weekdays}, send_time = {values.SendTime}, updated_at = {now}
            where id = {row.Id} and class_id = {row.ClassId} and status = 'active'
            """,
            ct);
        if (changed == 0)
        {
            return false;
        }

        await Outbox.WriteAsync(tx, "notifications.class_event_updated", new ClassEventUpdated(row.Id, row.ClassId, token), NotificationsJson.Default.ClassEventUpdated, clock, ct);
        await tx.CommitAsync(ct);
        return true;
    }
}
