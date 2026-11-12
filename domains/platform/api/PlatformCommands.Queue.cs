using Microsoft.EntityFrameworkCore;

namespace Tsr.Platform.Api;

/// <summary>One row taken from the delivery queue by <see cref="PlatformCommands.ClaimMessagesAsync"/>. <c>Payload</c> is the stored JSON text; <c>Recipient</c> is a device token or a number: never log either.</summary>
public sealed record ClaimedMessage(long Id, string Recipient, string? Payload, int Attempts);

/// <summary>
/// The delivery queue's published commands for a worker (PHP <c>OutboundMessagesModel</c>: <c>claim</c>, <c>markSent</c>, <c>markFailed</c>, <c>markDead</c>, <c>release</c>). Each is ONE statement on the caller's connection,
/// outside any transaction, so a claim commits before anything is sent. The clock comes from the caller. After a claim, every result command is guarded on <c>status = 'sending'</c> AND the <c>attempts</c> value the claim returned:
/// a row another worker has reclaimed since carries a higher count, so a late answer from the first worker changes nothing (the command answers false or null).
/// </summary>
public static partial class PlatformCommands
{
    /// <summary>A row left <c>sending</c> this long is taken over by the next claim (PHP leaves such a row stuck for ever; the owner accepts a rare duplicate push, 12 Nov 2026). A row claimed before <c>claimed_at</c> existed has no time and is never taken over.</summary>
    public static readonly TimeSpan ClaimLease = TimeSpan.FromMinutes(10);

    // PHP OutboundMessagesModel::BACKOFF: seconds to wait after the 1st, 2nd, 3rd and 4th failed attempt; the 5th failure is dead.
    private static readonly int[] BackoffSeconds = [60, 300, 900, 3600];

    /// <summary>
    /// Takes up to <paramref name="limit"/> rows of <paramref name="channel"/> that are <c>queued</c> and due (<c>next_attempt_at</c> null or not after <paramref name="now"/>), or <c>sending</c> with <c>claimed_at</c> older than
    /// <see cref="ClaimLease"/>, oldest id first. One statement with <c>for update skip locked</c>: two workers never take the same row. Each row becomes <c>sending</c>, <c>attempts + 1</c>, <c>claimed_at = now</c>.
    /// </summary>
    public static async Task<IReadOnlyList<ClaimedMessage>> ClaimMessagesAsync(DbContext db, string channel, int limit, DateTimeOffset now, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentOutOfRangeException.ThrowIfLessThan(limit, 1);
        var staleBefore = now - ClaimLease;
        // No LINQ operator may follow SqlQuery here: EF would wrap the UPDATE in a select, which PostgreSQL refuses.
        var rows = await db.Database.SqlQuery<ClaimedMessage>(
            $"""
            update platform.outbound_messages m
               set status = 'sending', attempts = m.attempts + 1, claimed_at = {now}
             where m.id in (
                   select q.id from platform.outbound_messages q
                    where q.channel = {channel}::citext
                      and ((q.status = 'queued' and (q.next_attempt_at is null or q.next_attempt_at <= {now}))
                        or (q.status = 'sending' and q.claimed_at < {staleBefore}))
                    order by q.id
                    limit {limit}
                      for update skip locked)
            returning m.id as "Id", m.recipient::text as "Recipient", m.payload::text as "Payload", m.attempts as "Attempts"
            """).ToListAsync(ct);
        return [.. rows.OrderBy(r => r.Id)];
    }

    /// <summary>The message reached the channel: status <c>sent</c>, <c>sent_at</c> now, error cleared. False when the claim is no longer this worker's.</summary>
    public static async Task<bool> MarkSentAsync(DbContext db, long id, int attempts, DateTimeOffset now, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        var changed = await db.Database.ExecuteSqlAsync(
            $"update platform.outbound_messages set status = 'sent', sent_at = {now}, error = null where id = {id} and status = 'sending' and attempts = {attempts}", ct);
        return changed == 1;
    }

    /// <summary>
    /// The send was attempted and failed: back to <c>queued</c> with <c>next_attempt_at</c> = now + 60, 300, 900 or 3600 seconds after attempt 1 to 4, and <c>dead</c> after the 5th. Returns the status the row now holds
    /// (<c>queued</c> or <c>dead</c>), or null when the claim is no longer this worker's. <paramref name="error"/> is a short reason code, never a recipient or message text.
    /// </summary>
    public static async Task<string?> MarkFailedAsync(DbContext db, long id, int attempts, string error, DateTimeOffset now, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        if (attempts < 1 || attempts > BackoffSeconds.Length)
        {
            return await MarkDeadAsync(db, id, attempts, error, ct) ? "dead" : null;
        }

        var next = now.AddSeconds(BackoffSeconds[attempts - 1]);
        var changed = await db.Database.ExecuteSqlAsync(
            $"update platform.outbound_messages set status = 'queued', error = {error}, next_attempt_at = {next} where id = {id} and status = 'sending' and attempts = {attempts}", ct);
        return changed == 1 ? "queued" : null;
    }

    /// <summary>The channel was not usable, so the message was never really attempted: back to <c>queued</c> with the attempt given back (PHP <c>release</c>). False when the claim is no longer this worker's.</summary>
    public static async Task<bool> ReleaseMessageAsync(DbContext db, long id, int attempts, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        var changed = await db.Database.ExecuteSqlAsync(
            $"update platform.outbound_messages set status = 'queued', attempts = greatest(attempts - 1, 0) where id = {id} and status = 'sending' and attempts = {attempts}", ct);
        return changed == 1;
    }

    /// <summary>The send failed in a way a retry cannot change: status <c>dead</c> now, with <paramref name="reason"/> (a short code). False when the claim is no longer this worker's.</summary>
    public static async Task<bool> MarkDeadAsync(DbContext db, long id, int attempts, string reason, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        var changed = await db.Database.ExecuteSqlAsync(
            $"update platform.outbound_messages set status = 'dead', error = {reason} where id = {id} and status = 'sending' and attempts = {attempts}", ct);
        return changed == 1;
    }
}
