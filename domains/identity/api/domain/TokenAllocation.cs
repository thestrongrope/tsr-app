using Microsoft.EntityFrameworkCore;

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

    public static async Task<int> NextAsync(DbContext db, CancellationToken ct)
    {
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("A token is allocated inside the transaction that inserts it.");
        }

        await db.Database.ExecuteSqlAsync($"select set_config('lock_timeout', '10s', true)", ct);
        await db.Database.ExecuteSqlAsync($"select pg_advisory_xact_lock({TokenLock})", ct);
        var highest = await db.Database.SqlQuery<int?>($"select max(token) as \"Value\" from identity.users").ToListAsync(ct);
        return (highest[0] ?? FirstToken) + 1;
    }
}
