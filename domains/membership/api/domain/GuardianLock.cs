using Microsoft.EntityFrameworkCore;

namespace Tsr.Membership.Api.Domain;

/// <summary>
/// The lock PHP takes on the child's <c>users</c> row (<c>UPDATE users SET roleid = roleid</c>) so that "one active link per pair" and
/// "five pending invites", which have no database key, cannot be broken by two requests at once. Here: a transaction-level advisory
/// lock on the child's user id, in this module's own lock class. It is released at commit or rollback; the caller opens the transaction.
/// </summary>
internal static class GuardianLock
{
    /// <summary>The first key of the two-key advisory lock: membership's guardian links. Do not reuse it for anything else.</summary>
    public const int LockClass = 3001;

    public static Task TakeAsync(MembershipContext db, int childUserId, CancellationToken ct) =>
        db.Database.ExecuteSqlAsync($"select pg_advisory_xact_lock({LockClass}, {childUserId})", ct);
}
