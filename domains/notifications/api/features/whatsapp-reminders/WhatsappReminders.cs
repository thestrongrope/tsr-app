using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Features.WhatsappReminders;

// Slice: GET /admin/whatsapp/reminders -> {reminders: [...]}: every reminder of the notifier with its audience, language and schedule. whatsapp:manage (403). A notifier error is its own status and text (NotifierAsk).
// PHP: routes/whatsapp_reminders.php route_admin_whatsapp_reminders (:92). Notifier call: GET /reminders. Contract: spec/api.yaml.
internal static class WhatsappRemindersSlice
{
    internal sealed record Listed(IEnumerable<WhatsAppReminder> Reminders);

    public static IEndpointRouteBuilder MapWhatsappReminders(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/whatsapp/reminders", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, Permissions permissions, INotifier notifier, CancellationToken ct)
    {
        var (_, refusal) = await NotifierAccess.RequireManagerAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (data, failed) = NotifierAsk.Interpret(await notifier.RemindersAsync(ct));
        return failed ?? Results.Json(new Listed(NotifierRows.Rows(data).Select(NotifierRows.Reminder).ToList()), NotificationsJson.Answers.RemindersListed);
    }
}
