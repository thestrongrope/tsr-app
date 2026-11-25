using Npgsql;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP <c>ClassesModel::getAll(0, includeInactive)</c> as the admin screens use it: every class with its level's name (a class with no level is left out), its teacher's name, its live enrolment
/// count (rows not removed, whatever their status) and its city and country, ordered gender, level order, id. Shared by the transfer, the deactivation and the candidate routes. Bound: 20000 classes.
/// As in PHP, a caller whose only reach on <c>classes:read</c> is "assigned" gets those classes and no other, whatever permission opened the screen (<see cref="AssignedAsync"/>).
/// </summary>
internal static class ClassListing
{
    private const int MaxRows = 20000;

    internal sealed record Row(int Id, string Code, string Name, string Level, int? Gender, string? TeacherName, string? City, string? Country, int Students, string Status);

    private static Row ReadRow(DbRow row) =>
        new(
            row.Int("Id"),
            row.Text("Code"),
            row.Text("Name"),
            row.Text("Level"),
            row.IntOrNull("Gender"),
            row.TextOrNull("TeacherName"),
            row.TextOrNull("City"),
            row.TextOrNull("Country"),
            row.Int("Students"),
            row.Text("Status"));

    /// <summary>PHP assignedOnlyIds(caller, 'classes:read'): the classes a listing is limited to, or null when it is not limited.</summary>
    public static async Task<IReadOnlyList<int>?> AssignedAsync(Permissions permissions, Caller caller, CancellationToken ct) =>
        (await permissions.ReachAsync(caller, "classes:read", ct)).AssignedOnlyIds;

    public static async Task<List<Row>> AllAsync(NpgsqlDataSource source, IReadOnlyList<int>? assigned, bool includeInactive, CancellationToken ct)
    {
        var limited = assigned is not null;
        var ids = assigned?.ToArray() ?? [];
        return await source.ListAsync(
            $"""
                select c.id as "Id", c.code as "Code", c.name as "Name", cl.name as "Level", c.gender as "Gender", t.name as "TeacherName",
                       c.city::text as "City", c.country::text as "Country",
                       (select count(1) from classes.class_students s where s.class_id = c.id and s.removed_at is null)::int as "Students",
                       c.status as "Status"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members t on t.token = c.teacher
                where ({includeInactive} or c.status = 'A')
                  and (not {limited} or c.id = any({ids}))
                order by c.gender, cl.sort_order, c.id
                limit {MaxRows}
                """,
            ReadRow,
            ct);
    }

    /// <summary>The class with this id in any status, as <see cref="AllAsync"/> would list it, or null.</summary>
    public static async Task<Row?> FindAsync(NpgsqlDataSource source, IReadOnlyList<int>? assigned, long classId, CancellationToken ct)
    {
        var limited = assigned is not null;
        var ids = assigned?.ToArray() ?? [];
        var rows = await source.ListAsync(
            $"""
                select c.id as "Id", c.code as "Code", c.name as "Name", cl.name as "Level", c.gender as "Gender", t.name as "TeacherName",
                       c.city::text as "City", c.country::text as "Country",
                       (select count(1) from classes.class_students s where s.class_id = c.id and s.removed_at is null)::int as "Students",
                       c.status as "Status"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members t on t.token = c.teacher
                where c.id = {classId}
                  and (not {limited} or c.id = any({ids}))
                limit 1
                """,
            ReadRow,
            ct);
        return rows.Count == 0 ? null : rows[0];
    }
}
