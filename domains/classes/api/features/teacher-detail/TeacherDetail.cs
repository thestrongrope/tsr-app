using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.TeacherDetail;

// Slice: GET /teachers/{token} -> a teacher's contact details, trained levels, classes (now and before) and training history. Contract: spec/api.yaml.
// PHP: routes/teachers.php route_teachers_detail (:80), TeachersModel::canView, teacherDetail and get. Guards: teachers:lookup (403), then canView: a teacher the caller may not see, or no such member, is 404 "Teacher not found".
// canView: lookup on the member's gender; a member with no gender 1 or 2 only for a caller holding the `all` scope; a gents member also for a caller who may look up gents teachers of ladies classes, when the member teaches
// or has a training record. Quirks copied: the `ended_on` of an attended class is the removal day (the query never selects the class's own end dates); `comments` falls back to the removal reason when the class has none.
// Deferred: PHP logs teacher.view_refused on a refusal.

internal static class TeacherDetailSlice
{
    private const int MaxRows = 5000;
    private static readonly string[] Levels = ["salman", "abuzar", "miqdad", "ammar", "bilal"];

    internal sealed record Member(int Token, string? Name, string? Email, string? Mobile, string? State, string? City, string? Country, string? Zip, string? Gender);

    internal sealed record Training(int Salman, int Abuzar, int Miqdad, int Ammar, int Bilal);

    internal sealed record Conducting(int Id, string Code, string? Level, string? City, string? Country, DateOnly? StartedOn, DateOnly? CreatedOn, DateOnly? CompletedOn,
        DateOnly? ShutdownOn, string? Comments, string Status);

    internal sealed record Attending(int Id, string Code, string? Level, string? City, string? Country, DateOnly? StartedOn, DateOnly? CreatedOn, string? Comments, int? Teacher,
        string? TeacherName, string Status, DateOnly? RemovedOn, string? RemovedReason, string? RemovedByName);

    internal sealed record Slot(int ClassId, int Day, int Hour, int Minute, string? Timezone);

    internal sealed record History(string? Comments, string? By, DateOnly? On);

    public static IEndpointRouteBuilder MapTeacherDetail(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/teachers/{token}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string token, HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "teachers:lookup", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var teacherToken = (int)Math.Clamp(PhpValue.IntOfText(token), int.MinValue, int.MaxValue);
        var member = await FindMemberAsync(db, teacherToken, ct);
        if (member is null || !await CanViewAsync(db, permissions, caller, member, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Teacher not found");
        }

        return Results.Json(await DetailAsync(db, member, ct));
    }

    private static async Task<Member?> FindMemberAsync(ClassesContext db, int token, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<Member>($"""
                select m.token as "Token", m.name as "Name", u.email as "Email", m.mobile as "Mobile", m.state as "State", m.city as "City", m.country as "Country",
                       m.zip as "Zip", m.gender as "Gender"
                from membership.v_members m join identity.v_users u on u.id = m.user_id
                where m.token = {token}
                order by m.user_id
                limit 1
                """)
            .ToListAsync(ct);
        return rows.Count == 0 ? null : rows[0];
    }

    private static async Task<bool> CanViewAsync(ClassesContext db, Permissions permissions, Caller caller, Member member, CancellationToken ct)
    {
        var gender = (int)PhpValue.IntOfText(member.Gender ?? string.Empty);
        if (gender is not (1 or 2))
        {
            return (await permissions.ReachAsync(caller, "teachers:lookup", ct)).All;
        }

        if (await permissions.CanAsync(caller, "teachers:lookup", AccessTarget.ForGender(gender), ct))
        {
            return true;
        }

        // Gents may teach ladies classes: whoever manages a ladies class may see a gents member, but only one who teaches.
        if (gender != 1 || !await permissions.CanAsync(caller, "teachers:lookup", AccessTarget.ForTeacherGender(1), ct))
        {
            return false;
        }

        var teaches = await db.Database
            .SqlQuery<int>($"""
                select 1 as "Value" where exists (select 1 from classes.teachers where token = {member.Token}) or exists (select 1 from classes.classes where teacher = {member.Token})
                """)
            .ToListAsync(ct);
        return teaches.Count > 0;
    }

    private static async Task<Dictionary<string, object?>> DetailAsync(ClassesContext db, Member m, CancellationToken ct)
    {
        var training = await db.Database
            .SqlQuery<Training>($"""
                select coalesce(salman, 0) as "Salman", coalesce(abuzar, 0) as "Abuzar", coalesce(miqdad, 0) as "Miqdad", coalesce(ammar, 0) as "Ammar", coalesce(bilal, 0) as "Bilal"
                from classes.teachers where token = {m.Token} limit 1
                """)
            .ToListAsync(ct);
        var flags = training.Count == 0 ? new Training(0, 0, 0, 0, 0) : training[0];

        var conducting = await ConductingAsync(db, m.Token, ct);
        var attending = await AttendingAsync(db, m.Token, ct);
        var slots = await SlotsAsync(db, conducting.Where(c => c.Status == "A").Select(c => c.Id).Concat(LiveIds(attending)).Distinct().ToArray(), ct);
        var history = await HistoryAsync(db, m.Token, ct);

        return new Dictionary<string, object?>
        {
            ["token"] = m.Token,
            ["name"] = m.Name ?? string.Empty,
            ["email"] = Empty(m.Email),
            ["mobile"] = Empty(m.Mobile),
            ["state"] = Empty(m.State),
            ["city"] = Empty(m.City),
            ["country"] = Empty(m.Country),
            ["zip"] = Empty(m.Zip),
            ["trained"] = training.Count > 0,
            ["flags"] = FlagsWire(flags),
            ["conducting"] = conducting.Where(c => c.Status == "A").Select(c => ConductingWire(c, slots[c.Id])).ToList(),
            ["conducted"] = conducting.Where(c => c.Status == "I").Select(c => ConductingWire(c, [])).ToList(),
            ["attending"] = attending.Where(IsLive).Select(a => AttendingWire(a, slots[a.Id], false)).ToList(),
            ["attended"] = attending.Where(a => !IsLive(a) && (a.Status == "I" || a.RemovedOn is not null)).Select(a => AttendingWire(a, [], true)).ToList(),
            ["history"] = history.Select(h => new Dictionary<string, object?>
            {
                ["comments"] = Text(Empty(h.Comments)),
                ["by"] = Empty(h.By),
                ["on"] = DateText(h.On),
            }).ToList(),
        };
    }

    private static bool IsLive(Attending a) => a.Status == "A" && a.RemovedOn is null;

    private static IEnumerable<int> LiveIds(List<Attending> attending) => attending.Where(IsLive).Select(a => a.Id);

    // The `trained` flag of PHP is "has a training record" (teachers.token set); the level flags read the five columns.
    private static Dictionary<string, object?> FlagsWire(Training t)
    {
        var values = new[] { t.Salman, t.Abuzar, t.Miqdad, t.Ammar, t.Bilal };
        var flags = new Dictionary<string, object?>();
        for (var i = 0; i < Levels.Length; i++)
        {
            flags[Levels[i]] = values[i] != 0;
        }

        return flags;
    }

    private static async Task<List<Conducting>> ConductingAsync(ClassesContext db, int token, CancellationToken ct) =>
        await db.Database
            .SqlQuery<Conducting>($"""
                select c.id as "Id", c.code as "Code", cl.name as "Level", c.city as "City", c.country as "Country", c.started_on as "StartedOn",
                       (c.created_at at time zone 'UTC')::date as "CreatedOn", c.completed_on as "CompletedOn", c.shutdown_on as "ShutdownOn", c.comments::text as "Comments", c.status as "Status"
                from classes.classes c join classes.class_levels cl on cl.id = c.class_level_id
                where c.teacher = {token}
                order by c.status, c.code, c.id
                limit {MaxRows}
                """)
            .ToListAsync(ct);

    private static async Task<List<Attending>> AttendingAsync(ClassesContext db, int token, CancellationToken ct) =>
        await db.Database
            .SqlQuery<Attending>($"""
                select c.id as "Id", c.code as "Code", cl.name as "Level", c.city as "City", c.country as "Country", c.started_on as "StartedOn",
                       (c.created_at at time zone 'UTC')::date as "CreatedOn", c.comments::text as "Comments", c.teacher as "Teacher", t.name as "TeacherName", c.status as "Status",
                       (cs.removed_at at time zone 'UTC')::date as "RemovedOn", cs.removed_reason::text as "RemovedReason", r.name as "RemovedByName"
                from classes.class_students cs
                join classes.classes c on c.id = cs.class_id
                join classes.class_levels cl on cl.id = c.class_level_id
                join membership.v_members t on t.token = c.teacher
                left join membership.v_members r on r.token = cs.removed_by
                where cs.token_no = {token}
                order by c.status, cl.sort_order, c.code, cs.id
                limit {MaxRows}
                """)
            .ToListAsync(ct);

    // PHP: ORDER BY day, hour, minute where each name is the select list's ALIAS (the day NAME, the padded hour and minute as text), so Saturday sorts before Tuesday.
    // The text is DAYNAME of 1970-09-2<day> (day 1 is a Monday), the hour and minute padded to two digits.
    private static async Task<ILookup<int, string>> SlotsAsync(ClassesContext db, int[] classIds, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<Slot>($"""
                select class_id as "ClassId", coalesce(day, 0) as "Day", coalesce(hour, 0) as "Hour", coalesce(minute, 0) as "Minute", timezone as "Timezone"
                from classes.class_schedules
                where class_id = any({classIds}) and deleted_at is null
                order by class_id, id
                limit {MaxRows}
                """)
            .ToListAsync(ct);
        return rows
            .OrderBy(s => s.ClassId)
            .ThenBy(s => DayName(s.Day), StringComparer.Ordinal)
            .ThenBy(s => Padded(s.Hour), StringComparer.Ordinal)
            .ThenBy(s => Padded(s.Minute), StringComparer.Ordinal)
            .ToLookup(s => s.ClassId, SlotText);
    }

    private static string Padded(int number) => number.ToString("00", CultureInfo.InvariantCulture);

    private static string DayName(int day) =>
        day is >= 1 and <= 7 ? CultureInfo.InvariantCulture.DateTimeFormat.GetDayName((DayOfWeek)(day % 7)) : string.Empty;

    private static string SlotText(Slot s) => string.Create(CultureInfo.InvariantCulture, $"{DayName(s.Day)} {Padded(s.Hour)}:{Padded(s.Minute)} {s.Timezone}");

    private static async Task<List<History>> HistoryAsync(ClassesContext db, int token, CancellationToken ct) =>
        await db.Database
            .SqlQuery<History>($"""
                select th.comments::text as "Comments", u.name as "By", (th.created_at at time zone 'UTC')::date as "On"
                from classes.teachers_history th join membership.v_members u on u.token = th.created_by
                where th.token = {token}
                order by th.created_at desc, th.id desc
                limit {MaxRows}
                """)
            .ToListAsync(ct);

    // api_teachers_class: every key is always present, schedules last.
    private static Dictionary<string, object?> ConductingWire(Conducting c, IEnumerable<string> schedules) => new()
    {
        ["id"] = c.Id,
        ["code"] = c.Code,
        ["level"] = c.Level ?? string.Empty,
        ["city"] = Empty(c.City),
        ["country"] = Empty(c.Country),
        ["startedOn"] = DateText(c.StartedOn ?? c.CreatedOn),
        ["endedOn"] = c.Status == "I" ? DateText(c.CompletedOn ?? c.ShutdownOn) : null,
        ["comments"] = c.Status == "I" ? Text(Empty(c.Comments)) : null,
        ["teacher"] = null,
        ["teacherToken"] = null,
        ["removedBy"] = null,
        ["schedules"] = schedules.ToList(),
    };

    private static Dictionary<string, object?> AttendingWire(Attending a, IEnumerable<string> schedules, bool attended) => new()
    {
        ["id"] = a.Id,
        ["code"] = a.Code,
        ["level"] = a.Level ?? string.Empty,
        ["city"] = Empty(a.City),
        ["country"] = Empty(a.Country),
        ["startedOn"] = DateText(a.StartedOn ?? a.CreatedOn),
        ["endedOn"] = attended ? DateText(a.RemovedOn) : null,
        ["comments"] = attended ? Text(Empty(a.Comments ?? a.RemovedReason)) : null,
        ["teacher"] = Empty(a.TeacherName),
        ["teacherToken"] = a.Teacher ?? 0,
        ["removedBy"] = attended ? Empty(a.RemovedByName) : null,
        ["schedules"] = schedules.ToList(),
    };

    private static string? DateText(DateOnly? date) => date?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    private static string? Empty(string? value) => string.IsNullOrEmpty(value) ? null : value;

    private static string? Text(string? value) => value is null ? null : PhpText.HtmlDecode(value);
}
