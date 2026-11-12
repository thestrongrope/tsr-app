using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Features.WhatsappReminderUpdate;

// Slice: PUT /admin/whatsapp/reminders/{reminder_id} {gender, city, country, levels, lang, leewayDays, timezone, weekday, sendTime, scheduleOn, enabled} -> {reminder}: change the fields sent (a key that is present counts,
// even null). whatsapp:manage (403), then the body (422 "Invalid JSON body"). The values are the notifier's to judge (its 400 text reaches the caller, nothing saved); here a string with a NUL byte or over 500 characters is a 422.
// The id is PHP's (int) of the segment: "abc" is 0 and the notifier call is never made (400 "missing or invalid id"). Event: none (PHP logs whatsapp.reminder_updated, field names only).
// PHP: routes/whatsapp_reminders.php route_admin_whatsapp_reminder_update (:106). Notifier call: PUT /reminders/{id} {fields (snake_case names), updated_by: token}. Contract: spec/api.yaml.
internal static partial class WhatsappReminderUpdateSlice
{
    private static readonly (string App, string Notifier)[] Names =
    [
        ("gender", "gender"), ("city", "city"), ("country", "country"), ("levels", "levels"), ("lang", "lang"),
        ("leewayDays", "leeway_days"), ("timezone", "timezone"), ("weekday", "weekday"),
        ("sendTime", "send_time"), ("scheduleOn", "schedule_on"), ("enabled", "enabled"),
    ];

    internal sealed record Updated(WhatsAppReminder Reminder);

    [LoggerMessage(Level = LogLevel.Information, Message = "whatsapp.reminder_updated reminder={Reminder} fields={Fields}")]
    private static partial void LogUpdated(ILogger logger, long reminder, string fields);

    public static IEndpointRouteBuilder MapWhatsappReminderUpdate(this IEndpointRouteBuilder routes)
    {
        routes.MapPut("/admin/whatsapp/reminders/{reminder_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

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

        var fields = new Dictionary<string, JsonElement>();
        foreach (var (app, notifierName) in Names.Where(name => body!.Has(name.App)))
        {
            var problem = NotifierAccess.JsonTextProblem(app, body!.Get(app), NotifierAccess.MaxFieldText);
            if (problem is not null)
            {
                return Problem.Detail(StatusCodes.Status422UnprocessableEntity, problem);
            }

            fields[notifierName] = body.Get(app);
        }

        var id = NotifierAccess.IdOf(reminder_id);
        if (id <= 0)
        {
            return Problem.Detail(StatusCodes.Status400BadRequest, "missing or invalid id");
        }

        var (data, failed) = NotifierAsk.Interpret(await notifier.UpdateReminderAsync(id, fields, caller!.Token, ct));
        if (failed is not null)
        {
            return failed;
        }

        var changed = string.Join(',', fields.Keys);
        LogUpdated(log, id, changed);
        return Results.Json(new Updated(NotifierRows.Reminder(data)));
    }
}
