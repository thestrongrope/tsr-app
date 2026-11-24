using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// PHP's MySQL named locks as PostgreSQL transaction-level advisory locks (single bigint key; membership's 3001 is the two-key form, a separate space): taken without waiting
/// (PHP <c>GET_LOCK(name, 0)</c>), held until the transaction commits or rolls back, so the caller opens the transaction first. Registered in domains/assessment/CLAUDE.md.
/// </summary>
internal static class AssessmentLocks
{
    /// <summary>PHP <c>standard_mcq_update</c>.</summary>
    public const long StandardMcqUpdate = 5001;

    /// <summary>PHP <c>quiz_admin</c>: every change to the quiz competition.</summary>
    public const long QuizAdmin = 5002;

    /// <summary>True when the lock is ours; false when another transaction holds it.</summary>
    public static async Task<bool> TryTakeAsync(DbTx tx, long key, CancellationToken ct) =>
        (await tx.ListAsync($"""select pg_try_advisory_xact_lock({key}) as "Value" """, row => row.Bool("Value"), ct)).Single();
}
