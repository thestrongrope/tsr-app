using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminTeachers;

// Slice: GET /admin/teachers?gender= -> {gender, levels, teachers}: a gender's trained teachers with their five training flags and the classes they conduct. The gender is a gender administrator's own (genderLock), else
// the query's (exactly 2 is ladies, anything else gents: no 422), then teachers:read for that gender (403 "You do not have permission to do that"). No audit row. No contact details. Contract: spec/api.yaml.
// PHP: routes/teachers.php route_admin_teachers (:42), TeachersModel::getAll / trainingList. Quirks: a teacher appears only when their record is active AND they are themselves a student in an active class (an inner
// join), "level" is the alphabetical minimum of the codes of those classes (not the lowest level), gender matches the stored text "1" or "2" only ("Male" never), conducting is the active classes they teach
// ordered by level then id. Bound: 5000 teachers.

internal static class AdminTeachersSlice
{
    private const int MaxRows = 5000;

    private sealed record Row(int Token, string? Name, string? Level, int Salman, int Abuzar, int Miqdad, int Ammar, int Bilal, int Classes, string? Conducting);

    internal sealed record Level(string Key, string Code, string Name);

    internal sealed record Teacher(int Token, string Name, string Level, int Classes, Dictionary<string, bool> Flags, IReadOnlyList<string> Conducting);

    internal sealed record Body(int Gender, IReadOnlyList<Level> Levels, IReadOnlyList<Teacher> Teachers);

    public static IEndpointRouteBuilder MapAdminTeachers(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/teachers", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var asked = context.Request.Query["gender"];
        var gender = await TeacherWriter.GenderAsync(permissions, caller, asked.Count == 0 ? string.Empty : asked[^1] ?? string.Empty, ct);
        if (!await permissions.CanAsync(caller, "teachers:read", AccessTarget.ForGender(gender), ct))
        {
            return Refusals.NotPermitted();
        }

        var genderText = gender.ToString(System.Globalization.CultureInfo.InvariantCulture);
        var rows = await source.ListAsync(
            $"""
                select t.token as "Token", m.name as "Name", c2.class_level as "Level",
                       max(t.salman) as "Salman", max(t.abuzar) as "Abuzar", max(t.miqdad) as "Miqdad", max(t.ammar) as "Ammar", max(t.bilal) as "Bilal",
                       count(c.id)::int as "Classes", string_agg(c.code::text, ', ' order by c.sort_order, c.id) as "Conducting"
                from classes.teachers t
                join membership.v_members m on m.token = t.token
                join (
                    select cs.token_no as token, min(cl.code::text) as class_level
                    from classes.class_students cs
                    join classes.classes k on k.id = cs.class_id and k.status = 'A'
                    join classes.class_levels cl on cl.id = k.class_level_id
                    where cs.status = 'A' and cs.removed_at is null
                    group by cs.token_no) c2 on c2.token = t.token
                left join (
                    select k.teacher, k.id, k.code, cl.sort_order
                    from classes.classes k
                    join classes.class_levels cl on cl.id = k.class_level_id
                    where k.status = 'A') c on c.teacher = t.token
                where m.gender = {genderText} and t.status = 'A'
                group by t.token, m.name, c2.class_level
                order by m.name, t.token
                limit {MaxRows}
                """,
            row => new Row(
                row.Int("Token"),
                row.TextOrNull("Name"),
                row.TextOrNull("Level"),
                row.Int("Salman"),
                row.Int("Abuzar"),
                row.Int("Miqdad"),
                row.Int("Ammar"),
                row.Int("Bilal"),
                row.Int("Classes"),
                row.TextOrNull("Conducting")),
            ct);

        var levels = TeacherTraining.Levels.Select(l => new Level(l.Key, l.Code, PhpText.UcFirst(l.Key))).ToList();
        var teachers = rows.Select(r => new Teacher(
            r.Token,
            PhpCast.Str(r.Name),
            PhpCast.Str(r.Level),
            r.Classes,
            Flags(r),
            string.IsNullOrEmpty(r.Conducting) ? [] : r.Conducting.Split(", "))).ToList();
        return Results.Json(new Body(gender, levels, teachers), ClassesJson.Answers.TeachersBody);
    }

    private static Dictionary<string, bool> Flags(Row r) => new()
    {
        ["salman"] = r.Salman != 0,
        ["abuzar"] = r.Abuzar != 0,
        ["miqdad"] = r.Miqdad != 0,
        ["ammar"] = r.Ammar != 0,
        ["bilal"] = r.Bilal != 0,
    };
}
