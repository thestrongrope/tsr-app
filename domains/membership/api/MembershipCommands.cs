using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api;

/// <summary>
/// The commands membership publishes to other domains (docs/specs/initial-build/fill-phase-design.md D2): public static methods that write membership's tables on the
/// caller's own connection and transaction, so another domain never touches a membership table itself. Plain parameters, no public records.
/// </summary>
public static class MembershipCommands
{
    /// <summary>
    /// PHP <c>writeEnrolment</c>'s first step: a member who has no class request at all gets an Accepted one naming the class they were placed in. A member who has any row
    /// (whatever its status) is left alone. Run inside the caller's transaction.
    /// </summary>
    public static async Task RecordAcceptedRegistrationAsync(DbContext db, int token, int classId, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("An accepted registration is written inside the transaction of the enrolment it belongs to.");
        }

        await db.Database.ExecuteSqlAsync(
            $"""
            insert into membership.class_registrations (token, for_classid, status)
            select {token}, {classId}, 'Accepted'
            where not exists (select 1 from membership.class_registrations where token = {token})
            """,
            ct);
    }

    /// <summary>What the profile columns hold (PHP's <c>users.name</c> and <c>mobile</c>); a longer value is a caller bug the command refuses.</summary>
    public const int MaxNameLength = 200;
    public const int MaxMobileLength = 100;

    /// <summary>
    /// PHP <c>updateStudentInClass</c>'s write of the member's contact: the name (only when one is given: null leaves it) and the mobile, which is always overwritten, an empty one included. Every profile row of the
    /// token is written, as PHP wrote every users row of it; a token with no profile changes nothing. No history row (PHP writes none). Writes one outbox row, <c>membership.member_contact_changed</c>.
    /// Run inside the caller's transaction.
    /// </summary>
    public static async Task ChangeContactAsync(DbContext db, int token, string? name, string mobile, TimeProvider clock, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(mobile);
        ArgumentNullException.ThrowIfNull(clock);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(token);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(mobile.Length, MaxMobileLength);
        if (name is not null)
        {
            ArgumentException.ThrowIfNullOrWhiteSpace(name);
            ArgumentOutOfRangeException.ThrowIfGreaterThan(name.Length, MaxNameLength);
        }

        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("A contact change is written inside the transaction of the edit it belongs to.");
        }

        await db.Database.ExecuteSqlAsync(
            $"""
            update membership.member_profiles set name = coalesce({name}, name), mobile = {mobile}
            where user_id in (select id from identity.v_users where token = {token})
            """,
            ct);
        await Outbox.WriteAsync(db, "membership.member_contact_changed", new MemberContactChanged(token, name is not null), clock, ct);
    }

    private sealed record MemberContactChanged(int Token, bool NameChanged);
}
