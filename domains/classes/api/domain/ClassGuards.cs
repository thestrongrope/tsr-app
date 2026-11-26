using Microsoft.AspNetCore.Http;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// The guards the class reads share, each PHP's own (routes/classes.php, response.php): the caller's gender is a number, the class is active and
/// complete, and the id in the path is PHP's <c>(int)</c> cast of it. Each answer the refusal PHP gives, so a slice reads as one guard chain.
/// </summary>
internal static class ClassGuards
{
    /// <summary>The class PHP's <c>ClassesModel::get()</c> returns: active, with its gender, level and teacher rows present (else it is "not found").</summary>
    internal sealed record ClassHead(int Id, string Name, string Code, int? LevelId, string LevelName, int Gender);

    /// <summary>PHP casts a path segment with (int): "5abc" is 5, "abc" is 0 (no such class).</summary>
    public static long IdOf(string segment) => PhpValue.IntOfText(segment);

    /// <summary>A token in a path: PHP (int) cast, kept inside what a token column holds (a larger number matches nobody).</summary>
    public static int TokenOf(string segment) => (int)Math.Clamp(IdOf(segment), int.MinValue, int.MaxValue);

    /// <summary>PHP's <c>(int)($_GET[name] ?? default)</c>: the numeric prefix of the value, the default when it is absent.</summary>
    public static long QueryInt(HttpContext context, string name, long fallback)
    {
        var values = context.Request.Query[name];
        return values.Count == 0 ? fallback : PhpValue.IntOfText(values[^1] ?? string.Empty);
    }

    /// <summary>PHP api_require_class_schedule: whoever may update the class, else whoever holds classes:schedule on it (its teacher or MCQ admin).</summary>
    public static async Task<bool> CanSetScheduleAsync(Permissions permissions, Caller caller, int classId, CancellationToken ct)
    {
        var target = AccessTarget.ForClass(classId);
        return await permissions.CanAsync(caller, "classes:update", target, ct) || await permissions.CanAsync(caller, "classes:schedule", target, ct);
    }

    public static IResult ScheduleRefusal() => Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to set this class's schedule");

    public static async Task<ClassHead?> FindActiveClassAsync(NpgsqlDataSource source, long classId, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"""
            select c.id as "Id", c.name as "Name", c.code as "Code", c.class_level_id as "LevelId", cl.name as "LevelName", c.gender as "Gender"
            from classes.classes c
            join platform.v_genders g on g.id = c.gender
            join classes.class_levels cl on cl.id = c.class_level_id
            join membership.v_members t on t.token = c.teacher
            where c.id = {classId} and c.status = 'A'
            limit 1
            """,
            row => new ClassHead(row.Int("Id"), row.Text("Name"), row.Text("Code"), row.IntOrNull("LevelId"), row.Text("LevelName"), row.Int("Gender")),
            ct);
        return rows.Count == 0 ? null : rows[0];
    }

    public static async Task<long?> NumericGenderAsync(NpgsqlDataSource source, Caller caller, CancellationToken ct)
    {
        var gender = await source.ListAsync(
            $"""select coalesce(gender, '') as "Value" from membership.v_members where user_id = {caller.UserId} limit 1""",
            row => row.Text("Value"),
            ct);
        return gender.Count == 1 && PhpValue.IsNumeric(gender[0]) ? PhpValue.IntOfText(gender[0]) : null;
    }

    public static async Task<bool> HasNumericGenderAsync(NpgsqlDataSource source, Caller caller, CancellationToken ct) =>
        await NumericGenderAsync(source, caller, ct) is not null;

    public static async Task<bool> CanViewClassAsync(NpgsqlDataSource source, long classId, int token, CancellationToken ct) =>
        await source.AnyAsync(
            $"""
            select 1 as "Value" from classes.classes c
            where c.id = {classId} and c.status = 'A'
              and (exists (select 1 from classes.class_students cs where cs.class_id = c.id and cs.token_no = {token} and cs.status = 'A' and cs.removed_at is null)
                   or c.teacher = {token})
            limit 1
            """,
            ct);

    /// <summary>The admin-access row without a database context: platform's command needs none.</summary>
    public static async Task LogAdminAccessAsync(HttpContext context, Permissions permissions, Caller caller, CancellationToken ct) =>
        await PlatformCommands.RecordAdminAccessAsync(context, caller.UserId, caller.Token, await permissions.RoleIdAsync(caller, ct), ct);
}
