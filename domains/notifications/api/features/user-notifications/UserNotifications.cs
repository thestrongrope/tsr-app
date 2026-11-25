using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.UserNotifications;

// Slice: GET /user/notifications?limit&offset -> {notifications, total, unread_count, limit, offset}: the caller's own inbox, newest first. Contract: spec/api.yaml.
// PHP: routes/notifications.php route_user_notifications, MobileNotificationsModel::forUser, reminderClasses. notifications:read (403 "You do not have permission to do that"); limit (default 20)
// and offset (default 0) are whole numbers or 422 "Invalid limit" / "Invalid offset". Only rows of the caller's token are read. Items are camelCase except id and notification_id, as the app
// reads them; "classes" lists the classes a CC_NUDGE reminder covers (the ones that still exist), empty for every other notification. Deviation: limit is cut to 200 (PHP has no cap) and
// the echoed limit stays what was asked; ties on sent_at are ordered by id.

internal static class UserNotificationsSlice
{
    internal sealed record InboxRow(int Id, int NotificationId, string Title, string Body, string? ActionLink, string? Criteria, DateTimeOffset SentAt, short IsRead, DateTimeOffset? ReadAt);

    public static IEndpointRouteBuilder MapUserNotifications(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/user/notifications", HandleAsync).RequireMember(createsMember: true);
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

        var limit = NotifyGuards.IntParam(context, "limit", 20);
        if (limit is null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Invalid limit");
        }

        var offset = NotifyGuards.IntParam(context, "offset", 0);
        if (offset is null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Invalid offset");
        }

        var (take, skip) = NotifyGuards.Page(limit.Value, offset.Value);
        var rows = await source.ListAsync(
            $"""
                select un.id as "Id", un.notification_id as "NotificationId", n.title as "Title", n.body as "Body", n.action_link as "ActionLink",
                       n.target_audience_criteria as "Criteria", n.sent_at as "SentAt", un.is_read as "IsRead", un.read_at as "ReadAt"
                from notifications.user_notifications un
                join notifications.notifications n on un.notification_id = n.notification_id
                where un.user_token = {caller.Token}
                order by n.sent_at desc, un.id desc
                limit {take} offset {skip}
                """,
            row => new InboxRow(
                row.Int("Id"),
                row.Int("NotificationId"),
                row.Text("Title"),
                row.Text("Body"),
                row.TextOrNull("ActionLink"),
                row.TextOrNull("Criteria"),
                row.Instant("SentAt"),
                row.Short("IsRead"),
                row.InstantOrNull("ReadAt")),
            ct);
        var covered = await ReminderClassesAsync(source, rows, ct);
        var total = (await source.ListAsync($"""select count(*) as "Value" from notifications.user_notifications where user_token = {caller.Token}""", row => row.Long("Value"), ct))[0];
        var unread = (await source.ListAsync($"""select count(*) as "Value" from notifications.user_notifications where user_token = {caller.Token} and is_read = 0""", row => row.Long("Value"), ct))[0];

        var items = rows.Select(r => Item(r, covered)).ToList();
        return Results.Json(new Dictionary<string, object?>
        {
            ["notifications"] = items,
            ["total"] = total,
            ["unread_count"] = unread,
            ["limit"] = limit.Value,
            ["offset"] = offset.Value,
        }, NotificationsJson.Answers.Answer);
    }

    private static Dictionary<string, object?> Item(InboxRow row, Dictionary<int, List<Dictionary<string, object?>>> covered) => new()
    {
        ["id"] = row.Id,
        ["notification_id"] = row.NotificationId,
        ["title"] = row.Title,
        ["body"] = row.Body,
        ["actionLink"] = string.IsNullOrEmpty(row.ActionLink) ? null : row.ActionLink,
        ["sentAt"] = NotifyGuards.IsoStamp(row.SentAt),
        ["isRead"] = row.IsRead == 1,
        ["readAt"] = row.ReadAt is null ? null : NotifyGuards.IsoStamp(row.ReadAt.Value),
        ["classes"] = covered.TryGetValue(row.NotificationId, out var classes) ? classes : [],
    };

    // Only CC_NUDGE rows have any: the class ids of their criteria, named once for the whole page; a class that no longer exists is left out.
    private static async Task<Dictionary<int, List<Dictionary<string, object?>>>> ReminderClassesAsync(NpgsqlDataSource source, List<InboxRow> rows, CancellationToken ct)
    {
        var idsByNotification = new Dictionary<int, List<int>>();
        foreach (var row in rows)
        {
            var criteria = Criteria.Parse(row.Criteria);
            if (Criteria.TypeOf(criteria) == "CC_NUDGE" && criteria!.Value.TryGetProperty("classes", out var classes) && classes.ValueKind is JsonValueKind.Array or JsonValueKind.Object)
            {
                idsByNotification[row.NotificationId] = Criteria.PositiveIds(JsonBody.Entries(classes).Select(e => e.Value));
            }
        }

        var names = await Criteria.ClassNamesAsync(source, idsByNotification.Values.SelectMany(ids => ids), ct);
        var covered = new Dictionary<int, List<Dictionary<string, object?>>>();
        foreach (var (notificationId, ids) in idsByNotification)
        {
            var list = ids.Where(names.ContainsKey).Select(id => new Dictionary<string, object?> { ["id"] = id, ["name"] = names[id] }).ToList();
            if (list.Count > 0)
            {
                covered[notificationId] = list;
            }
        }

        return covered;
    }
}
