using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Features.WhatsappLinkRelink;

// Slice: POST /admin/whatsapp/link/relink -> {ok: true}: clear the WhatsApp session; a new QR code follows. Cache-Control no-store, whatsapp:manage (403), 6 a minute per member (429, shared with logout), an admin audit row
// before the attempt (platform's RecordAdminAccessAsync), then the notifier; anything but its 200 is 502 "Re-link failed. The link is unchanged; please try again." The body is not read.
// PHP: routes/whatsapp_reminders.php route_admin_whatsapp_link_relink (:255). Notifier call: POST /relink {}. Contract: spec/api.yaml.
internal static class WhatsappLinkRelinkSlice
{
    public static IEndpointRouteBuilder MapWhatsappLinkRelink(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/whatsapp/link/relink", HandleAsync).RequireMember(createsMember: true, precheck: NotifierAccess.NoStore);
        return routes;
    }

    private static Task<IResult> HandleAsync(HttpContext context, Permissions permissions, MemberRateLimit limit, INotifier notifier, ILogger<Notifier> log, CancellationToken ct) =>
        NotifierLinkChange.RunAsync(context, permissions, limit, log, notifier.RelinkAsync, "whatsapp.relinked", "Re-link failed. The link is unchanged; please try again.", ct);
}
