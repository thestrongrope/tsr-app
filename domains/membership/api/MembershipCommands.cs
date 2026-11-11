using Microsoft.EntityFrameworkCore;

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
}
