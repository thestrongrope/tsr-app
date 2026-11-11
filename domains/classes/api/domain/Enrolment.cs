using Microsoft.EntityFrameworkCore;
using Tsr.Membership.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP <c>ClassStudentsModel::addStudent</c>, shared by adding a student, joining by link and placing a registration (domains/CLAUDE.md rule 1: three slices use it). Refused (false, nothing
/// written) for a token that is not a member (or is not positive) and for a member of a known gender other than the class's. Otherwise: membership's accepted-registration command (a member
/// with no class request gets one), then a new <c>class_students</c> row (a removed member gets a NEW row, not a restore), <c>added_by</c> only when named. The caller owns the transaction
/// and writes the one outbox row.
/// </summary>
/// <summary>The outbox payload of classes.student_enrolled: who enrolled whom (AddedBy is null for a join and a placement) and through which route (added, joined, placed, bulk).</summary>
internal sealed record StudentEnrolled(int ClassId, int Token, int? AddedBy, string Source);

internal static class Enrolment
{
    private sealed record Pair(string? MemberGender, int? ClassGender);

    public static async Task<bool> AddAsync(ClassesContext db, int classId, int token, int? addedBy, CancellationToken ct)
    {
        if (token <= 0)
        {
            return false;
        }

        var pairs = await db.Database
            .SqlQuery<Pair>($"""
                select m.gender as "MemberGender", c.gender as "ClassGender"
                from membership.v_members m, classes.classes c
                where m.token = {token} and c.id = {classId}
                order by m.user_id
                limit 1
                """)
            .ToListAsync(ct);
        if (pairs.Count == 0 || !EnrolmentRules.GenderAllows(pairs[0].MemberGender, pairs[0].ClassGender))
        {
            return false;
        }

        await MembershipCommands.RecordAcceptedRegistrationAsync(db, token, classId, ct);
        if (addedBy is null)
        {
            await db.Database.ExecuteSqlAsync(
                $"insert into classes.class_students (class_id, token_no, joined_on) values ({classId}, {token}, (now() at time zone 'UTC')::date)", ct);
        }
        else
        {
            await db.Database.ExecuteSqlAsync(
                $"insert into classes.class_students (class_id, token_no, joined_on, added_by) values ({classId}, {token}, (now() at time zone 'UTC')::date, {addedBy})", ct);
        }

        return true;
    }
}
