using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Features.WhatsappLinkLogout;

// Slice: POST /admin/whatsapp/link/logout -> {ok: true}: end the session on WhatsApp's side too. Cache-Control no-store, whatsapp:manage (403), 6 a minute per member (429, shared with relink), an admin audit row before the attempt,
// then the notifier; anything but its 200 is 502 "Logout failed. The link is unchanged; please try again." The body is not read.
// PHP: routes/whatsapp_reminders.php route_admin_whatsapp_link_logout (:265). Notifier call: POST /logout {}. Contract: spec/api.yaml.
internal static class WhatsappLinkLogoutSlice
{
    public static IEndpointRouteBuilder MapWhatsappLinkLogout(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/whatsapp/link/logout", HandleAsync).RequireMember(createsMember: true, precheck: NotifierAccess.NoStore);
        return routes;
    }

    private static Task<IResult> HandleAsync(HttpContext context, Permissions permissions, MemberRateLimit limit, INotifier notifier, ILogger<Notifier> log, CancellationToken ct) =>
        NotifierLinkChange.RunAsync(context, permissions, limit, log, notifier.LogoutAsync, "whatsapp.logged_out", "Logout failed. The link is unchanged; please try again.", ct);
}
