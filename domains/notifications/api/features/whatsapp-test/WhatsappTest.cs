using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Features.WhatsappTest;

// Slice: POST /admin/whatsapp/test {mobile, message} -> {runId, status}: ONE real WhatsApp message to one number, recorded by the notifier as a run. whatsapp:manage (403), then the body (422 "Invalid JSON body").
// As PHP: each of mobile and message is its text trimmed, or empty when it is not a string; the notifier judges them (400 "mobile and message are required", 400 "invalid mobile number", 409 "WhatsApp not connected").
// Deviation: a NUL byte, a mobile over 40 characters or a message over 4096 is a 422 here (PHP forwards them). Event: none (PHP logs whatsapp.test_sent with the run id only; never the number or the text).
// PHP: routes/whatsapp_reminders.php route_admin_whatsapp_test (:176). Notifier call: POST /send-test {mobile, message, triggered_by: token}. Contract: spec/api.yaml.
internal static partial class WhatsappTestSlice
{
    private const int MaxMobile = 40;

    internal sealed record Sent(long RunId, string Status);

    [LoggerMessage(Level = LogLevel.Information, Message = "whatsapp.test_sent run={Run}")]
    private static partial void LogSent(ILogger logger, long run);

    public static IEndpointRouteBuilder MapWhatsappTest(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/whatsapp/test", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    /// <summary>PHP <c>is_string($body[$key] ?? null) ? trim($body[$key]) : ''</c>.</summary>
    internal static string TextOf(JsonBody body, string key)
    {
        var value = body.Get(key);
        return value.ValueKind == JsonValueKind.String ? PhpText.Trim(value.GetString()!) : string.Empty;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, Permissions permissions, INotifier notifier, ILogger<Notifier> log, CancellationToken ct)
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

        var mobile = TextOf(body!, "mobile");
        var message = TextOf(body!, "message");
        var problem = NotifierAccess.TextProblem("mobile", mobile, MaxMobile) ?? NotifierAccess.TextProblem("message", message, NotifierAccess.MaxText);
        if (problem is not null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, problem);
        }

        var (data, failed) = NotifierAsk.Interpret(await notifier.SendTestAsync(mobile, message, caller!.Token, ct));
        if (failed is not null)
        {
            return failed;
        }

        var runId = NotifierRows.Int(NotifierRows.Field(data, "run_id")) ?? 0;
        LogSent(log, runId);
        var status = NotifierRows.Field(data, "status");
        var statusText = status.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null ? "sent" : PhpValue.Text(status);
        return Results.Json(new Sent(runId, statusText), NotificationsJson.Answers.TestSent);
    }
}
