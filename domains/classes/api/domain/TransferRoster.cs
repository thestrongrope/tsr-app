using System.Globalization;
using Microsoft.EntityFrameworkCore;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP <c>ClassStudentsModel::transferSourceRoster</c>: the students who can be moved out of a class: its active students (first enrolment's day), or for a closed class with none, the students it had when
/// it was deactivated (removal reason "Class deactivated: ..." and no active enrolment anywhere), each marked <c>fromDeactivation</c>. An active class never falls back. Shared by the roster route and the
/// transfer route (which names the students from it). Bound: 5000 rows.
/// </summary>
internal static class TransferRoster
{
    private const int MaxRows = 5000;

    internal sealed record Student(int Token, string? Name, string? Email, string? Mobile, string? JoinedOn, string? RemovedOn, bool FromDeactivation);

    private sealed record Cohort(int Token, string? Name, string? Email, string? Mobile, DateOnly? RemovedOn);

    public static async Task<List<Student>> ForAsync(ClassesContext db, int classId, bool classActive, CancellationToken ct)
    {
        var active = await ClassRoster.ActiveAsync(db, classId, ct);
        if (active.Count > 0 || classActive)
        {
            return active
                .Select(s => new Student(s.Token, s.Name, s.Email, s.Mobile, s.JoinedOn?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), null, false))
                .ToList();
        }

        var cohort = await db.Database
            .SqlQuery<Cohort>($"""
                select m.token as "Token", m.name as "Name", u.email as "Email", m.mobile as "Mobile", (max(cs.removed_at) at time zone 'UTC')::date as "RemovedOn"
                from classes.class_students cs
                join membership.v_members m on m.token = cs.token_no
                join identity.v_users u on u.id = m.user_id
                where cs.class_id = {classId} and cs.status = 'I' and cs.removed_at is not null and cs.removed_reason like 'Class deactivated:%'
                  and not exists (select 1 from classes.class_students act where act.token_no = cs.token_no and act.removed_at is null and act.status = 'A')
                group by m.user_id, m.name, m.token, u.email, m.mobile
                order by m.name, m.token
                limit {MaxRows}
                """)
            .ToListAsync(ct);
        return cohort
            .Select(c => new Student(c.Token, c.Name, c.Email, c.Mobile, null, c.RemovedOn?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), true))
            .ToList();
    }
}
