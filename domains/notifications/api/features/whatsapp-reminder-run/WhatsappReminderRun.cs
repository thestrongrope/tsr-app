using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Features.WhatsappReminderRun;

// Slice: POST /admin/whatsapp/reminders/{reminder_id}/run {dryRun} -> 202 {runId, dryRun}: start a run in the notifier. A dry run (previews who would be messaged, sends nothing) UNLESS dryRun is exactly the JSON
// literal false: a missing, null, malformed or any other value is a dry run, so it can never cause a real send by mistake. whatsapp:manage (403), then the body (422 "Invalid JSON body").
// The id is PHP's (int) of the segment; the notifier judges it (400 "reminder_id is required and must name a reminder", 409 switched off or a run in progress). The run goes on in the notifier; the app polls /admin/whatsapp/runs/{id}.
// PHP: routes/whatsapp_reminders.php route_admin_whatsapp_reminder_run (:163). Notifier call: POST /run-weekly {reminder_id, dry_run, triggered_by: token}. Event: none (PHP logs whatsapp.run_started). Contract: spec/api.yaml.
internal static partial class WhatsappReminderRunSlice
{
    internal sealed record Started(long RunId, bool DryRun);

    [LoggerMessage(Level = LogLevel.Information, Message = "whatsapp.run_started reminder={Reminder} dryRun={DryRun} run={Run}")]
    private static partial void LogStarted(ILogger logger, long reminder, bool dryRun, long run);

    public static IEndpointRouteBuilder MapWhatsappReminderRun(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/whatsapp/reminders/{reminder_id}/run", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    /// <summary>PHP <c>(api_body()['dryRun'] ?? true) !== false</c>.</summary>
    internal static bool IsDryRun(JsonBody body) => body.Get("dryRun").ValueKind != JsonValueKind.False;

    private static async Task<IResult> HandleAsync(string reminder_id, HttpContext context, Permissions permissions, INotifier notifier, ILogger<Notifier> log, CancellationToken ct)
    {
        var (caller, refusal) = await NotifierAccess.RequireManagerAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var dryRun = IsDryRun(body!);
        var id = NotifierAccess.IdOf(reminder_id);
        var (data, failed) = NotifierAsk.Interpret(await notifier.RunWeeklyAsync(id, dryRun, caller!.Token, ct));
        if (failed is not null)
        {
            return failed;
        }

        var runId = NotifierRows.Int(NotifierRows.Field(data, "run_id")) ?? 0;
        LogStarted(log, id, dryRun, runId);
        return Results.Json(new Started(runId, dryRun), statusCode: StatusCodes.Status202Accepted);
    }
}
