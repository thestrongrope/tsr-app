using Microsoft.AspNetCore.Routing;
using Tsr.Notifications.Api.Features.WhatsappLink;
using Tsr.Notifications.Api.Features.WhatsappLinkLogout;
using Tsr.Notifications.Api.Features.WhatsappLinkQr;
using Tsr.Notifications.Api.Features.WhatsappLinkRelink;
using Tsr.Notifications.Api.Features.WhatsappReminderRun;
using Tsr.Notifications.Api.Features.WhatsappReminders;
using Tsr.Notifications.Api.Features.WhatsappReminderUpdate;
using Tsr.Notifications.Api.Features.WhatsappRun;
using Tsr.Notifications.Api.Features.WhatsappRuns;
using Tsr.Notifications.Api.Features.WhatsappTest;

namespace Tsr.Notifications.Api;

/// <summary>The ten /admin/whatsapp/* routes: proxies to the notifier (domain/Notifier.cs). No table of this domain is used.</summary>
internal static class WhatsAppRoutes
{
    public static IEndpointRouteBuilder MapWhatsApp(this IEndpointRouteBuilder routes)
    {
        routes.MapWhatsappReminders();
        routes.MapWhatsappReminderUpdate();
        routes.MapWhatsappReminderRun();
        routes.MapWhatsappRuns();
        routes.MapWhatsappRun();
        routes.MapWhatsappTest();
        routes.MapWhatsappLink();
        routes.MapWhatsappLinkQr();
        routes.MapWhatsappLinkRelink();
        routes.MapWhatsappLinkLogout();
        return routes;
    }
}
