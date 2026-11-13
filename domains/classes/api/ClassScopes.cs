using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;

namespace Tsr.Classes.Api;

/// <summary>
/// Supplies access's port from this domain's own tables (PHP PermissionsModel: taught, MCQ-flagged and enrolled classes, all active).
/// Replaces access's default "no classes" (registered in <see cref="ClassesModule.AddClasses"/>).
/// </summary>
internal sealed class ClassScopes(ClassesContext db) : IClassScopes
{
    private const int MaxClasses = 10000;

    internal sealed record Fact(int Id, int Gender, string? City, string? Country, int? LevelId, string? Code, string? Name);

    internal sealed record TagRow(int ClassId, string Name);

    internal sealed record MembershipRow(int[] Taught, int[] Flagged, int[] Enrolled);

    // One command: access asks this for every signed-in request.
    public async Task<ClassMemberships> MembershipsAsync(int token, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<MembershipRow>($"""
                select
                  array(select id from classes.classes where teacher = {token} and status = 'A' order by id) as "Taught",
                  array(select distinct cs.class_id from classes.class_students cs
                        join classes.classes c on c.id = cs.class_id
                        where cs.token_no = {token} and cs.mcq_admin = 1 and cs.removed_at is null and c.status = 'A'
                        order by 1) as "Flagged",
                  array(select distinct cs.class_id from classes.class_students cs
                        join classes.classes c on c.id = cs.class_id
                        where cs.token_no = {token} and cs.status = 'A' and cs.removed_at is null and c.status = 'A'
                        order by 1) as "Enrolled"
                """)
            .ToListAsync(ct);
        return new ClassMemberships(rows[0].Taught, rows[0].Flagged, rows[0].Enrolled);
    }

    public async Task<ClassFacts?> ActiveClassAsync(int classId, CancellationToken ct)
    {
        var facts = await FactsAsync(classId, ct);
        return facts.Count == 0 ? null : facts[0];
    }

    public Task<IReadOnlyList<ClassFacts>> ActiveClassesAsync(CancellationToken ct) => FactsAsync(null, ct);

    private async Task<IReadOnlyList<ClassFacts>> FactsAsync(int? classId, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<Fact>($"""
                select id as "Id", coalesce(gender, 0) as "Gender", city as "City", country as "Country", class_level_id as "LevelId", code as "Code", name as "Name"
                from classes.classes where status = 'A' and ({classId}::int is null or id = {classId}) order by id limit {MaxClasses}
                """)
            .ToListAsync(ct);
        var tags = await db.Database
            .SqlQuery<TagRow>($"""
                select ct.class_id as "ClassId", t.name as "Name" from classes.class_tags ct
                join classes.tags t on t.id = ct.tag_id
                where ct.deleted_at is null and t.deleted_at is null and ({classId}::int is null or ct.class_id = {classId})
                order by t.name
                """)
            .ToListAsync(ct);
        var byClass = tags.ToLookup(t => t.ClassId, t => t.Name);
        return rows.Select(r => new ClassFacts(r.Id, r.Gender, r.City, r.Country, r.LevelId, byClass[r.Id].ToList(), r.Code ?? string.Empty, r.Name ?? string.Empty)).ToList();
    }
}
