using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.ClassEventDelete;

// Slice: DELETE /classes/{class_id}/scheduled-events/{event_id} -> {success: true}: remove an event of a class from every student's calendar. The row stays, marked deleted (status, deleted_at).
// Contract: spec/api.yaml. PHP: routes/calendar.php route_class_events_delete, MobileCalendarModel::delete. Order: notifications:send on the class (403 "You cannot manage events for this
// class"), the live event of THIS class (404 "Scheduled event not found": another class's id and an event already deleted too), the owner rule (403 "Only the owner can delete this event while
// they retain access"). Event notifications.class_event_deleted (id, classId, deletedBy). Deviation: two deletes at the same instant: the second is the 404 (PHP answers both with success).

internal static class ClassEventDeleteSlice
{
    internal sealed record ClassEventDeleted(int Id, int ClassId, int DeletedBy);

    private const string NotOwner = "Only the owner can delete this event while they retain access";

    public static IEndpointRouteBuilder MapClassEventDelete(this IEndpointRouteBuilder routes)
    {
        routes.MapDelete("/classes/{class_id}/scheduled-events/{event_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, string event_id, HttpContext context, NotificationsContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
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

        var row = await ClassEvents.FindAsync(db, classId, NotifyGuards.IdOf(event_id), ct);
        if (row is null)
        {
            return ClassEvents.NotFound();
        }

        if (!await ClassEvents.EditableAsync(permissions, caller, row, [], ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, NotOwner);
        }

        return await DeleteAsync(db, clock, row, caller.Token, ct)
            ? Results.Json(new Dictionary<string, object> { ["success"] = true })
            : ClassEvents.NotFound();
    }

    private static async Task<bool> DeleteAsync(NotificationsContext db, TimeProvider clock, ClassEventRow row, int token, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var deleted = await db.Database.ExecuteSqlAsync(
            $"update notifications.class_scheduled_events set status = 'deleted', deleted_at = {now}, updated_at = {now} where id = {row.Id} and class_id = {row.ClassId} and status = 'active'", ct);
        if (deleted == 0)
        {
            return false;
        }

        await Outbox.WriteAsync(db, "notifications.class_event_deleted", new ClassEventDeleted(row.Id, row.ClassId, token), clock, ct);
        await transaction.CommitAsync(ct);
        return true;
    }
}
