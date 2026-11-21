using Tsr.Shared.Api;

namespace Tsr.Notifications.Api;

/// <summary>
/// The erasure command notifications publishes to other domains (domains/CLAUDE.md rules 3 and 11): a public static method that
/// writes notifications' tables on the caller's own connection and transaction.
/// </summary>
public static class NotificationsErasure
{
    /// <summary>
    /// PHP <c>AccountDeletionModel::complete</c>: <c>delete from user_devices where token = :token</c>. Deletes every device row of the member and returns the device ids it
    /// deleted, because they are also the recipients of queued push messages, which the caller redacts. Every one, as PHP: a cap would leave queued pushes to the devices past it unredacted. Run inside the caller's transaction.
    /// </summary>
    public static async Task<IReadOnlyList<string>> EraseDevicesAsync(DbTx tx, int token, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(tx);
        return await tx.ListAsync($"delete from notifications.user_devices where token = {token} returning device_id", row => row.Text("device_id"), ct);
    }

    /// <summary>
    /// PHP <c>AccountDeletionModel::complete</c>: <c>delete from member_event_settings where user_id in (select id from users where token = :token)</c>. Deletes the member's calendar alert
    /// settings and tombstones (they say which class events a person follows) and returns how many. Run inside the caller's transaction.
    /// </summary>
    public static async Task<int> EraseEventSettingsAsync(DbTx tx, int token, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(tx);
        return await tx.ExecuteAsync(
            $"delete from notifications.member_event_settings where user_id in (select id from identity.v_users where token = {token})", ct);
    }
}
