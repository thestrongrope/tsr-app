using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Features.WhatsappRuns;

// Slice: GET /admin/whatsapp/runs?reminderId=&limit= -> {runs: [...]}: recent runs, newest first. whatsapp:manage (403). A query value is passed on only when it is plain digits (PHP ctype_digit), at most 18 of them
// (deviation: PHP forwards any length); the last of a repeated key counts. The limit itself is the notifier's (10 when absent).
// PHP: routes/whatsapp_reminders.php route_admin_whatsapp_runs (:130). Notifier call: GET /recent-runs?limit=&reminder_id=. Contract: spec/api.yaml.
internal static class WhatsappRunsSlice
{
    private const int MaxDigits = 18;

    internal sealed record Listed(IEnumerable<WhatsAppRun> Runs);

    public static IEndpointRouteBuilder MapWhatsappRuns(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/whatsapp/runs", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    internal static string? Digits(string? value) =>
        !string.IsNullOrEmpty(value) && value.Length <= MaxDigits && value.All(char.IsAsciiDigit) ? value : null;

    private static async Task<IResult> HandleAsync(HttpContext context, Permissions permissions, INotifier notifier, CancellationToken ct)
    {
        var (_, refusal) = await NotifierAccess.RequireManagerAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var query = context.Request.Query;
        var answer = await notifier.RecentRunsAsync(Digits(query["limit"].LastOrDefault()), Digits(query["reminderId"].LastOrDefault()), ct);
        var (data, failed) = NotifierAsk.Interpret(answer);
        return failed ?? Results.Json(new Listed(NotifierRows.Rows(data).Select(NotifierRows.Run).ToList()));
    }
}
