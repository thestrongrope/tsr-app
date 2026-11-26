using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>
/// PHP's <c>GuardiansModel::revokeForPair</c>: every active link of one parent token and child token pair becomes revoked, by the caller, now.
/// Both self-service revoke operations use it (the parent ending a link, the child removing a parent); a duplicate active pair from old data
/// ends together, as PHP's one UPDATE does.
/// </summary>
internal static class GuardianRevoker
{
    /// <summary>True when at least one active link ended.</summary>
    public static async Task<bool> RevokePairAsync(NpgsqlDataSource source, long parentToken, long childToken, int callerUserId, DateTimeOffset now, CancellationToken ct)
    {
        // No token outside the integer range can be held, so no row can match.
        if (parentToken is < int.MinValue or > int.MaxValue || childToken is < int.MinValue or > int.MaxValue)
        {
            return false;
        }

        var parent = (int)parentToken;
        var child = (int)childToken;
        var changed = await source.ExecuteAsync(
            $"""
            update membership.user_guardians set status = 'revoked', revoked_at = {now}, revoked_by = {callerUserId}
            where parent_token = {parent} and child_token = {child} and status = 'active'
            """,
            ct);
        return changed > 0;
    }
}
