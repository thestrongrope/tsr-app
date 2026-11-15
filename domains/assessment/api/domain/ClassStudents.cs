using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// A class's current students as PHP's ClassStudentsModel::getStudents reads them (status A, not removed, one row per member, by name), through classes' <c>v_enrolments</c> and the members' published views
/// (<c>membership.v_members</c> for the name, <c>identity.v_users</c> for the email). Used by the offline entry (who may be written for) and publish (who is told). At most 5000.
/// </summary>
internal static partial class ClassStudents
{
    internal sealed record Student(int Token, string Name, string Email);

    /// <summary>PHP isOfflineStudent: <c>/@thestrongrope\.com$/i</c>, a member with no phone whose teacher made an internal address. PHP's <c>$</c> also matches before a final line break, as .NET's does.</summary>
    [GeneratedRegex(@"@thestrongrope\.com$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex OfflineEmail();

    public static bool IsOffline(string email) => OfflineEmail().IsMatch(email);

    public static async Task<IReadOnlyList<Student>> ListAsync(AssessmentContext db, long classId, CancellationToken ct) =>
        await db.Database
            .SqlQuery<Student>($"""
                select e.token_no as "Token", coalesce(max(m.name::text), '') as "Name", coalesce(max(u.email::text), '') as "Email"
                from classes.v_enrolments e
                join identity.v_users u on u.token = e.token_no
                left join membership.v_members m on m.token = e.token_no
                where e.class_id = {classId} and e.status = 'A' and e.removed_at is null
                group by e.token_no
                order by coalesce(max(m.name::text), ''), e.token_no
                limit 5000
                """)
            .ToListAsync(ct);
}
