namespace Tsr.Notifications.Api.Domain;

/// <summary>The counts of one push to many devices, and the device tokens FCM said are dead. <c>Invalid</c> holds device tokens: never log or return it.</summary>
internal sealed record PushReport(int Success, int Failure, IReadOnlyList<string> Invalid);

/// <summary>
/// PHP's <c>api_fcm_send</c> over <see cref="IPushSender"/>: the tokens are trimmed and made unique, the data gets PHP's <c>click_action</c>, every device is tried (a failure
/// counts, the rest still go). FCM v1 has no multicast, so this is one request per device with at most <see cref="Parallelism"/> in flight and <see cref="Deadline"/> for the whole batch;
/// devices not reached by then count as failures.
/// </summary>
internal static class PushBatch
{
    public const int Parallelism = 16;

    public static readonly TimeSpan Deadline = TimeSpan.FromSeconds(120);

    private const string ClickAction = "FLUTTER_NOTIFICATION_CLICK";

    /// <summary>The cut PHP applies to the pushed body (the inbox keeps the full text): 500 characters, never inside a surrogate pair.</summary>
    public static string CutBody(string body)
    {
        if (PhpText.CodePointCount(body) <= 500)
        {
            return body;
        }

        var runes = body.EnumerateRunes().Take(500).Select(r => r.ToString());
        return string.Concat(runes);
    }

    /// <summary>PHP's <c>gmdate('Y-m-d\TH:i:s.u')</c>: the microseconds are always zero.</summary>
    public static string SentAt(DateTimeOffset now) =>
        now.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture) + ".000000";

    public static async Task<PushReport> SendAsync(IPushSender sender, string title, string body, Dictionary<string, string> data, IEnumerable<string> deviceTokens, CancellationToken ct)
    {
        var tokens = deviceTokens.Select(PhpText.Trim).Where(t => t.Length > 0).Distinct(StringComparer.Ordinal).ToList();
        data["click_action"] = ClickAction;
        var message = new PushMessage(title, body, data);
        var invalid = new System.Collections.Concurrent.ConcurrentBag<string>();
        var success = 0;
        var failure = 0;

        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(ct);
        deadline.CancelAfter(Deadline);
        try
        {
            await Parallel.ForEachAsync(
                tokens,
                new ParallelOptions { MaxDegreeOfParallelism = Parallelism, CancellationToken = deadline.Token },
                async (token, inner) =>
                {
                    switch (await sender.SendAsync(message, token, inner))
                    {
                        case PushResult.Sent:
                            Interlocked.Increment(ref success);
                            break;
                        case PushResult.TokenInvalid:
                            invalid.Add(token);
                            Interlocked.Increment(ref failure);
                            break;
                        default:
                            Interlocked.Increment(ref failure);
                            break;
                    }
                });
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            failure = tokens.Count - success;
        }

        return new PushReport(success, failure, [.. invalid]);
    }
}
