using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>What the deletion routes share: the permission gate, the reads (PHP <c>AccountDeletionModel</c>) and the one insert both ways of raising a request use.</summary>
internal static class DeletionRequests
{
    public const int QueueLimit = 1000;
    public const int MaxTextLength = 500;
    public const string NotPermitted = "You do not have permission to do that";

    internal sealed record Requested(int RequestId, int Token, string Source);

    private sealed record Count(string Key, int Total);

    /// <summary>PHP <c>api_authenticate</c> then <c>api_require</c>: 401 without a caller, 403 without the permission, otherwise null.</summary>
    public static async Task<IResult?> RefuseAsync(Caller? caller, Permissions permissions, string action, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        return await permissions.CanAsync(caller, action, AccessTarget.None, ct)
            ? null
            : Problem.Detail(StatusCodes.Status403Forbidden, NotPermitted);
    }

    /// <summary>A body text field the way PHP validates <c>reason</c> and <c>note</c>: absent or null is null; not text, a NUL byte, or over 500 characters is the refusal; trimmed, empty is null.</summary>
    public static (string? Text, string? Refusal) ReadText(JsonBody body, string field)
    {
        var element = body.Get(field);
        if (element.ValueKind is System.Text.Json.JsonValueKind.Undefined or System.Text.Json.JsonValueKind.Null)
        {
            return (null, null);
        }

        var raw = element.ValueKind == System.Text.Json.JsonValueKind.String ? element.GetString() : null;
        if (raw is null || raw.Contains('\0', StringComparison.Ordinal))
        {
            return (null, field + " must be text");
        }

        var trimmed = PhpText.Trim(raw);
        if (PhpText.CodePointCount(trimmed) > MaxTextLength)
        {
            return (null, field + " must be 500 characters or fewer");
        }

        return (trimmed.Length == 0 ? null : trimmed, null);
    }

    /// <summary>
    /// Requests with their member's details, newest first, at most <see cref="QueueLimit"/>. Filter by request id, by status, or (<paramref name="activeToken"/>) to the one live request of a member.
    /// A token held by several user rows shows the first (lowest id).
    /// </summary>
    public static async Task<List<DeletionRow>> QueryAsync(IdentityContext db, int? id, string? status, int? activeToken, CancellationToken ct) =>
        await db.Database
            .SqlQuery<DeletionRow>($"""
                select r.id as "Id", r.status::text as "Status", r.source::text as "Source", r.token as "Token",
                       m.name as "MemberName", u.email as "MemberEmail", m.zip as "MemberZip", m.mobile as "MemberMobile",
                       r.contact_name as "ContactName", r.contact_email as "ContactEmail", r.requested_at as "RequestedAt", r.reason as "Reason",
                       r.operator_note as "OperatorNote", r.confirmation_sent_at as "ConfirmationSentAt", r.completed_at as "CompletedAt",
                       r.cancelled_at as "CancelledAt", r.handled_by as "HandledBy", hm.name as "HandledByName"
                from identity.account_deletion_requests r
                left join identity.users u on u.id = (select min(id) from identity.users where token = r.token)
                left join membership.v_members m on m.user_id = u.id
                left join membership.v_members hm on hm.user_id = (select min(id) from identity.users where token = r.handled_by)
                where ({id}::int is null or r.id = {id}::int)
                  and ({status}::text is null or r.status::text = {status}::text)
                  and ({activeToken}::int is null or (r.token = {activeToken}::int and r.status::text in ('pending', 'awaiting_prize_delivery')))
                order by r.id desc
                limit {QueueLimit}
                """)
            .ToListAsync(ct);

    public static async Task<DeletionRow?> FindAsync(IdentityContext db, int id, CancellationToken ct) =>
        (await QueryAsync(db, id, null, null, ct)).FirstOrDefault();

    public static async Task<DeletionRow?> ActiveForAsync(IdentityContext db, int token, CancellationToken ct) =>
        (await QueryAsync(db, null, null, token, ct)).FirstOrDefault();

    /// <summary>How many requests sit in each status, every status present (PHP <c>counts</c>).</summary>
    public static async Task<Dictionary<string, int>> CountsAsync(IdentityContext db, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<Count>($"""select status::text as "Key", count(*)::int as "Total" from identity.account_deletion_requests group by status""")
            .ToListAsync(ct);
        return DeletionViews.Statuses.ToDictionary(s => s, s => rows.Where(r => r.Key == s).Sum(r => r.Total), StringComparer.Ordinal);
    }

    /// <summary>PHP <c>demo_member_tokens()</c>: the reviewer demo members (address ending @demo.invalid), whose request an operator may never complete.</summary>
    public static async Task<List<int>> DemoTokensAsync(IdentityContext db, CancellationToken ct) =>
        await db.Database
            .SqlQuery<int>($"""select token as "Value" from identity.users where email like '%@demo.invalid' limit 1000""")
            .ToListAsync(ct);

    /// <summary>
    /// PHP <c>request()</c>: raises a pending request, or reports the live one the member already has. Idempotent by the partial unique index, never by looking first (two taps race): the insert
    /// is attempted and a conflict does nothing. Returns the live request and whether this call raised it; a raise writes <c>identity.deletion_requested</c> (request id, token, source) in the same transaction.
    /// </summary>
    public static async Task<(DeletionRow Row, bool Created)> RaiseAsync(
        IdentityContext db, TimeProvider clock, int token, string source, string? reason, string? contactName, string? contactEmail, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var inserted = await db.Database.ExecuteSqlAsync(
            $"""
            insert into identity.account_deletion_requests (token, status, source, reason, contact_name, contact_email, requested_at)
            values ({token}, 'pending', {source}, {reason}, {contactName}, {contactEmail}, {now})
            on conflict do nothing
            """,
            ct);
        var row = await ActiveForAsync(db, token, ct)
            ?? throw new InvalidOperationException("The deletion request was neither raised nor already there.");
        if (inserted == 1)
        {
            await Outbox.WriteAsync(db, "identity.deletion_requested", new Requested(row.Id, token, source), clock, ct);
        }

        await transaction.CommitAsync(ct);
        return (row, inserted == 1);
    }

    /// <summary>The request id of a path segment as PHP's <c>(int) $id</c> reads it; null when it cannot name a request.</summary>
    public static int? ParseId(string text)
    {
        var id = PhpValue.IntOfText(text);
        return id is > 0 and <= int.MaxValue ? (int)id : null;
    }
}
