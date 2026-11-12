using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace Tsr.Platform.Api;

/// <summary>
/// The commands platform publishes to other domains (docs/specs/initial-build/fill-phase-design.md D2): public static methods that write platform's tables
/// on the caller's own connection, so another domain never touches a platform table itself. Each is a few lines and takes plain values, not a record.
/// </summary>
public static partial class PlatformCommands
{
    // PHP is_privileged_roleid: ROLE_ADMIN, ROLE_GENTS_ADMIN, ROLE_LADIES_ADMIN, ROLE_CLASS_ADMIN, ROLE_FINANCE.
    private static readonly int[] PrivilegedRoles = [1, 3, 4, 5, 7];

    /// <summary>
    /// PHP <c>api_log_admin_action</c> (lib/audit.php, functions.php log_admin_page_access): one <c>admin_access_log</c> row for a caller whose role is privileged, with the request's
    /// path, method, client address, user agent and referer (cut to the column lengths, as PHP's substr; the session id is null). Fire and forget, as PHP: an audit write that fails is
    /// logged (without the request's values) and never fails the action it records. Call it outside a transaction, right after the permission check: PostgreSQL aborts a transaction
    /// whose statement failed, which PHP's autocommit never did.
    /// </summary>
    public static async Task RecordAdminAccessAsync(DbContext db, HttpContext context, int userId, int token, int roleId, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(context);
        if (!PrivilegedRoles.Contains(roleId))
        {
            return;
        }

        var request = context.Request;
        var path = Cut(request.Path.ToUriComponent(), 255) ?? string.Empty;
        var method = Cut(request.Method, 10) ?? string.Empty;
        var ip = Cut(CallerAddress(context), 45) ?? string.Empty;
        var userAgent = Cut(request.Headers.UserAgent.ToString(), 512);
        var referer = Cut(request.Headers.Referer.ToString(), 512);
        try
        {
            await db.Database.ExecuteSqlAsync(
                $"""
                insert into platform.admin_access_log (user_id, token, roleid, page, method, ip, user_agent, referer, session_id)
                values ({userId}, {token}, {roleId}, {path}, {method}, {ip}, {userAgent}, {referer}, null)
                """,
                ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            var logger = context.RequestServices.GetService<ILoggerFactory>()?.CreateLogger("Tsr.Platform.Api.PlatformCommands");
            if (logger is not null)
            {
                LogAuditFailed(logger, e);
            }
        }
    }

    private const int MaxRedactedRecipients = 1000;

    /// <summary>
    /// PHP <c>AccountDeletionModel::complete</c>: <c>delete from feedback where user_id = :user_id</c>. Feedback is free text that may name the member. Run inside the caller's transaction.
    /// </summary>
    public static async Task EraseFeedbackAsync(DbContext db, int userId, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        RequireTransaction(db);
        await db.Database.ExecuteSqlAsync($"delete from platform.feedback where user_id = {userId}", ct);
    }

    /// <summary>
    /// PHP <c>redactQueuedMessages</c>: <c>update outbound_messages set recipient = '[deleted]' where recipient in (...)</c>. The queue has no member key, so a member's rows are found by their
    /// recipient values (mobile number, device ids); the rows stay, with the recipient redacted. At most 1000 recipients (more throws). Run inside the caller's transaction.
    /// </summary>
    public static async Task RedactRecipientsAsync(DbContext db, IReadOnlyCollection<string> recipients, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(recipients);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(recipients.Count, MaxRedactedRecipients);
        RequireTransaction(db);
        if (recipients.Count == 0)
        {
            return;
        }

        var values = recipients.ToArray();
        await db.Database.ExecuteSqlAsync($"update platform.outbound_messages set recipient = '[deleted]' where recipient = any({values})", ct);
    }

    private static void RequireTransaction(DbContext db)
    {
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("An erasure is written inside the transaction of the deletion it belongs to.");
        }
    }

    /// <summary>
    /// PHP <c>queue_message</c> (functions.php:472, OutboundMessagesModel::enqueue): one <c>outbound_messages</c> row per non-blank recipient with status queued, on the caller's transaction. NOTHING is sent: no worker reads
    /// the queue yet. The dedupe key is PHP's <c>dedupeKeyFor</c>: the first 150 characters of <paramref name="dedupeKey"/>, a colon and the first 20 bytes of the SHA-256 of the recipient in hex (PHP used SHA-1: a deliberate difference, so a key PHP queued is not recognised); the unique (channel, dedupe_key) index makes a repeat a no-op.
    /// Returns the rows queued. Needs an open transaction (it does not start one). The recipients are device ids: not logged.
    /// </summary>
    public static async Task<int> QueueMessagesAsync(
        DbContext db, string channel, IReadOnlyList<string> recipients, string payloadJson, string? dedupeKey, int? createdBy, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(recipients);
        var wanted = recipients.Select(r => r.Trim()).Where(r => r.Length > 0).Distinct(StringComparer.Ordinal).ToArray();
        if (wanted.Length == 0)
        {
            return 0;
        }

        var keys = wanted.Select(r => dedupeKey is null ? null : DedupeKeyFor(dedupeKey, r)).ToArray();
        return await db.Database.ExecuteSqlAsync(
            $"""
            insert into platform.outbound_messages (channel, recipient, payload, dedupe_key, status, created_by)
            select {channel}, r.recipient, {payloadJson}, r.dedupe_key, 'queued', {createdBy}
            from unnest({wanted}::text[], {keys}::text[]) as r(recipient, dedupe_key)
            on conflict (channel, dedupe_key) do nothing
            """,
            ct);
    }

    private static string DedupeKeyFor(string key, string recipient) =>
        (key.Length <= 150 ? key : key[..150]) + ":" + Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(recipient))[..20]);

    [LoggerMessage(Level = LogLevel.Warning, Message = "The admin access log row could not be written")]
    private static partial void LogAuditFailed(ILogger logger, Exception exception);

    // Stricter than PHP's getRealIpAddr (decided 11 Nov 2026), which believes Client-IP and X-Forwarded-For as sent: the peer, or the hop our own proxy added; "" when there is no peer.
    private static string CallerAddress(HttpContext context)
    {
        var address = Tsr.Shared.Api.ClientAddress.Of(context);
        return address == Tsr.Shared.Api.ClientAddress.Unknown ? string.Empty : address;
    }

    // PHP substr to the column length; null stays null (an absent header is NULL, as PHP's `$x ? substr : null`).
    private static string? Cut(string? value, int length)
    {
        if (string.IsNullOrEmpty(value))
        {
            return null;
        }

        if (value.Length <= length)
        {
            return value;
        }

        return char.IsHighSurrogate(value[length - 1]) ? value[..(length - 1)] : value[..length];
    }
}
