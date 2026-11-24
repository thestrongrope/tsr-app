using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Features.WhatsappLink;

// Slice: GET /admin/whatsapp/link -> {state, lastSeen}: connected, waiting (for a scan) or offline. Cache-Control no-store is sent first, even on a refusal. whatsapp:manage (403), 90 a minute per member (429, shared
// with the QR route). A notifier that does not answer 200 with JSON is 503 "The reminder service cannot be reached right now. Trying again." Nothing of the answer is logged.
// PHP: routes/whatsapp_reminders.php route_admin_whatsapp_link (:207), WhatsAppRemindersModel::linkStatus. Notifier call: GET /status. Contract: spec/api.yaml.
internal static class WhatsappLinkSlice
{
    internal sealed record Link(string State, string? LastSeen);

    public static IEndpointRouteBuilder MapWhatsappLink(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/whatsapp/link", HandleAsync).RequireMember(createsMember: true, precheck: NotifierAccess.NoStore);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, Permissions permissions, MemberRateLimit limit, INotifier notifier, CancellationToken ct)
    {
        var (caller, refusal) = await NotifierAccess.RequireManagerAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var limited = NotifierAccess.LinkLimit(limit, caller!, "whatsapp_link_read", 90);
        if (limited is not null)
        {
            return limited;
        }

        var answer = await notifier.StatusAsync(ct);
        var data = answer.Status == StatusCodes.Status200OK ? NotifierAsk.Decode(answer.Body) : default;
        return data.ValueKind == System.Text.Json.JsonValueKind.Undefined ? NotifierAsk.LinkUnreachable() : Results.Json(new Link(StateOf(data), LastSeenOf(data)), NotificationsJson.Answers.Link);
    }

    internal static string StateOf(System.Text.Json.JsonElement data)
    {
        if (!NotifierRows.PhpEmpty(NotifierRows.Field(data, "connected")))
        {
            return "connected";
        }

        return NotifierRows.PhpEmpty(NotifierRows.Field(data, "awaiting_qr")) ? "offline" : "waiting";
    }

    internal static string? LastSeenOf(System.Text.Json.JsonElement data)
    {
        var seen = NotifierRows.Field(data, "last_seen");
        return seen.ValueKind == System.Text.Json.JsonValueKind.String && seen.GetString()!.Length > 0 ? seen.GetString() : null;
    }
}
