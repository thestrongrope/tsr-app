using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.UserNotificationsReadAll;

// Slice: POST /user/notifications/read-all -> {ok: true}: mark every unread row of the caller's own inbox read. Contract: spec/api.yaml.
// PHP: routes/notifications.php route_user_notifications_read_all, MobileNotificationsModel::markAllRead. notifications:read (403 "You do not have permission to do that"). Only the caller's token.

internal static class UserNotificationsReadAllSlice
{
    public static IEndpointRouteBuilder MapUserNotificationsReadAll(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/user/notifications/read-all", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NotificationsContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
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

        var now = clock.GetUtcNow();
        await db.Database.ExecuteSqlAsync($"update notifications.user_notifications set is_read = 1, read_at = {now} where user_token = {caller.Token} and is_read = 0", ct);
        return Results.Json(new Dictionary<string, object> { ["ok"] = true });
    }
}
