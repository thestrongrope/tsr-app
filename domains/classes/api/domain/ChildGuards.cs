using Microsoft.EntityFrameworkCore;

namespace Tsr.Classes.Api.Domain;

/// <summary>PHP's GuardiansModel checks behind the /me/children/{child_token}/classes routes: an active guardian link (membership's published view), and any enrolment row.</summary>
internal static class ChildGuards
{
    /// <summary>isActiveGuardian: tokens above zero and an active link from the parent to the child.</summary>
    public static async Task<bool> IsActiveGuardianAsync(ClassesContext db, int parentToken, long childToken, CancellationToken ct)
    {
        if (parentToken <= 0 || childToken <= 0)
        {
            return false;
        }

        var rows = await db.Database
            .SqlQuery<int>($"""select 1 as "Value" from membership.v_guardian_links where parent_token = {parentToken} and child_token = {childToken} and status = 'active' limit 1""")
            .ToListAsync(ct);
        return rows.Count > 0;
    }

    /// <summary>isChildEnrolled: any enrolment row of the child in the class, removed or not.</summary>
    public static async Task<bool> IsChildEnrolledAsync(ClassesContext db, long childToken, long classId, CancellationToken ct)
    {
        if (childToken <= 0 || classId <= 0)
        {
            return false;
        }

        var rows = await db.Database
            .SqlQuery<int>($"""select 1 as "Value" from classes.class_students where token_no = {childToken} and class_id = {classId} limit 1""")
            .ToListAsync(ct);
        return rows.Count > 0;
    }
}
