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

        // A token is not unique: every row the update below touches is judged (PHP judges one arbitrary row).
        var rows = await db.Database
            .SqlQuery<Current>($"""select email as "Email", firebase_uid as "FirebaseUid" from identity.users where token = {token} order by id""")
            .ToListAsync(ct);
        if (rows.Count == 0)
        {
            return false;
        }

        var wanted = PhpText.Trim(email);
        if (rows.All(row => string.Equals(PhpText.Trim(row.Email ?? string.Empty), wanted, StringComparison.Ordinal)))
        {
            return true;
        }

        if (!rows.All(row => MayTake(row, token, wanted)))
        {
            return false;
        }

        await db.Database.ExecuteSqlAsync($"update identity.users set email = {wanted} where token = {token}", ct);
        await Outbox.WriteAsync(db, "identity.member_email_changed", new MemberEmailChanged(token), clock, ct);
        return true;
    }

    private static bool MayTake(Current row, int token, string wanted)
    {
        var current = PhpText.Trim(row.Email ?? string.Empty);
        var sameAddress = string.Equals(current, wanted, StringComparison.OrdinalIgnoreCase);
        var placeholder = current.Length == 0 || string.Equals(current, $"{token}@thestrongrope.com", StringComparison.OrdinalIgnoreCase);
        return sameAddress || (placeholder && string.IsNullOrEmpty(row.FirebaseUid));
    }

    private sealed record MemberEmailChanged(int Token);

    /// <summary>
    /// PHP <c>createClassStudent</c>'s <c>users</c> insert, for a member who is not an app member yet (bulk add): a row with the next token (<see cref="TokenAllocation"/>, PHP's max + 1 under the advisory lock),
    /// the placeholder address <c>&lt;token&gt;@thestrongrope.com</c>, no Firebase link and no role. Returns the token. The profile is membership's (<c>MembershipCommands.CreateProfileAsync</c>). Writes one outbox
    /// row, <c>identity.member_created</c>. Run inside the caller's transaction.
    /// </summary>
    public static async Task<int> CreateMemberAsync(DbContext db, TimeProvider clock, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(clock);
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("A member is created inside the transaction of the add it belongs to.");
        }

        var token = await TokenAllocation.NextAsync(db, ct);
        var email = $"{token}@thestrongrope.com";
        var now = clock.GetUtcNow();
        await db.Database.ExecuteSqlAsync($"insert into identity.users (token, email, createdon) values ({token}, {email}, {now})", ct);
        await Outbox.WriteAsync(db, "identity.member_created", new MemberCreated(token), clock, ct);
        return token;
    }

    private sealed record MemberCreated(int Token);
}
