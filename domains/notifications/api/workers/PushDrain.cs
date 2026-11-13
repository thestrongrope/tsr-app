using System.Collections.Concurrent;
using System.Globalization;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Tsr.Notifications.Api.Domain;
using Tsr.Platform.Api;

namespace Tsr.Notifications.Api.Workers;

/// <summary>
/// What one tick did, in rows. <c>Lost</c> is a row whose claim another worker took over before this one recorded the result (nothing was overwritten). <c>InvalidTokens</c> is how many tokens FCM called unknown or invalid
/// (logged as a count only; no device row is deleted). <c>Unrecorded</c> is a row whose result could not be written (the database failed for it): it stays <c>sending</c> until the queue's lease takes it over.
/// </summary>
internal sealed record DrainReport(int Claimed, int Sent, int Retrying, int Dead, int Released, int Lost, int InvalidTokens, int Unrecorded)
{
    public DrainReport Plus(DrainReport other) => new(
        Claimed + other.Claimed,
        Sent + other.Sent,
        Retrying + other.Retrying,
        Dead + other.Dead,
        Released + other.Released,
        Lost + other.Lost,
        InvalidTokens + other.InvalidTokens,
        Unrecorded + other.Unrecorded);
}

/// <summary>
/// PHP <c>cli/drain_push.php</c> as one batch: claim up to <see cref="MaxRows"/> due <c>push</c> rows from platform's queue, send each to its one device (at most <see cref="PushBatch.Parallelism"/> at a time, the sender's own 10 s timeout),
/// then record every outcome. The claim commits before any send. Outcomes, as PHP: sent; a past <c>deadline</c> or an unusable payload is dead without a send; FCM calling the token unknown or invalid, or any other failure of this message, burns the attempt
/// (backoff, dead after the 5th); a sender mismatch is dead at once; the service being unusable (<see cref="PushResult.Unavailable"/>) releases the row and every row not yet started, with the attempt given back, and no further send starts.
/// A sender that THROWS counts as a failure of that one message (the attempt is burnt): the push may or may not have left, and a bounded retry with backoff is safer than a release, which would retry every minute with no ceiling and stop the batch.
/// The host stopping starts no new send; the sends in flight finish (the sender's own 10 s timeout) and every result is recorded, each row on its own, so one failed write does not leave the others unrecorded.
/// Faster than PHP on purpose (owner decision, 12 Nov 2026): PHP sends one batch a minute; a tick here takes batch after batch until the queue has nothing due, a batch released a row (the service is unusable or the host is stopping),
/// or <see cref="ClaimFor"/> has passed since the tick began (the batch in hand is always finished). A failed row is not taken again in the same tick: its backoff is at least a minute.
/// The error column and the log hold short reason codes and counts only, never a token, a title or a body. A device row is never deleted here (the cleanup route owns that).
/// </summary>
internal static partial class PushDrain
{
    public const string Channel = "push";
    public const int MaxRows = 50;

    /// <summary>How long one tick goes on claiming batches: under the worker's one minute, so ticks keep their rhythm.</summary>
    public static readonly TimeSpan ClaimFor = TimeSpan.FromSeconds(50);

    private static readonly DrainReport Nothing = new(0, 0, 0, 0, 0, 0, 0, 0);

    private sealed record Plan(ClaimedMessage Row, string? DeadReason, PushMessage? Message);

    private enum Outcome
    {
        Sent,
        Retrying,
        Dead,
        Released,
        Lost,
        Unrecorded,
    }

    public static async Task<DrainReport> TickAsync(NotificationsContext db, IPushSender sender, TimeProvider clock, ILogger log, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(sender);
        ArgumentNullException.ThrowIfNull(clock);
        ArgumentNullException.ThrowIfNull(log);
        if (!sender.IsConfigured)
        {
            LogNotConfigured(log);
            return Nothing;
        }

        var claimUntil = clock.GetUtcNow() + ClaimFor;
        var total = Nothing;
        while (true)
        {
            var batch = await BatchAsync(db, sender, clock, log, ct);
            total = total.Plus(batch);
            if (batch.Claimed < MaxRows || batch.Released > 0 || ct.IsCancellationRequested || clock.GetUtcNow() >= claimUntil)
            {
                return total;
            }
        }
    }

    private static async Task<DrainReport> BatchAsync(NotificationsContext db, IPushSender sender, TimeProvider clock, ILogger log, CancellationToken ct)
    {
        var rows = await PlatformCommands.ClaimMessagesAsync(db, Channel, MaxRows, clock.GetUtcNow(), ct);
        if (rows.Count == 0)
        {
            return Nothing;
        }

        var now = clock.GetUtcNow();
        var plans = rows.Select(row => PlanOf(row, now)).ToList();
        var results = await SendAllAsync(sender, plans, log, ct);
        var report = await RecordAllAsync(db, plans, results, clock, log);
        LogDrained(log, report.Claimed, report.Sent, report.Retrying, report.Dead, report.Released, report.Lost, report.InvalidTokens, report.Unrecorded);
        return report;
    }

    // Reads the payload {title, body, data, deadline?}. Order as PHP: the deadline first, then the title and body. A deadline that cannot be read counts as none (PHP strtotime false).
    private static Plan PlanOf(ClaimedMessage row, DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(row.Payload))
        {
            return new Plan(row, "payload_invalid", null);
        }

        try
        {
            using var document = JsonDocument.Parse(row.Payload);
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object)
            {
                return new Plan(row, "payload_invalid", null);
            }

            if (PastDeadline(root, now))
            {
                return new Plan(row, "past_deadline", null);
            }

            var title = TextOf(root, "title");
            var body = TextOf(root, "body");
            if (title.Length == 0 || body.Length == 0)
            {
                return new Plan(row, "payload_invalid", null);
            }

            return new Plan(row, null, PushBatch.Message(title, body, DataOf(root)));
        }
        catch (JsonException)
        {
            return new Plan(row, "payload_invalid", null);
        }
    }

    private static bool PastDeadline(JsonElement root, DateTimeOffset now) =>
        TextOf(root, "deadline") is { Length: > 0 } text
        && DateTimeOffset.TryParse(text, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var deadline)
        && now > deadline;

    private static string TextOf(JsonElement root, string name) =>
        root.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? (value.GetString() ?? string.Empty).Trim() : string.Empty;

    // FCM refuses data that is not a string, so each value becomes one as PHP's (string) cast does: true is "1", false and null are "".
    private static Dictionary<string, string> DataOf(JsonElement root)
    {
        var data = new Dictionary<string, string>(StringComparer.Ordinal);
        if (!root.TryGetProperty("data", out var node) || node.ValueKind != JsonValueKind.Object)
        {
            return data;
        }

        foreach (var property in node.EnumerateObject())
        {
            data[property.Name] = property.Value.ValueKind switch
            {
                JsonValueKind.String => property.Value.GetString() ?? string.Empty,
                JsonValueKind.True => "1",
                JsonValueKind.False or JsonValueKind.Null => string.Empty,
                _ => property.Value.GetRawText(),
            };
        }

        return data;
    }

    // The sends run in parallel and touch no database context (it is not thread safe). The first Unavailable answer, or the host stopping, stops further sends from STARTING; the ones already running are never cancelled
    // (one may have been delivered, and releasing it would send it twice): neither the loop nor a send takes the host's token, each send ends within the sender's own timeout. A row with no result was not sent.
    private static async Task<ConcurrentDictionary<long, PushResult>> SendAllAsync(IPushSender sender, List<Plan> plans, ILogger log, CancellationToken ct)
    {
        var results = new ConcurrentDictionary<long, PushResult>();
        var stopped = 0;
        await Parallel.ForEachAsync(
            plans.Where(p => p.Message is not null),
            new ParallelOptions { MaxDegreeOfParallelism = PushBatch.Parallelism },
            async (plan, _) =>
            {
                if (ct.IsCancellationRequested || Volatile.Read(ref stopped) != 0)
                {
                    return;
                }

                var result = await SendOneAsync(sender, plan, log);
                results[plan.Row.Id] = result;
                if (result == PushResult.Unavailable)
                {
                    Volatile.Write(ref stopped, 1);
                }
            });
        return results;
    }

    // An exception the sender did not turn into a result must not lose the batch's other results. It is a failure of this message (see the class summary); only its type is logged, a message could hold a token.
    private static async Task<PushResult> SendOneAsync(IPushSender sender, Plan plan, ILogger log)
    {
        try
        {
            return await sender.SendAsync(plan.Message!, plan.Row.Recipient, CancellationToken.None);
        }
        catch (Exception e)
        {
            LogSendThrew(log, plan.Row.Id, e.GetType().Name);
            return PushResult.Failed;
        }
    }

    // Results are written with no cancellation (each command has the database's own 5 s timeout): a stop must not leave a delivered push unrecorded. Each row is recorded on its own:
    // a write that fails is logged and the loop goes on, so the rows after it are not left "sending" to be sent again.
    private static async Task<DrainReport> RecordAllAsync(NotificationsContext db, List<Plan> plans, ConcurrentDictionary<long, PushResult> results, TimeProvider clock, ILogger log)
    {
        var counts = new Dictionary<Outcome, int>();
        var invalid = 0;
        foreach (var plan in plans)
        {
            var result = results.TryGetValue(plan.Row.Id, out var found) ? found : PushResult.Unavailable;
            invalid += result == PushResult.TokenInvalid ? 1 : 0;
            var outcome = await RecordSafelyAsync(db, plan, result, clock.GetUtcNow(), log);
            counts[outcome] = counts.GetValueOrDefault(outcome) + 1;
        }

        return new DrainReport(
            plans.Count,
            counts.GetValueOrDefault(Outcome.Sent),
            counts.GetValueOrDefault(Outcome.Retrying),
            counts.GetValueOrDefault(Outcome.Dead),
            counts.GetValueOrDefault(Outcome.Released),
            counts.GetValueOrDefault(Outcome.Lost),
            invalid,
            counts.GetValueOrDefault(Outcome.Unrecorded));
    }

    private static async Task<Outcome> RecordSafelyAsync(NotificationsContext db, Plan plan, PushResult result, DateTimeOffset now, ILogger log)
    {
        try
        {
            return await RecordOneAsync(db, plan, result, now);
        }
        catch (Exception e)
        {
            LogRecordFailed(log, plan.Row.Id, e.GetType().Name);
            return Outcome.Unrecorded;
        }
    }

    private static async Task<Outcome> RecordOneAsync(NotificationsContext db, Plan plan, PushResult result, DateTimeOffset now)
    {
        var row = plan.Row;
        var none = CancellationToken.None;
        if (plan.DeadReason is not null)
        {
            return await Settled(PlatformCommands.MarkDeadAsync(db, row.Id, row.Attempts, plan.DeadReason, none), Outcome.Dead);
        }

        switch (result)
        {
            case PushResult.Sent:
                return await Settled(PlatformCommands.MarkSentAsync(db, row.Id, row.Attempts, now, none), Outcome.Sent);
            case PushResult.SenderMismatch:
                return await Settled(PlatformCommands.MarkDeadAsync(db, row.Id, row.Attempts, "sender_mismatch", none), Outcome.Dead);
            case PushResult.TokenInvalid:
                return await Failed(db, row, "token_invalid", now);
            case PushResult.Failed:
                return await Failed(db, row, "send_failed", now);
            default:
                return await Settled(PlatformCommands.ReleaseMessageAsync(db, row.Id, row.Attempts, none), Outcome.Released);
        }
    }

    private static async Task<Outcome> Failed(NotificationsContext db, ClaimedMessage row, string reason, DateTimeOffset now) =>
        await PlatformCommands.MarkFailedAsync(db, row.Id, row.Attempts, reason, now, CancellationToken.None) switch
        {
            "queued" => Outcome.Retrying,
            "dead" => Outcome.Dead,
            _ => Outcome.Lost,
        };

    private static async Task<Outcome> Settled(Task<bool> changed, Outcome outcome) => await changed ? outcome : Outcome.Lost;

    [LoggerMessage(Level = LogLevel.Information, Message = "Push drain: claimed {Claimed}, sent {Sent}, retrying {Retrying}, dead {Dead}, released {Released}, lost to another worker {Lost}, tokens FCM rejected {Invalid}, results not recorded {Unrecorded}")]
    private static partial void LogDrained(ILogger logger, int claimed, int sent, int retrying, int dead, int released, int lost, int invalid, int unrecorded);

    [LoggerMessage(Level = LogLevel.Error, Message = "Push drain: the sender threw {Kind} for queue row {Id}; counted as a failed attempt")]
    private static partial void LogSendThrew(ILogger logger, long id, string kind);

    [LoggerMessage(Level = LogLevel.Error, Message = "Push drain: the result of queue row {Id} could not be recorded: {Kind}; the row stays sending until its lease ends")]
    private static partial void LogRecordFailed(ILogger logger, long id, string kind);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Push drain: the push sender is not configured (TSR_GOOGLE_SERVICE_ACCOUNT_B64), claiming nothing")]
    private static partial void LogNotConfigured(ILogger logger);
}
