using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.NotificationsHistory;

// Slice: GET /notifications/history?limit&offset -> {notifications, limit, offset, count}: what has been sent, newest first, with who sent it and who it reached. Contract: spec/api.yaml.
// PHP: routes/notifications.php route_notifications_history, MobileNotificationsModel::history and describe. notifications:broadcast (403 "Only super administrators can view notification history"),
// the admin audit row, limit (default 50) and offset (default 0) whole numbers or 422 "Invalid limit" / "Invalid offset". The sender is joined through the member's token, which is not unique:
// a sender whose token is shared by two accounts appears once per account (PHP's flaw, kept). Each item carries the decoded criteria (an empty one as [], as PHP), the audience in words
// (domain/AudienceWords.cs) and how many inbox rows it has. Deviation: limit is cut to 200 (PHP has no cap); the echoed limit stays what was asked.

internal static class NotificationsHistorySlice
{
    internal sealed record HistoryRow(
        int NotificationId,
        string Title,
        string Body,
        string TargetAudienceCriteria,
        int? DeviceCount,
        int? SuccessCount,
        int? FailureCount,
        DateTimeOffset SentAt,
        string? ActionLink,
        string? SenderName,
        string? SenderEmail);

    internal sealed record Recipients(int NotificationId, long Count);

    public static IEndpointRouteBuilder MapNotificationsHistory(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/notifications/history", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NotificationsContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var refusal = await NotifyGuards.AdminAsync(context, db, permissions, caller, "view notification history", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var limit = NotifyGuards.IntParam(context, "limit", 50);
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
        var rows = await db.Database
            .SqlQuery<HistoryRow>($"""
                select n.notification_id as "NotificationId", n.title as "Title", n.body as "Body", n.target_audience_criteria as "TargetAudienceCriteria",
                       n.device_count as "DeviceCount", n.success_count as "SuccessCount", n.failure_count as "FailureCount", n.sent_at as "SentAt",
                       n.action_link as "ActionLink", m.name as "SenderName", u.email as "SenderEmail"
                from notifications.notifications n
                left join identity.v_users u on n.created_by = u.token and u.token > 0
                left join membership.v_members m on m.user_id = u.id
                order by n.sent_at desc, n.notification_id desc
                limit {take} offset {skip}
                """)
            .ToListAsync(ct);

        var criteria = rows.ToDictionary(r => r.NotificationId, r => Criteria.Parse(r.TargetAudienceCriteria));
        var names = await AudienceWords.LookUpAsync(db, AudienceWords.IdsNeeded(criteria.Values), ct);
        var counts = await RecipientCountsAsync(db, rows.Select(r => r.NotificationId).Distinct().ToArray(), ct);
        var items = rows.Select(r => Item(r, criteria[r.NotificationId], names, counts)).ToList();
        return Results.Json(new Dictionary<string, object>
        {
            ["notifications"] = items,
            ["limit"] = limit.Value,
            ["offset"] = offset.Value,
            ["count"] = items.Count,
        });
    }

    private static async Task<Dictionary<int, long>> RecipientCountsAsync(NotificationsContext db, int[] ids, CancellationToken ct)
    {
        if (ids.Length == 0)
        {
            return [];
        }

        var rows = await db.Database
            .SqlQuery<Recipients>($"""
                select notification_id as "NotificationId", count(*) as "Count" from notifications.user_notifications
                where notification_id = any({ids}) group by notification_id
                """)
            .ToListAsync(ct);
        return rows.ToDictionary(r => r.NotificationId, r => r.Count);
    }

    private static Dictionary<string, object?> Item(HistoryRow row, JsonElement? criteria, AudienceNames names, Dictionary<int, long> counts)
    {
        var about = AudienceWords.Describe(criteria, names);
        return new Dictionary<string, object?>
        {
            ["notification_id"] = row.NotificationId,
            ["title"] = row.Title,
            ["body"] = row.Body,
            ["device_count"] = row.DeviceCount ?? 0,
            ["success_count"] = row.SuccessCount ?? 0,
            ["failure_count"] = row.FailureCount ?? 0,
            ["sent_at"] = NotifyGuards.IsoStamp(row.SentAt),
            ["action_link"] = string.IsNullOrEmpty(row.ActionLink) ? null : row.ActionLink,
            ["sender_name"] = string.IsNullOrEmpty(row.SenderName) ? null : PhpText.HtmlDecode(row.SenderName),
            ["sender_email"] = string.IsNullOrEmpty(row.SenderEmail) ? null : row.SenderEmail,
            ["target_audience_criteria"] = DecodedCriteria(criteria),
            ["audience_summary"] = about.Summary,
            ["audience_items"] = about.Items,
            ["recipient_count"] = counts.GetValueOrDefault(row.NotificationId),
        };
    }

    // json_decode(..., true) then json_encode: an empty object comes back as an empty list.
    private static object? DecodedCriteria(JsonElement? criteria) =>
        criteria is null ? null : criteria.Value is { ValueKind: JsonValueKind.Object } o && !o.EnumerateObject().Any() ? Array.Empty<object>() : criteria.Value;
}
