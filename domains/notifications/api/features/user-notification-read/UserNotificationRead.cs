using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.UserNotificationRead;

// Slice: POST /user/notifications/{notification_id}/read -> {ok: true}: mark one inbox row read. Contract: spec/api.yaml.
// PHP: routes/notifications.php route_user_notification_read, MobileNotificationsModel::markRead. notifications:read (403 "You do not have permission to do that"). The id in the path is the
// INBOX ROW id (user_notifications.id), not the notification id, despite the name. The update is scoped to the caller's token: someone else's row, or none, changes nothing and still
// answers ok (a silent no-op, not a 404, as PHP). The id is PHP's (int) cast of the segment.

internal static class UserNotificationReadSlice
{
    public static IEndpointRouteBuilder MapUserNotificationRead(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/user/notifications/{notification_id}/read", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string notification_id, HttpContext context, NotificationsContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "notifications:read", AccessTarget.None, ct))
        {
            return NotifyGuards.NotPermitted();
        }

        var id = NotifyGuards.IdOf(notification_id);
        var now = clock.GetUtcNow();
        await db.Database.ExecuteSqlAsync($"update notifications.user_notifications set is_read = 1, read_at = {now} where id = {id} and user_token = {caller.Token}", ct);
        return Results.Json(new Dictionary<string, object> { ["ok"] = true });
    }
}
