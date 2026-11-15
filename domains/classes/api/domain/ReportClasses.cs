using Microsoft.EntityFrameworkCore;

namespace Tsr.Classes.Api.Domain;

/// <summary>The class rows a report lists (PHP <c>MisModel::reportClasses</c> via <c>ClassesModel::getAll</c>): shared by the pending report and the MCQ summary and adherence reports.</summary>
internal static class ReportClasses
{
    private const int MaxClasses = 20000;

    /// <summary>PHP getAll: the level must exist (inner join), the teacher's name and the location may be missing (""); order gender, level order, id. Only the ids given (the scope's). Bound: 20000 classes.</summary>
    public static async Task<List<PendingRules.ClassRow>> ForIdsAsync(ClassesContext db, int[] ids, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(ids);
        return await db.Database
            .SqlQuery<PendingRules.ClassRow>($"""
                select c.id as "Id", c.code::text as "Code", cl.name::text as "Level", c.teacher as "Teacher", coalesce(u.name::text, '') as "TeacherName", coalesce(c.location::text, '') as "Location"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members u on u.token = c.teacher
                where c.id = any({ids})
                order by c.gender, cl.sort_order, c.id
                limit {MaxClasses}
                """)
            .ToListAsync(ct);
    }
}
