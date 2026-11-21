using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>
/// The one place a new member's token is chosen: PHP's <c>generateUniqueToken</c> (highest token + 1, 1001 for an empty table), made safe by a transaction-scoped advisory lock so two inserts at once
/// cannot read the same maximum. The lock is held until the caller's transaction ends and waits at most ten seconds (PHP's GET_LOCK timeout); a transaction that takes it twice (a bulk add) is not
/// blocked by itself, and reads its own earlier inserts, so each call returns the next number.
/// </summary>
internal static class TokenAllocation
{
    private const int FirstToken = 1000;
    private const long TokenLock = 7_100_001;

    public static async Task<int> NextAsync(DbTx tx, CancellationToken ct)
    {
        await tx.ExecuteAsync($"select set_config('lock_timeout', '10s', true)", ct);
        await tx.ExecuteAsync($"select pg_advisory_xact_lock({TokenLock})", ct);
        var highest = await tx.ScalarAsync<int>($"select max(token) as \"Value\" from identity.users", ct);
        return (highest ?? FirstToken) + 1;
    }
}
