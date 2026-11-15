using Microsoft.EntityFrameworkCore;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// The active teachers report as data, for the screen (GET /reports/active-teachers) and the download (its /download): each teacher of the active classes the scope reaches,
/// with the classes taught and the classes the teacher attends as a student. PHP: mis.php activeTeachers (:2024), sorted by api_require_active_teachers_report (:1522).
/// Copied: the teachers are filtered by THEIR OWN gender (users.gender = the gender asked for, compared as text), not by the gender of the class; a teacher with no member row, or whose class has no level, is not listed;
/// maxLevel is the name of the lowest level id among the classes; the codes are listed once each in level order then class id; the classes attended are those with an enrolment not removed (the status column is not read), the
/// teachers' names of those classes are GROUP_CONCAT's (a class whose teacher has no name adds a code and no name); sorted by lower-case ASCII name then token. Deviation: at most 20000 classes and 50000 attended classes.
/// </summary>
internal static class ActiveTeachers
{
    private const int MaxAttended = 50000;

    internal sealed record ClassRow(int Teacher, string Name, int ClassId, string Code, int LevelId, int SortOrder, string Level);

    internal sealed record AttendRow(int Token, int ClassId, string Code, int SortOrder, string? TeacherName);

    internal sealed record Item(int Token, string Name, string? AttendingClass, string? SelfTeacher, string MaxLevel, int TotalClasses, string ConductingClasses);

    public static async Task<IReadOnlyList<Item>> LoadAsync(ClassesContext db, ReportScope scope, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(scope);
        var ids = await scope.ClassIdsAsync(db, 0, ct);
        var gender = scope.Gender.ToString(System.Globalization.CultureInfo.InvariantCulture);
        var classes = await db.Database
            .SqlQuery<ClassRow>($"""
                select c.teacher as "Teacher", coalesce(m.name, '')::text as "Name", c.id as "ClassId", c.code::text as "Code",
                       cl.id as "LevelId", cl.sort_order as "SortOrder", cl.name::text as "Level"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                join membership.v_members m on m.token = c.teacher and m.gender = {gender}
                where c.id = any({ids})
                """)
            .ToListAsync(ct);

        var teachers = classes.Select(c => c.Teacher).Distinct().ToArray();
        var attends = await db.Database
            .SqlQuery<AttendRow>($"""
                select cs.token_no as "Token", c.id as "ClassId", c.code::text as "Code", cl.sort_order as "SortOrder", tu.name::text as "TeacherName"
                from classes.class_students cs
                join classes.classes c on c.id = cs.class_id
                join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members tu on tu.token = c.teacher
                where cs.removed_at is null and c.id = any({ids}) and cs.token_no = any({teachers})
                limit {MaxAttended}
                """)
            .ToListAsync(ct);

        return Build(classes, attends);
    }

    /// <summary>The teachers, one row each, in PHP's order (lower-case ASCII name, then token).</summary>
    internal static IReadOnlyList<Item> Build(IReadOnlyList<ClassRow> classes, IReadOnlyList<AttendRow> attends)
    {
        var attendsOf = attends.ToLookup(a => a.Token);
        var items = new List<Item>();
        foreach (var group in classes.GroupBy(c => c.Teacher))
        {
            var ordered = group.OrderBy(c => c.SortOrder).ThenBy(c => c.ClassId).ToList();
            var top = group.MinBy(c => c.LevelId)!;
            var attending = attendsOf[group.Key].OrderBy(a => a.SortOrder).ThenBy(a => a.ClassId).ToList();
            var names = attending.Where(a => a.TeacherName is not null).Select(a => a.TeacherName!).ToList();
            items.Add(new Item(
                group.Key,
                top.Name,
                attending.Count == 0 ? null : string.Join(", ", attending.Select(a => a.Code)),
                names.Count == 0 ? null : string.Join(", ", names),
                top.Level,
                ordered.Count,
                string.Join(", ", ordered.Select(c => c.Code).Distinct())));
        }

        return [.. items.OrderBy(i => AsciiLower(i.Name), StringComparer.Ordinal).ThenBy(i => i.Token)];
    }

    private static string AsciiLower(string text) => string.Create(text.Length, text, (span, source) =>
    {
        for (var i = 0; i < source.Length; i++)
        {
            span[i] = source[i] is >= 'A' and <= 'Z' ? (char)(source[i] + 32) : source[i];
        }
    });
}
