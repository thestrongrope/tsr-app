using Microsoft.EntityFrameworkCore;

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
    public static async Task<IReadOnlyList<string>> EraseDevicesAsync(DbContext db, int token, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("Devices are erased inside the transaction of the deletion they belong to.");
        }

        var ids = await db.Database
            .SqlQuery<string>($"""delete from notifications.user_devices where token = {token} returning device_id as "Value" """)
            .ToListAsync(ct);
        return ids;
    }
}
