using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Features.WhatsappRun;

// Slice: GET /admin/whatsapp/runs/{run_id} -> {run, messages}: the run and each teacher it handled. whatsapp:manage (403). The id is PHP's (int) of the segment; 0 or less is 400 "missing or invalid id" and no notifier call.
// The notifier's refusals pass on with its status and text (404 "run not found"). The run is asked first, then its messages; a refusal of either is the answer.
// PHP: routes/whatsapp_reminders.php route_admin_whatsapp_run (:145). Notifier calls: GET /runs/{id}, GET /runs/{id}/messages. Contract: spec/api.yaml.
internal static class WhatsappRunSlice
{
    internal sealed record Detail(WhatsAppRun Run, IEnumerable<WhatsAppMessage> Messages);

    public static IEndpointRouteBuilder MapWhatsappRun(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/whatsapp/runs/{run_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string run_id, HttpContext context, Permissions permissions, INotifier notifier, CancellationToken ct)
    {
        var (_, refusal) = await NotifierAccess.RequireManagerAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var id = NotifierAccess.IdOf(run_id);
        if (id <= 0)
        {
            return Problem.Detail(StatusCodes.Status400BadRequest, "missing or invalid id");
        }

        var (run, runFailed) = NotifierAsk.Interpret(await notifier.RunAsync(id, ct));
        if (runFailed is not null)
        {
            return runFailed;
        }

        var (messages, messagesFailed) = NotifierAsk.Interpret(await notifier.RunMessagesAsync(id, ct));
        return messagesFailed ?? Results.Json(new Detail(NotifierRows.Run(run), NotifierRows.Rows(messages).Select(NotifierRows.Message).ToList()));
    }
}
