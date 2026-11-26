using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.ClassScheduledDelete;

// Slice: DELETE /classes/{class_id}/notifications/scheduled/{scheduled_id} -> {success: true}: remove one scheduled notification of the class (a hard delete). Contract: spec/api.yaml.
// PHP: routes/classes.php route_class_notifications_scheduled_delete. Order: the class (404 "Class not found"), notifications:send on it (403 "You do not have permission to send notifications for
// this class"), the row of THIS class (404 "Scheduled notification not found": another class's id is a 404, never a delete). Event notifications.class_schedule_deleted (id, classId, deletedBy).

internal static class ClassScheduledDeleteSlice
{
    internal sealed record ScheduleDeleted(int Id, int ClassId, int DeletedBy);

    public static IEndpointRouteBuilder MapClassScheduledDelete(this IEndpointRouteBuilder routes)
    {
        routes.MapDelete("/classes/{class_id}/notifications/scheduled/{scheduled_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, string scheduled_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
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

        var id = NotifyGuards.IdOf(scheduled_id);
        if (!await DeleteAsync(source, clock, classId, id, caller.Token, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Scheduled notification not found");
        }

        return Results.Json(new Dictionary<string, object?> { ["success"] = true }, NotificationsJson.Answers.Answer);
    }

    private static async Task<bool> DeleteAsync(NpgsqlDataSource source, TimeProvider clock, int classId, int id, int token, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        var deleted = await tx.ExecuteAsync($"delete from notifications.class_scheduled_notifications where id = {id} and class_id = {classId}", ct);
        if (deleted == 0)
        {
            return false;
        }

        await Outbox.WriteAsync(tx, "notifications.class_schedule_deleted", new ScheduleDeleted(id, classId, token), NotificationsJson.Default.ScheduleDeleted, clock, ct);
        await tx.CommitAsync(ct);
        return true;
    }
}
