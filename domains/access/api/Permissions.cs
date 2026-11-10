using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api;

/// <summary>
/// The module's public interface, not a slice: every handler asks it what a caller may do. It loads the
/// caller's role, grants and class facts once per request and hands them to <see cref="AccessEngine"/>, which
/// holds PHP's rules (PermissionsModel). An action is <c>resource:action</c> (no scope), as in PHP's can().
/// </summary>
public sealed class Permissions
{
    private readonly AccessContext _db;
    private readonly IClassScopes _classes;
    private readonly Dictionary<int, UserAccess> _resolved = [];
    private IReadOnlyList<string>? _catalog;

    internal Permissions(AccessContext db, IClassScopes classes)
    {
        _db = db;
        _classes = classes;
    }

    /// <summary>
    /// May the caller do <paramref name="action"/> on <paramref name="target"/>? An action the catalog does not
    /// know throws: it is a bug in the calling code, not a refusal. A class target must be an active class.
    /// </summary>
    public async Task<bool> CanAsync(Caller caller, string action, AccessTarget target, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(caller);
        ArgumentNullException.ThrowIfNull(target);
        await RequireKnownAsync(action, ct);

        var state = await ResolveAsync(caller, ct);
        var targetClass = target.ClassId is int classId ? await _classes.ActiveClassAsync(classId, ct) : null;
        return AccessEngine.Check(state, action, target, targetClass);
    }

    /// <summary>What a list for <paramref name="action"/> may show: all, one gender, and/or a set of class ids (PHP managedReach, searchReach, genderLock and assignedOnlyIds).</summary>
    public async Task<Reach> ReachAsync(Caller caller, string action, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(caller);
        await RequireKnownAsync(action, ct);
        return AccessEngine.ReachOf(await ResolveAsync(caller, ct), action, caller.Token);
    }

    /// <summary>Every permission the caller holds and what their scopes resolve to (the body of GET /me/permissions).</summary>
    public Task<UserAccess> ForUserAsync(Caller caller, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(caller);
        return ResolveAsync(caller, ct);
    }

    internal async Task<bool> IsKnownAsync(string action, CancellationToken ct) =>
        AccessEngine.IsKnown(await CatalogAsync(ct), action);

    /// <summary>The scopes the caller holds the action in (PHP scopesOf); the action must be known.</summary>
    internal async Task<IReadOnlyList<string>> ScopesOfAsync(Caller caller, string action, CancellationToken ct)
    {
        await RequireKnownAsync(action, ct);
        return AccessEngine.HeldScopes(await ResolveAsync(caller, ct), action);
    }

    internal async Task<int> RoleIdAsync(Caller caller, CancellationToken ct) =>
        await _db.UserRoles.AsNoTracking()
            .Where(u => u.UserId == caller.UserId)
            .Select(u => (int?)u.RoleId)
            .FirstOrDefaultAsync(ct) ?? 0;

    private async Task RequireKnownAsync(string action, CancellationToken ct)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(action);
        if (!await IsKnownAsync(action, ct))
        {
            throw new ArgumentException("Unknown permission: " + action, nameof(action));
        }
    }

    private async Task<IReadOnlyList<string>> CatalogAsync(CancellationToken ct)
    {
        if (_catalog is null)
        {
            var names = await _db.Permissions.AsNoTracking().Select(p => p.Name).ToListAsync(ct);
            // Ordinal order, which is MariaDB's order for these names (db tests and the Hurl parity file prove it).
            _catalog = names.Order(StringComparer.Ordinal).ToList();
        }

        return _catalog;
    }

    private async Task<UserAccess> ResolveAsync(Caller caller, CancellationToken ct)
    {
        if (_resolved.TryGetValue(caller.UserId, out var cached))
        {
            return cached;
        }

        // A guest (token 0) holds nothing: PHP stops here too, before reading any grant.
        var state = caller.Token == 0 ? UserAccess.None : await LoadAsync(caller, ct);
        _resolved[caller.UserId] = state;
        return state;
    }

    private async Task<UserAccess> LoadAsync(Caller caller, CancellationToken ct)
    {
        var roleId = await RoleIdAsync(caller, ct);
        var stored = await StoredNamesAsync(caller.UserId, roleId, ct);
        var memberships = await _classes.MembershipsAsync(caller.Token, ct);
        var assigned = await AssignedClassesAsync(caller.Token, ct);
        return AccessEngine.Resolve(new AccessInputs(await CatalogAsync(ct), roleId, stored, memberships, assigned));
    }

    // The role's grants and the user's live named grants (PHP: role_permissions union user_permissions).
    private async Task<List<string>> StoredNamesAsync(int userId, int roleId, CancellationToken ct) =>
        await _db.RolePermissions.AsNoTracking().Where(g => g.RoleId == roleId).Select(g => g.Permission)
            .Union(_db.UserPermissions.AsNoTracking().Where(g => g.UserId == userId && g.RevokedAt == null).Select(g => g.Permission))
            .ToListAsync(ct);

    private async Task<IReadOnlyList<ClassFacts>> AssignedClassesAsync(int token, CancellationToken ct)
    {
        var rules = await LiveRulesAsync(token, ct);
        if (rules.Count == 0)
        {
            return [];
        }

        return RuleMatcher.Assigned(rules, await _classes.ActiveClassesAsync(ct));
    }

    private async Task<IReadOnlyList<AccessRule>> LiveRulesAsync(int token, CancellationToken ct)
    {
        var rules = await _db.ClassAccessRules.AsNoTracking()
            .Where(r => r.Token == token && r.RevokedAt == null)
            .Select(r => new { r.Id, r.Gender })
            .ToListAsync(ct);
        if (rules.Count == 0)
        {
            return [];
        }

        var ids = rules.Select(r => r.Id).ToList();
        var conditions = await _db.ClassAccessRuleConditions.AsNoTracking()
            .Where(c => ids.Contains(c.RuleId))
            .ToListAsync(ct);
        return rules
            .Select(r => new AccessRule(
                r.Gender,
                conditions.Where(c => c.RuleId == r.Id).Select(c => new RuleCondition(c.Field, c.Negate, c.Value, c.LevelId)).ToList()))
            .ToList();
    }
}
