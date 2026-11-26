using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Features.WhatsappLinkQr;

// Slice: GET /admin/whatsapp/link/qr -> {qr, ageSeconds, validSeconds, stale}. THE QR CODE IS A LIVE CREDENTIAL for the linked WhatsApp account: Cache-Control no-store first (even on a refusal), never logged.
// whatsapp:manage (403), 90 a minute per member (429, shared with the link route). The notifier's 404 means no code yet: qr null, not stale. Any other answer that is not 200 with a non-empty qr text is 503
// "The reminder service cannot be reached right now. Trying again." A code of unknown age, negative age or older than 60 seconds is withheld (qr null, stale true), never passed on as current.
// PHP: routes/whatsapp_reminders.php route_admin_whatsapp_link_qr (:225), WhatsAppRemindersModel::linkQr (QR_VALID_SECONDS 60). Notifier call: GET /qr. Contract: spec/api.yaml.
internal static class WhatsappLinkQrSlice
{
    internal const int ValidSeconds = 60;

    internal sealed record Code(string? Qr, long? AgeSeconds, int ValidSeconds, bool Stale);

    public static IEndpointRouteBuilder MapWhatsappLinkQr(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/whatsapp/link/qr", HandleAsync).RequireMember(createsMember: true, precheck: NotifierAccess.NoStore);
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

        var code = Interpret(await notifier.QrAsync(ct));
        return code is null ? NotifierAsk.LinkUnreachable() : Results.Json(code, NotificationsJson.Answers.Code);
    }

    /// <summary>PHP linkQr: the code to send, or null when the notifier cannot be asked.</summary>
    internal static Code? Interpret(NotifierAnswer answer)
    {
        if (answer.Status == StatusCodes.Status404NotFound)
        {
            return new Code(null, null, ValidSeconds, false);
        }

        var data = answer.Status == StatusCodes.Status200OK ? NotifierAsk.Decode(answer.Body) : default;
        var qr = NotifierRows.Field(data, "qr");
        if (qr.ValueKind != JsonValueKind.String || qr.GetString()!.Length == 0)
        {
            return null;
        }

        var age = NotifierRows.Int(NotifierRows.Field(data, "generated_seconds_ago"));
        var stale = age is null or < 0 or > ValidSeconds;
        return new Code(stale ? null : qr.GetString(), age, ValidSeconds, stale);
    }
}
