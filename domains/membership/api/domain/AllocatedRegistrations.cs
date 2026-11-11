using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>
/// The placed-registrations file as data (PHP: routes/reports.php route_reports_registrations_allocated_download :1745, subscribers.php getAllocatedRegistrations :495): everyone who registered and now sits in an active class, one row per member, newest registration first, with the class,
/// level and teacher they were placed with, and the pure rules of its columns (the labels PHP looks up by the integer value of a stored text, the interests text, the count of extra students).
/// Copied: the registrations of a token are grouped (each column the MAX); the class columns are the MAX over the member's enrolments not removed in active classes (code, level name, teacher token, teacher name, extra students: each its own MAX, so a member in two classes can show
/// a mix; the text MAX uses the "C" collation, MariaDB's is case-insensitive); the gender is PHP's integer comparison of the stored text (gents: 1 or 0, so "Male", empty and "0" are gents; ladies: 2; no gender at all is neither); members whose email ends
/// @thestrongrope.com (the placeholder members, case-insensitive) are left out; "class only" keeps registrations that name a class (for_classid above 0). A caller who reaches only assigned classes gets the people placed in those classes (no assigned class is nobody). Deviation: at most 20000 rows.
/// </summary>
internal static class AllocatedRegistrations
{
    private const int MaxRows = 20000;

    internal sealed record Row(
        int Token, string? Name, string? UserCreated, string? Gender, string? Mobile, string? Email, string? AgeRange, string? City, string? State, string? Country, string? Zip, string? CreatedAt, string? ModifiedAt,
        string? Residence, string? Work, string? ClassLevel, string? ClassNumber, string? Profession, string? Interests, string? OtherInterests, string? ClassCode, string? AllocatedLevel, int? Teacher,
        string? TeacherName, string? ExtraStudents);

    private static readonly string[] Genders = ["Not mentioned", "Male", "Female"];

    private static readonly string[] AgeRanges = ["Not mentioned", "Less than 15", "15 to 25", "26 to 40", "Above 40"];

    /// <summary>PHP <c>$genders[(int) $stored] ?? null</c>.</summary>
    public static string? GenderLabel(string? stored) => Label(Genders, stored);

    /// <summary>PHP <c>$ageRanges[(int) $stored] ?? null</c>.</summary>
    public static string? AgeRangeLabel(string? stored) => Label(AgeRanges, stored);

    /// <summary>PHP <c>($interests ?? '') . ($other ? ',' . str_replace(' ,', ',', $other) : '')</c>: an empty text and "0" are falsy.</summary>
    public static string Interests(string? interests, string? other)
    {
        var tail = other is null or "" or "0" ? string.Empty : "," + other.Replace(" ,", ",", StringComparison.Ordinal);
        return (interests ?? string.Empty) + tail;
    }

    /// <summary>PHP <c>trim($extra) === '' ? 0 : count(explode("\n", $extra))</c>.</summary>
    public static int ExtraStudents(string? extra) =>
        extra is null || PhpText.Trim(extra).Length == 0 ? 0 : extra.Count(c => c == '\n') + 1;

    /// <summary>The people placed in a class for one gender. <paramref name="classOnly"/>: only registrations that name a class. <paramref name="classIds"/>: only people placed in those classes (null: any class).</summary>
    public static async Task<List<Row>> LoadAsync(MembershipContext db, int gender, bool classOnly, int[]? classIds, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        var limited = classIds is not null;
        var ids = classIds ?? [];
        var ladies = gender == 2;
        return await db.Database
            .SqlQuery<Row>($"""
                select r.token as "Token", p.name::text as "Name", to_char(u.created_on at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS') as "UserCreated", p.gender::text as "Gender", p.mobile::text as "Mobile", u.email::text as "Email",
                       p.age_range::text as "AgeRange", p.city::text as "City", p.state::text as "State", p.country::text as "Country", p.zip::text as "Zip",
                       to_char(r.created_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS') as "CreatedAt", to_char(r.modified_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS') as "ModifiedAt",
                       r.residence_location as "Residence", r.work_location as "Work", r.class_level as "ClassLevel", r.class_number as "ClassNumber", r.profession as "Profession",
                       r.interests as "Interests", r.other_interests as "OtherInterests", a.code as "ClassCode", a.level as "AllocatedLevel", a.teacher as "Teacher", a.teacher_name as "TeacherName", a.extra as "ExtraStudents"
                from (
                    select token, max(for_classid) as for_classid, max(created_at) as created_at, max(modified_at) as modified_at,
                           max(residence_location::text collate "C") as residence_location, max(work_location::text collate "C") as work_location,
                           max(class_level::text collate "C") as class_level, max(class_number::text collate "C") as class_number, max(profession::text collate "C") as profession,
                           max(interests::text collate "C") as interests, max(other_interests::text collate "C") as other_interests
                    from membership.class_registrations
                    group by token
                ) r
                join identity.v_users u on u.token = r.token
                left join membership.member_profiles p on p.user_id = u.id
                join lateral (
                    select max(c.code::text collate "C") as code, max(c.level_name::text collate "C") as level, max(c.teacher) as teacher, max(t.name::text collate "C") as teacher_name,
                           max(c.extra_students::text collate "C") as extra
                    from classes.v_enrolments cs
                    join classes.v_classes c on c.id = cs.class_id and c.status = 'A'
                    left join membership.v_members t on t.token = c.teacher
                    where cs.token_no = r.token and cs.removed_at is null and ({limited} = false or c.id = any({ids}))
                    having count(*) > 0) a on true
                where p.gender is not null
                  and (case when {ladies} then coalesce(nullif(substring(p.gender::text from '^\s*[+-]?[0-9]+(?:\.[0-9]*)?'), '')::numeric, 0) = 2
                            else coalesce(nullif(substring(p.gender::text from '^\s*[+-]?[0-9]+(?:\.[0-9]*)?'), '')::numeric, 0) in (0, 1) end)
                  and ({classOnly} = false or r.for_classid > 0)
                  and u.email not ilike '%@thestrongrope.com'
                order by r.created_at desc, r.token
                limit {MaxRows}
                """)
            .ToListAsync(ct);
    }

    private static string? Label(string[] labels, string? stored)
    {
        var index = PhpValue.IntOfText(stored ?? string.Empty);
        return index >= 0 && index < labels.Length ? labels[index] : null;
    }
}
