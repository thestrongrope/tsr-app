using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Access.Api;

/// <summary>
/// The module's public interface, not a slice: every handler calls it to ask may this caller do
/// <c>resource:action:scope</c>?
/// Mirrors tsr-account's PermissionsModel::can() for the parts this sample needs:
/// a <c>:self</c> permission is held by every registered member, otherwise the caller's role
/// must grant it or a named grant in user_permissions must exist and not be revoked.
/// Scopes (gender, city, level) and class-coordinator rules are not in this sample yet.
/// </summary>
public sealed class Permissions
{
    private const string SelfSuffix = ":self";

    private readonly AccessContext _db;

    internal Permissions(AccessContext db) => _db = db;

    public async Task<bool> CanAsync(Caller caller, string permission, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(caller);
        ArgumentException.ThrowIfNullOrWhiteSpace(permission);

        var exists = await _db.Permissions.AsNoTracking().AnyAsync(p => p.Name == permission, ct);
        if (!exists)
        {
            return false;
        }

        if (permission.EndsWith(SelfSuffix, StringComparison.Ordinal))
        {
            return caller.Token > 0;
        }

        return await IsGrantedAsync(caller, permission, ct);
    }

    private async Task<bool> IsGrantedAsync(Caller caller, string permission, CancellationToken ct)
    {
        var byRole = await _db.RolePermissions.AsNoTracking()
            .AnyAsync(g => g.RoleId == caller.RoleId && g.Permission == permission, ct);
        if (byRole)
        {
            return true;
        }

        return await _db.UserPermissions.AsNoTracking()
            .AnyAsync(g => g.UserId == caller.UserId && g.Permission == permission && g.RevokedAt == null, ct);
    }
}
