using System.Data.Common;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Membership.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminMemberEnrol;

// Slice: POST /admin/members/{token}/enrolments {classId} -> {saved: true, students, removedStudents, mcqStudents, transferHistory}: the super admin enrols a member, found by token, in one class and gets the class's roster
// back (domain/ClassRoster.cs, the roster of the manage screen). Order: members:enrol-by-token (403 "You do not have permission to do that"), the body (422 Invalid JSON), classId a JSON integer above 0 (422 "classId must
// be a class id"), the class active and complete (404 "Class not found"), students:enrol on it (403 "You do not have permission to change this class's students"), the admin audit row, then 30 enrolments an hour per caller
// (429, counted here: refusals and failures too). Then the answer by outcome: no such member 404 (the token is plain digits, else 0), two holders 422 code ambiguous_token, already in the class 409 code already_enrolled,
// a known gender other than the class's 422 code other_gender, the class no longer active 409 code class_inactive, a database failure 500 "Nothing was changed". Contract: spec/api.yaml.
// PHP: routes/member_enrol.php route_admin_member_enrol (:131), ClassStudentsModel::enrolByToken. In one transaction whose first statement locks the member (an advisory lock on their token, five seconds), the class is
// read again; a member with a removed (or not active) row of this class gets the LATEST such row back (status A, removal cleared, joined today, mcq_admin 0, added_by the caller) and otherwise a new row is written after
// membership's accepted-registration command (a member with no class request gets one). A member of unknown gender may join any class. If the roster cannot be built after the commit the answer is 200 {saved: true,
// roster: null}. Events: classes.student_enrolled (source by_token) for a new row, classes.student_restored for a restored one (outbox, same transaction). PHP's search touch is not sent.

internal static partial class AdminMemberEnrolSlice
{
    private const int LockClass = 7_200_001;

    internal sealed record MemberEnrolRestored(int ClassId, int Token, int RestoredBy);

    internal sealed record Outcome(bool Saved, object? Roster);

    private enum Answer
    {
        Enrolled,
        Restored,
        AlreadyEnrolled,
        OtherGender,
        NotFound,
        Ambiguous,
        ClassInactive,
    }

    private sealed record ClassRow(int? Gender, string Status);

    [LoggerMessage(Level = LogLevel.Error, Message = "member_enrol.failed class={ClassId}")]
    private static partial void LogFailed(ILogger logger, Exception exception, int classId);

    [LoggerMessage(Level = LogLevel.Error, Message = "member_enrol.roster_failed class={ClassId}")]
    private static partial void LogRosterFailed(ILogger logger, Exception exception, int classId);

    public static IEndpointRouteBuilder MapAdminMemberEnrol(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/members/{token}/enrolments", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string token,
        HttpContext context,
        NpgsqlDataSource source,
        Permissions permissions,
        MemberRateLimit limit,
        TimeProvider clock,
        ILogger<ClassesLog> log,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "members:enrol-by-token", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        if (!PhpValue.IsInt(body!.Get("classId"), out var classId) || classId <= 0)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "classId must be a class id");
        }

        var head = await ClassGuards.FindActiveClassAsync(source, classId, ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "students:enrol", AccessTarget.ForClass(head.Id), ct))
        {
            return Refusals.NotPermittedToChangeStudents();
        }

        await ClassGuards.LogAdminAccessAsync(context, permissions, caller, ct);
        if (!limit.Allow("member_enrol", caller.Token, 30, 3600))
        {
            return Problem.Detail(StatusCodes.Status429TooManyRequests, MemberLookup.Throttled);
        }

        Answer answer;
        try
        {
            answer = await EnrolAsync(source, clock, head.Id, MemberLookup.TokenOf(token), caller.Token, ct);
        }
        catch (Exception e) when (e is DbException or InvalidOperationException)
        {
            LogFailed(log, e, head.Id);
            return Problem.Detail(StatusCodes.Status500InternalServerError, "Nothing was changed");
        }

        return answer switch
        {
            Answer.NotFound => MemberLookup.NotFoundAnswer(),
            Answer.Ambiguous => MemberLookup.AmbiguousAnswer(),
            Answer.AlreadyEnrolled => MemberLookup.Refusal(StatusCodes.Status409Conflict, "This member is already in this class", "already_enrolled"),
            Answer.OtherGender => MemberLookup.Refusal(StatusCodes.Status422UnprocessableEntity, "This class is for the other gender", "other_gender"),
            Answer.ClassInactive => MemberLookup.Refusal(StatusCodes.Status409Conflict, "This class is not active", "class_inactive"),
            _ => await SavedAsync(source, permissions, caller, head.Id, log, ct),
        };
    }

    // The enrolment is committed, so the answer is a success even when the roster cannot be built.
    private static async Task<IResult> SavedAsync(NpgsqlDataSource source, Permissions permissions, Caller caller, int classId, ILogger<ClassesLog> log, CancellationToken ct)
    {
        try
        {
            var roster = await ClassRoster.BuildAsync(source, permissions, caller, classId, ct);
            var answer = new Dictionary<string, object?> { ["saved"] = true };
            foreach (var entry in roster)
            {
                answer[entry.Key] = entry.Value;
            }

            return Results.Json(answer, ClassesJson.Answers.Answer);
        }
        catch (DbException e)
        {
            LogRosterFailed(log, e, classId);
            return Results.Json(new Outcome(true, null), ClassesJson.Answers.MemberEnrolOutcome);
        }
    }

    private static async Task<Answer> EnrolAsync(NpgsqlDataSource source, TimeProvider clock, int classId, int token, int by, CancellationToken ct)
    {
        await using (var read = await source.BeginAsync(ct))
        {
            var first = await ReadClassAsync(read, classId, ct);
            if (first.Status != "A")
            {
                return Answer.ClassInactive;
            }

            var holders = await MemberLookup.HoldersAsync(read, token, ct);
            if (holders != 1)
            {
                return holders == 0 ? Answer.NotFound : Answer.Ambiguous;
            }
        }

        await using var tx = await source.BeginAsync(ct);
        await tx.ExecuteAsync($"set local lock_timeout = '5s'", ct);
        await tx.ExecuteAsync($"select pg_advisory_xact_lock({LockClass}, {token})", ct);
        var current = await ReadClassAsync(tx, classId, ct);
        if (current.Status != "A")
        {
            return Answer.ClassInactive;
        }

        var member = await MemberLookup.RowAsync(tx, token, ct);
        if (member is null)
        {
            return Answer.NotFound;
        }

        if (await IsEnrolledAsync(tx, classId, token, ct))
        {
            return Answer.AlreadyEnrolled;
        }

        var memberGender = EnrolmentRules.GenderOf(member.Gender);
        if (memberGender is not null && memberGender != (current.Gender ?? 0))
        {
            return Answer.OtherGender;
        }

        var restored = await RestoreLatestAsync(tx, classId, token, by, ct);
        if (restored)
        {
            await Outbox.WriteAsync(tx, "classes.student_restored", new MemberEnrolRestored(classId, token, by), ClassesJson.Default.MemberEnrolRestored, clock, ct);
        }
        else
        {
            await MembershipCommands.RecordAcceptedRegistrationAsync(tx, token, classId, ct);
            await tx.ExecuteAsync(
                $"insert into classes.class_students (class_id, token_no, joined_on, added_by) values ({classId}, {token}, (now() at time zone 'UTC')::date, {by})", ct);
            await Outbox.WriteAsync(tx, "classes.student_enrolled", new StudentEnrolled(classId, token, by, "by_token"), ClassesJson.Default.StudentEnrolled, clock, ct);
        }

        await tx.CommitAsync(ct);
        return restored ? Answer.Restored : Answer.Enrolled;
    }

    private static async Task<ClassRow> ReadClassAsync(DbTx tx, int classId, CancellationToken ct) =>
        (await tx.ListAsync(
            $"""select gender as "Gender", status as "Status" from classes.classes where id = {classId}""",
            row => new ClassRow(row.IntOrNull("Gender"), row.Text("Status")),
            ct))
            .FirstOrDefault() ?? throw new InvalidOperationException("The class was removed while it was being enrolled in");

    // PHP isEnrolledStudent: an active row (status A, not removed) of the member in the class.
    private static async Task<bool> IsEnrolledAsync(DbTx tx, int classId, int token, CancellationToken ct) =>
        await tx.AnyAsync($"""select 1 as "Value" from classes.class_students where class_id = {classId} and token_no = {token} and status = 'A' and removed_at is null limit 1""", ct);

    // PHP restoreLatestRemoved: the latest removed (or not active) row of the member in the class comes back, as restoreStudent and a rejoin do for the join date and mcq_admin.
    private static async Task<bool> RestoreLatestAsync(DbTx tx, int classId, int token, int by, CancellationToken ct)
    {
        var ids = await tx.ListAsync(
            $"""
                select id as "Value" from classes.class_students
                where class_id = {classId} and token_no = {token} and (removed_at is not null or status <> 'A')
                order by id desc limit 1
                """,
            row => row.Int("Value"),
            ct);
        if (ids.Count == 0)
        {
            return false;
        }

        await tx.ExecuteAsync(
            $"""
            update classes.class_students
            set status = 'A', removed_at = null, removed_by = null, removed_reason = null, joined_on = (now() at time zone 'UTC')::date, mcq_admin = 0, added_by = {by}
            where id = {ids[0]}
            """,
            ct);
        return true;
    }
}
