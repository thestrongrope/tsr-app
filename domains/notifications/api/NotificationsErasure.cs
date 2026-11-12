using Microsoft.EntityFrameworkCore;

namespace Tsr.Notifications.Api;

/// <summary>
/// The erasure command notifications publishes to other domains (domains/CLAUDE.md rules 3 and 11): a public static method that
/// writes notifications' tables on the caller's own connection and transaction.
/// </summary>
public static class NotificationsErasure
{
    private const int MaxDevices = 1000;

    /// <summary>
    /// PHP <c>AccountDeletionModel::complete</c>: <c>delete from user_devices where token = :token</c>. Deletes every device row of the member and returns the device ids it
    /// deleted (at most 1000), because they are also the recipients of queued push messages, which the caller redacts. Run inside the caller's transaction.
    /// </summary>
    public static async Task<IReadOnlyList<string>> EraseDevicesAsync(DbContext db, int token, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("Devices are erased inside the transaction of the deletion they belong to.");
        }

        var ids = await db.Database
            .SqlQuery<string>($"""select device_id as "Value" from notifications.user_devices where token = {token} order by id limit {MaxDevices}""")
            .ToListAsync(ct);
        await db.Database.ExecuteSqlAsync($"delete from notifications.user_devices where token = {token}", ct);
        return ids;
    }
}
