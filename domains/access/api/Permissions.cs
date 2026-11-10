using MySqlConnector;
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
public sealed class Permissions(Db db)
{
    private const string SelfSuffix = ":self";

    public async Task<bool> CanAsync(Caller caller, string permission, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(caller);
        ArgumentException.ThrowIfNullOrWhiteSpace(permission);

        await using var connection = await db.OpenAsync(ct);
        if (!await ExistsAsync(connection, permission, ct))
        {
            return false;
        }

        if (permission.EndsWith(SelfSuffix, StringComparison.Ordinal))
        {
            return caller.Token > 0;
        }

        return await IsGrantedAsync(connection, caller, permission, ct);
    }

    private static async Task<bool> ExistsAsync(MySqlConnection connection, string permission, CancellationToken ct)
    {
        await using var command = new MySqlCommand(
            "select 1 from permissions where name = @name limit 1", connection);
        command.Parameters.AddWithValue("@name", permission);
        return await command.ExecuteScalarAsync(ct) is not null;
    }

    private static async Task<bool> IsGrantedAsync(
        MySqlConnection connection, Caller caller, string permission, CancellationToken ct)
    {
        await using var command = new MySqlCommand(
            """
            select 1 from role_permissions where roleid = @role and permission = @name
            union all
            select 1 from user_permissions
             where user_id = @user and permission = @name and revoked_at is null
            limit 1
            """,
            connection);
        command.Parameters.AddWithValue("@role", caller.RoleId);
        command.Parameters.AddWithValue("@user", caller.UserId);
        command.Parameters.AddWithValue("@name", permission);
        return await command.ExecuteScalarAsync(ct) is not null;
    }
}
