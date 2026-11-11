using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

// The waiting list as data, for the screen (GET /reports/registrations?gender) and the download (its /download) -> {gender, registrants[{id, token, name, status, registeredOn, requestedClass, email, mobile, residenceLocation, preferredLocation, workLocation, birthYear, classLevel,
// classNumber, profession, islamicStudyYears, interests, city, country, zip}]}: the people waiting to be placed in a class, newest first.
// PHP: routes/reports.php api_require_registrations_report (:1696), subscribers.php waitingRegistrations (:584). Guard: the gender (locked by registrations:read, else "2" is ladies,
// anything else gents), then registrations:read for that gender (403); NO row scope beyond the gender (PHP's waiting list has none, so a coordinator who reaches assigned classes sees every waiting person of
// their locked gender). One query.
// Copied: one row per token, each column the MAX over the member's registrations (so the status is the greatest TEXT: Rejected > Pending > Accepted, and one Rejected form hides the member); members with an enrolment
// that is not removed in an active class, members whose email ends @thestrongrope.com (case-insensitive) and members with no account are left out; the requested class is shown only while that class is active;
// the gender is the stored text compared with "1" or "2". Deviations: at most 5000 rows (PHP has no bound); ties on the creation time are ordered by id (PHP: undefined); the text MAX uses the "C" collation
// (MariaDB: case-insensitive).

internal static class WaitingRegistrations
{
    private const int MaxRows = 5000;

    internal sealed record Row(
        int Id, int Token, string? Name, string Status, string RegisteredOn, string? ForClass, string? Email, string? Mobile, string? Residence, string? Preferred, string? Work, string? ClassLevel,
        string? ClassNumber, string? Profession, int? BirthYear, int? IslamicYears, string? Interests, string? City, string? Country, string? Zip, string CreatedAt = "");

    internal sealed record Item(int Id, int Token, string Name, string Status, string RegisteredOn, string? RequestedClass, string? Email, string? Mobile, string? ResidenceLocation, string? PreferredLocation,
        string? WorkLocation, int? BirthYear, string? ClassLevel, string? ClassNumber, string? Profession, string? IslamicStudyYears, string? Interests, string? City, string? Country, string? Zip);

    /// <summary>PHP <c>api_require_registrations_report</c>'s guard: the gender (locked by registrations:read, else "2" is ladies, anything else gents), then registrations:read for it (403).</summary>
    public static async Task<(int Gender, IResult? Refusal)> GuardAsync(HttpContext context, Permissions permissions, Caller caller, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(context);
        var reach = await permissions.ReachAsync(caller, "registrations:read", ct);
        var asked = context.Request.Query["gender"];
        var gender = reach.GenderLock ?? (asked.Count > 0 && asked[^1] == "2" ? 2 : 1);
        if (!await permissions.CanAsync(caller, "registrations:read", AccessTarget.ForGender(gender), ct))
        {
            return (gender, Refusals.NotPermitted());
        }

        return (gender, null);
    }

    public static async Task<List<Row>> LoadAsync(MembershipContext db, int gender, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        var stored = gender.ToString(System.Globalization.CultureInfo.InvariantCulture);
        return await db.Database
            .SqlQuery<Row>($"""
                select r.id as "Id", r.token as "Token", p.name::text as "Name", r.status as "Status", to_char(r.created_at at time zone 'UTC', 'YYYY-MM-DD') as "RegisteredOn", f.code::text as "ForClass",
                       u.email::text as "Email", p.mobile::text as "Mobile", r.residence_location as "Residence", r.preferred_location as "Preferred", r.work_location as "Work", r.class_level as "ClassLevel",
                       r.class_number as "ClassNumber", r.profession as "Profession", r.birth_year as "BirthYear", r.islamic_study_years as "IslamicYears", r.interests as "Interests",
                       p.city::text as "City", p.country::text as "Country", p.zip::text as "Zip",
                       to_char(r.created_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS') as "CreatedAt"
                from (
                    select max(id) as id, max(token) as token, max(for_classid) as for_classid, max(status::text collate "C") as status, max(created_at) as created_at,
                           max(residence_location::text collate "C") as residence_location, max(work_location::text collate "C") as work_location, max(preferred_location::text collate "C") as preferred_location,
                           max(class_level::text collate "C") as class_level, max(class_number::text collate "C") as class_number, max(birth_year) as birth_year,
                           max(profession::text collate "C") as profession, max(islamic_study_years) as islamic_study_years, max(interests::text collate "C") as interests
                    from membership.class_registrations
                    group by token
                ) r
                join identity.v_users u on u.token = r.token
                left join membership.member_profiles p on p.user_id = u.id
                left join classes.v_classes f on f.id = r.for_classid and f.status = 'A'
                where r.status <> 'Rejected'
                  and not exists (
                      select 1 from classes.v_enrolments cs join classes.v_classes c on c.id = cs.class_id
                      where c.status = 'A' and cs.removed_at is null and cs.token_no = r.token)
                  and u.email not ilike '%@thestrongrope.com'
                  and p.gender::text = {stored}
                order by r.created_at desc, r.id desc
                limit {MaxRows}
                """)
            .ToListAsync(ct);
    }

    /// <summary>PHP <c>api_reports_registrant</c>: <c>str?</c> (empty is null) for the short columns, <c>text?</c> (entity-decoded, empty is null) for the free texts, the years as text.</summary>
    internal static Item ToItem(Row row) => new(
        row.Id, row.Token, row.Name ?? string.Empty, row.Status, row.RegisteredOn, Short(row.ForClass), Short(row.Email), Short(row.Mobile), Free(row.Residence), Free(row.Preferred), Free(row.Work), row.BirthYear,
        Short(row.ClassLevel), Short(row.ClassNumber), Free(row.Profession), row.IslamicYears?.ToString(System.Globalization.CultureInfo.InvariantCulture), Free(row.Interests), Short(row.City), Short(row.Country), Short(row.Zip));

    private static string? Short(string? value) => string.IsNullOrEmpty(value) ? null : value;

    private static string? Free(string? value) => string.IsNullOrEmpty(value) ? null : PhpText.HtmlDecode(value);
}
