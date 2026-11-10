using Microsoft.EntityFrameworkCore;

namespace Tsr.Membership.Api;

/// <summary>
/// The module's public read interface: a member's name by identity user id. For the access log's list and, later, classes and
/// assessment. Only members who have a name appear; a user with no profile row, or an empty name, is left out.
/// </summary>
public sealed class MemberNames
{
    /// <summary>The most ids one call accepts. A bigger batch is a bug in the caller and throws.</summary>
    public const int MaxBatch = 500;

    private readonly MembershipContext _db;

    internal MemberNames(MembershipContext db) => _db = db;

    /// <summary>User id to name. Empty when there are no ids or none of them has a name.</summary>
    public async Task<IReadOnlyDictionary<int, string>> ByUserIdsAsync(IReadOnlyCollection<int> userIds, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(userIds);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(userIds.Count, MaxBatch);
        if (userIds.Count == 0)
        {
            return new Dictionary<int, string>();
        }

        var ids = userIds.Distinct().ToList();
        var rows = await _db.MemberProfiles.AsNoTracking()
            .Where(p => ids.Contains(p.UserId) && p.Name != null && p.Name != string.Empty)
            .Select(p => new { p.UserId, Name = p.Name! })
            .ToListAsync(ct);
        return rows.ToDictionary(r => r.UserId, r => r.Name);
    }
}
