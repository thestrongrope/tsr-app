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

    /// <summary>
    /// PHP <c>createClassStudent</c>'s profile columns for a member just created by <c>IdentityCommands.CreateMemberAsync</c>: the name, the gender (the raw text PHP keeps, the class's number) and the mobile
    /// (may be empty). No other profile column is written. The token must name an existing user without a profile. Writes one outbox row, <c>membership.member_created</c>. Run inside the caller's transaction.
    /// </summary>
    public static async Task CreateProfileAsync(DbContext db, int token, string name, string gender, string mobile, TimeProvider clock, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(clock);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(token);
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(gender);
        ArgumentNullException.ThrowIfNull(mobile);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(name.Length, MaxNameLength);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(gender.Length, MaxGenderLength);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(mobile.Length, MaxMobileLength);
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("A member profile is created inside the transaction of the add it belongs to.");
        }

        var written = await db.Database.ExecuteSqlAsync(
            $"""
            insert into membership.member_profiles (user_id, name, gender, mobile)
            select id, {name}, {gender}, {mobile} from identity.v_users where token = {token}
            """,
            ct);
        if (written == 0)
        {
            throw new InvalidOperationException("No member has that token.");
        }

        await Outbox.WriteAsync(db, "membership.member_created", new MemberCreated(token), clock, ct);
    }

    private const int MaxGenderLength = 200;

    /// <summary>
    /// PHP <c>AccountDeletionModel::anonymisationMap</c> (the profile columns, which moved out of <c>users</c>) and <c>registrationAnonymisationMap</c>, for the member of
    /// <paramref name="token"/>. Profile of every user row of the token: name "Deleted member"; first and last name, picture, gender, age range, country, state, city, zip null;
    /// mobile empty; language 0; sendupdates N; unsubscribe Y. Every <c>class_registrations</c> row of the token: the three locations, birth year, profession, Islamic study years,
    /// interests (and other), education block (education, field of study and other, professional courses and other, occupation type, field of work, years of experience, role level),
    /// LinkedIn URL and the status reason are null; status, class and dates are kept. Run inside the caller's transaction.
    /// </summary>
    public static async Task EraseMemberAsync(DbContext db, int token, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(token);
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("A member is erased inside the transaction of the deletion it belongs to.");
        }

        await db.Database.ExecuteSqlAsync(
            $"""
            update membership.member_profiles
            set name = 'Deleted member', first_name = null, last_name = null, picture = null, gender = null, age_range = null,
                mobile = '', country = null, state = null, city = null, zip = null, language = 0, sendupdates = 'N', unsubscribe = 'Y'
            where user_id in (select id from identity.v_users where token = {token})
            """,
            ct);
        await db.Database.ExecuteSqlAsync(
            $"""
            update membership.class_registrations
            set residence_location = null, work_location = null, preferred_location = null, birth_year = null, profession = null,
                islamic_study_years = null, interests = null, other_interests = null, education = null, field_of_study = null,
                field_of_study_other = null, professional_courses = null, professional_courses_other = null, occupation_type = null,
                field_of_work = null, years_experience = null, role_level = null, linkedin_url = null, status_reason = null
            where token = {token}
            """,
            ct);
    }

    private sealed record MemberCreated(int Token);
}
