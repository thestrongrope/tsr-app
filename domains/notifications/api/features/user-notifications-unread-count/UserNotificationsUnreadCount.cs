using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.UserNotificationsUnreadCount;

// Slice: GET /user/notifications/unread-count -> {unread_count}: how many of the caller's own inbox rows are unread. Contract: spec/api.yaml.
// PHP: routes/notifications.php route_user_notifications_unread_count, MobileNotificationsModel::countUnread. notifications:read (403 "You do not have permission to do that").

internal static class UserNotificationsUnreadCountSlice
{
    public static IEndpointRouteBuilder MapUserNotificationsUnreadCount(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/user/notifications/unread-count", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
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

        var counts = await source.ListAsync(
            $"""select count(*) as "Value" from notifications.user_notifications where user_token = {caller.Token} and is_read = 0""",
            row => row.Long("Value"),
            ct);
        return Results.Json(new Dictionary<string, object?> { ["unread_count"] = counts[0] }, NotificationsJson.Answers.Answer);
    }
}
