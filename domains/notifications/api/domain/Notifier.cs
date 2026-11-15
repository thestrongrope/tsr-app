using System.Globalization;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Tsr.Notifications.Api.Domain;

/// <summary>
/// The notifier over HTTP, 30 seconds a call as PHP's curl and 1 MB of answer at most (the client's settings). Every path is a literal or built from an integer, so a caller cannot steer a request
/// to another path; redirects are not followed (PHP's curl did not). Nothing sent or received is logged: bodies carry phone numbers, messages and the QR credential. A refusal to connect, a timeout
/// or an oversized answer is <see cref="NotifierAnswer.Unreachable"/> (PHP also appended curl's error text; that is left out, it names internal hosts).
/// </summary>
internal sealed class Notifier(HttpClient http, IOptions<NotifierSettings> settings) : INotifier
{
    public Task<NotifierAnswer> StatusAsync(CancellationToken ct) => SendAsync(HttpMethod.Get, "status", null, ct);

    public Task<NotifierAnswer> QrAsync(CancellationToken ct) => SendAsync(HttpMethod.Get, "qr", null, ct);

    public Task<NotifierAnswer> RemindersAsync(CancellationToken ct) => SendAsync(HttpMethod.Get, "reminders", null, ct);

    public Task<NotifierAnswer> RecentRunsAsync(string? limit, string? reminderId, CancellationToken ct)
    {
        var query = new List<string>();
        AddDigits(query, "limit", limit);
        AddDigits(query, "reminder_id", reminderId);
        return SendAsync(HttpMethod.Get, "recent-runs" + (query.Count > 0 ? "?" + string.Join('&', query) : string.Empty), null, ct);
    }

    public Task<NotifierAnswer> RunAsync(long id, CancellationToken ct) => SendAsync(HttpMethod.Get, "runs/" + Id(id), null, ct);

    public Task<NotifierAnswer> RunMessagesAsync(long id, CancellationToken ct) => SendAsync(HttpMethod.Get, "runs/" + Id(id) + "/messages", null, ct);

    public Task<NotifierAnswer> RelinkAsync(CancellationToken ct) => SendAsync(HttpMethod.Post, "relink", "{}", ct);

    public Task<NotifierAnswer> LogoutAsync(CancellationToken ct) => SendAsync(HttpMethod.Post, "logout", "{}", ct);

    public Task<NotifierAnswer> UpdateReminderAsync(long id, IReadOnlyDictionary<string, JsonElement> fields, int token, CancellationToken ct) =>
        SendAsync(HttpMethod.Put, "reminders/" + Id(id), JsonSerializer.Serialize(new { fields, updated_by = token }), ct);

    public Task<NotifierAnswer> RunWeeklyAsync(long reminderId, bool dryRun, int token, CancellationToken ct) =>
        SendAsync(HttpMethod.Post, "run-weekly", JsonSerializer.Serialize(new { reminder_id = reminderId, dry_run = dryRun, triggered_by = token }), ct);

    public Task<NotifierAnswer> SendTestAsync(string mobile, string message, int token, CancellationToken ct) =>
        SendAsync(HttpMethod.Post, "send-test", JsonSerializer.Serialize(new { mobile, message, triggered_by = token }), ct);

    private static string Id(long id) => id.ToString(CultureInfo.InvariantCulture);

    // Callers pass digits only (checked in the slice); anything else is left out rather than forwarded.
    private static void AddDigits(List<string> query, string name, string? value)
    {
        if (!string.IsNullOrEmpty(value) && value.All(char.IsAsciiDigit))
        {
            query.Add(name + "=" + value);
        }
    }

    private async Task<NotifierAnswer> SendAsync(HttpMethod method, string relative, string? json, CancellationToken ct)
    {
        var baseUri = settings.Value.BaseUri;
        if (baseUri is null)
        {
            return NotifierAnswer.Unreachable;
        }

        using var request = new HttpRequestMessage(method, new Uri(baseUri, relative));
        if (json is not null)
        {
            request.Content = new StringContent(json, Encoding.UTF8, "application/json");
        }

        try
        {
            using var response = await http.SendAsync(request, ct);
            return new NotifierAnswer((int)response.StatusCode, await response.Content.ReadAsStringAsync(ct));
        }
        catch (HttpRequestException)
        {
            return NotifierAnswer.Unreachable;
        }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested)
        {
            return NotifierAnswer.Unreachable;
        }
    }
}
