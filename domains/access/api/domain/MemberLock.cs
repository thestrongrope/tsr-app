using Tsr.Shared.Api;

namespace Tsr.Access.Api.Domain;

/// <summary>
/// The lock every write to one member's grants, role or class access rules takes first (PHP: <c>UPDATE users SET roleid = roleid</c>, a row lock).
/// A transaction-level advisory lock, class 6001 (no other code may use it), keyed by the member's token; it waits at most five seconds.
/// </summary>
internal static class MemberLock
{
    public const int LockClass = 6001;

    public static async Task TakeAsync(DbTx tx, int token, CancellationToken ct)
    {
        await tx.ExecuteAsync($"set local lock_timeout = '5s'", ct);
        await tx.ExecuteAsync($"select pg_advisory_xact_lock({LockClass}, {token})", ct);
    }
}
