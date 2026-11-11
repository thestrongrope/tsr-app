using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>
/// The commands identity publishes to other domains (docs/specs/initial-build/fill-phase-design.md D2): public static methods that write identity's tables on the caller's own
/// connection and transaction, so another domain never touches an identity table itself. Plain parameters, no public records.
/// </summary>
public static class IdentityCommands
{
    private const int MaxEmailLength = 255;

    private sealed record Current(string? Email, string? FirebaseUid);

    /// <summary>
    /// PHP <c>ClassStudentsModel::canChangeEmail</c> and the email write of <c>updateStudentInClass</c>: sign-in matches members by email, so only a placeholder (blank, or
    /// <c>&lt;token&gt;@thestrongrope.com</c>) that has never signed in (no Firebase link) may be given another address. Returns false, writing nothing, when the member does not exist or may not
    /// be changed; true when the member now has <paramref name="email"/> (an address the member already has is left alone, one that differs only in case is rewritten). The email is not checked for
    /// uniqueness, as PHP does not (its column has no unique key). Writes one outbox row, <c>identity.member_email_changed</c>, when it changes the address. Run inside the caller's transaction.
    /// </summary>
    public static async Task<bool> ChangeEmailAsync(DbContext db, int token, string email, TimeProvider clock, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(clock);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(token);
        ArgumentException.ThrowIfNullOrWhiteSpace(email);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(email.Length, MaxEmailLength);
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("An email change is written inside the transaction of the edit it belongs to.");
        }

        var rows = await db.Database
            .SqlQuery<Current>($"""select email as "Email", firebase_uid as "FirebaseUid" from identity.users where token = {token} order by id limit 1""")
            .ToListAsync(ct);
        if (rows.Count == 0)
        {
            return false;
        }

        var current = PhpText.Trim(rows[0].Email ?? string.Empty);
        var wanted = PhpText.Trim(email);
        if (string.Equals(current, wanted, StringComparison.Ordinal))
        {
            return true;
        }

        var sameAddress = string.Equals(current, wanted, StringComparison.OrdinalIgnoreCase);
        var placeholder = current.Length == 0 || string.Equals(current, $"{token}@thestrongrope.com", StringComparison.OrdinalIgnoreCase);
        if (!sameAddress && !(placeholder && string.IsNullOrEmpty(rows[0].FirebaseUid)))
        {
            return false;
        }

        await db.Database.ExecuteSqlAsync($"update identity.users set email = {wanted} where token = {token}", ct);
        await Outbox.WriteAsync(db, "identity.member_email_changed", new MemberEmailChanged(token), clock, ct);
        return true;
    }

    private sealed record MemberEmailChanged(int Token);
}
