using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassJoin;

// Slice: POST /classes/join {link} -> the caller joins (or rejoins) the class a link names. Answers {success, message, classId, className}. Contract: spec/api.yaml.
// PHP: routes/classes.php route_class_join (:260), ClassStudentsModel::{getEnrolmentRow, rejoin, addStudent}. Order: classes:join (no target; 403 "You do not have permission to do that"), the caller's gender is a
// number (400 "User gender not set; update profile first"), link (string) trimmed, blank is 422 "link is required"; the class with that link (case-insensitive, its teacher a member) that is active (else 404
// "Invalid class link or class not active"); a class with a gender other than the caller's is 403 "This class is not available for your gender". Then every enrolment row of the caller in the class is judged (PHP judges one
// arbitrary row; with duplicate rows that could hide a removal by someone else): not removed -> 200 success false "You are already enrolled in this class"; removed by someone else -> 403 "You were removed from this class. Please contact the class coordinator."; removed by the
// caller or by nobody -> REJOIN every row of the pair (status A, removed_at and removed_reason cleared, joined_on today, mcq_admin 0; removed_by is NOT cleared) -> 200 "Welcome back! You have re-joined the class";
// no row -> domain/Enrolment.AddAsync with no added_by -> 200 "Successfully joined the class!" EVEN WHEN it refuses (a class without a gender, a member of a known gender: nothing is written, as PHP).
// A link with a NUL byte names no class (404). Events (outbox, same transaction, only when a row was written): classes.student_rejoined, classes.student_enrolled (source "joined"). PHP's search touch is not sent.

internal static class ClassJoinSlice
{
    internal sealed record StudentRejoined(int ClassId, int Token);

    private sealed record Target(int Id, string Name, int? Gender);

    private sealed record Existing(bool AnyLive, bool AnyRemovedByOther);

    public static IEndpointRouteBuilder MapClassJoin(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/join", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "classes:join", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var gender = await ClassGuards.NumericGenderAsync(source, caller, ct);
        if (gender is null)
        {
            return Refusals.GenderNotSet();
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var link = PhpText.Trim(PhpValue.Text(body!.Get("link")));
        if (link.Length == 0)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "link is required");
        }

        var target = await FindAsync(source, link, ct);
        if (target is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Invalid class link or class not active");
        }

        if (target.Gender is not null && target.Gender != gender)
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "This class is not available for your gender");
        }

        return await JoinAsync(source, clock, target, caller.Token, ct);
    }

    private static async Task<Target?> FindAsync(NpgsqlDataSource source, string link, CancellationToken ct)
    {
        if (link.Contains('\0', StringComparison.Ordinal))
        {
            return null;
        }

        var rows = await source.ListAsync(
            $"""
            select c.id as "Id", c.name as "Name", c.gender as "Gender"
            from classes.classes c
            join membership.v_members t on t.token = c.teacher
            where c.link = {link}::citext and c.status = 'A'
            order by c.id
            limit 1
            """,
            row => new Target(row.Int("Id"), row.Text("Name"), row.IntOrNull("Gender")),
            ct);
        return rows.Count == 0 ? null : rows[0];
    }

    private static async Task<IResult> JoinAsync(NpgsqlDataSource source, TimeProvider clock, Target target, int token, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"""
            select coalesce(bool_or(removed_at is null), false) as "AnyLive",
                   coalesce(bool_or(removed_at is not null and removed_by is not null and removed_by <> {token}), false) as "AnyRemovedByOther"
            from classes.class_students where class_id = {target.Id} and token_no = {token}
            having count(*) > 0
            """,
            row => new Existing(row.Bool("AnyLive"), row.Bool("AnyRemovedByOther")),
            ct);
        if (rows.Count == 0)
        {
            await EnrolAsync(source, clock, target.Id, token, ct);
            return Answer(true, "Successfully joined the class!", target);
        }

        if (rows[0].AnyLive)
        {
            return Answer(false, "You are already enrolled in this class", target);
        }

        if (rows[0].AnyRemovedByOther)
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You were removed from this class. Please contact the class coordinator.");
        }

        await RejoinAsync(source, clock, target.Id, token, ct);
        return Answer(true, "Welcome back! You have re-joined the class", target);
    }

    private static async Task EnrolAsync(NpgsqlDataSource source, TimeProvider clock, int classId, int token, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        if (await Enrolment.AddAsync(tx, classId, token, null, ct))
        {
            await Outbox.WriteAsync(tx, "classes.student_enrolled", new StudentEnrolled(classId, token, null, "joined"), ClassesJson.Default.StudentEnrolled, clock, ct);
        }

        await tx.CommitAsync(ct);
    }

    private static async Task RejoinAsync(NpgsqlDataSource source, TimeProvider clock, int classId, int token, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        await tx.ExecuteAsync(
            $"update classes.class_students set status = 'A', removed_at = null, removed_reason = null, joined_on = (now() at time zone 'UTC')::date, mcq_admin = 0 where class_id = {classId} and token_no = {token}",
            ct);
        await Outbox.WriteAsync(tx, "classes.student_rejoined", new StudentRejoined(classId, token), ClassesJson.Default.StudentRejoined, clock, ct);
        await tx.CommitAsync(ct);
    }

    private static IResult Answer(bool success, string message, Target target) => Results.Json(
        new Dictionary<string, object?>
        {
            ["success"] = success,
            ["message"] = message,
            ["classId"] = target.Id,
            ["className"] = target.Name,
        },
        ClassesJson.Answers.Answer);
}
