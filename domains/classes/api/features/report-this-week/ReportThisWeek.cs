using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportThisWeek;

// Slice: GET /reports/this-week?gender -> {gender, week{from, to}, summary{met, of, formsMissing, attendance, flagged}, stages{cform, conduction, attendance, alignment, met, attended}}: the class coordinator's review of the last
// completed week (a row per class and stage: teacher, teacher mobile where the caller may see it, detail, action message or call, quiet subjects). Contract: spec/api.yaml.
// PHP: routes/this_week.php route_reports_this_week (:22), thisweek.php report and assemble (the rules are ThisWeekRules), mis.php weeklyReport, weekAttendance, subjectsTaughtOnDays, lastCompletedWeek. Scope: the gender and
// reports:read as every report (ReportScope), the classes of weekly (the reach and, for an assigned-only classes:read, the assigned classes) for the rows, the plain reach for the subjects taught (as PHP).
// Queries: the class ids of the scope, the classes, the sessions of the nine weeks (one per class and day), the subjects taught, the attendance of the week, the teachers' gender and mobile.
// Copied: the review window is the last completed week (the week of today minus seven days, cut at New Year as calendar_table is) and the eight weeks before it; a class's start is its own started_on, else its creation day;
// the teacher's mobile is shown only for a teacher TeachersModel::canView allows (teachers:lookup, decided per gender: every listed teacher teaches); the attendance average and percent round half away from zero.
// Deviation: at most 100000 session rows and 50000 subject rows (PHP has no bound).

internal static class ReportThisWeekSlice
{
    private const int Weeks = 9;
    private const int MaxRows = 100000;

    internal sealed record WeekItem(string From, string To);

    internal sealed record Answer(int Gender, WeekItem Week, ThisWeekRules.Summary Summary, ThisWeekRules.Stages Stages);

    private sealed record ClassRow(int Id, string Code, string Level, string? Teacher, int? TeacherToken, DateOnly StartedOn);

    private sealed record TaughtRow(int ClassId, DateOnly ConductedOn, bool Arabic, bool Aqaed, bool Ahkam, bool Akhlaq);

    private sealed record AttendanceRow(int ClassId, long Present, long Marked);

    private sealed record TeacherRow(int Token, string? Gender, string? Mobile, string? Country);

    public static IEndpointRouteBuilder MapReportThisWeek(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/this-week", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (scope, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var (year, number) = ReportCalendar.LastCompleted(today);
        var last = ReportCalendar.Range(year, number);
        if (last is null)
        {
            return Results.Json(new Answer(scope!.Gender, new WeekItem(string.Empty, string.Empty), new ThisWeekRules.Summary(0, 0, 0, null, 0), Empty()), ClassesJson.Answers.ReportThisWeek);
        }

        var scopeIds = await scope!.ClassIdsAsync(db, 0, ct);
        var ids = await ReportScope.KeepAssignedAsync(scopeIds, permissions, caller, ct);
        var (start, end) = ReportCalendar.Window(Month(last.Value.Min.AddDays(-7 * (Weeks - 1))), Month(last.Value.Max), today);
        var months = WeeklyGrid.Months(start, end);
        var weeks = ThisWeekRules.RecentWeeks(months, last.Value.Max, Weeks);

        var classes = await ClassesAsync(db, ids, ct);
        var conducted = await WeeklySessions.ByClassAndDayAsync(db, ids, start, end, ct);
        var flags = weeks.Count == 0 ? [] : ThisWeekRules.TaughtFlags(await TaughtAsync(db, scopeIds, weeks[0].Start, last.Value.Max, ct), weeks);
        var attendance = await AttendanceAsync(db, ids, last.Value.Min, last.Value.Max, ct);
        var mobiles = await MobilesAsync(db, permissions, caller, classes, ct);

        var allWeeks = months.SelectMany(m => m.Weeks).ToList();
        var inputs = classes.Select(c => ToInput(c, conducted.GetValueOrDefault(c.Id) ?? [], allWeeks, weeks, flags, mobiles)).ToList();
        var screen = ThisWeekRules.Assemble([.. weeks.Select(w => w.Start)], inputs, attendance);
        return Results.Json(new Answer(scope.Gender, new WeekItem(Day(last.Value.Min), Day(last.Value.Max)), screen.Summary, screen.Stages), ClassesJson.Answers.ReportThisWeek);
    }

    private static ThisWeekRules.Stages Empty() => new([], [], [], [], [], []);

    private static string Month(DateOnly day) => day.ToString("MM-yyyy", CultureInfo.InvariantCulture);

    private static string Day(DateOnly day) => day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    private static ThisWeekRules.ClassInput ToInput(
        ClassRow c, Dictionary<DateOnly, int> conducted, List<IReadOnlyList<DateOnly>> allWeeks, IReadOnlyList<ThisWeekRules.WeekRef> weeks, Dictionary<int, Dictionary<string, bool[]>> flags,
        Dictionary<int, string> mobiles)
    {
        var cells = weeks.Select(w => WeeklyGrid.CellOf(conducted, allWeeks[w.Position])).ToList();
        var mobile = c.TeacherToken is { } token ? mobiles.GetValueOrDefault(token) : null;
        return new ThisWeekRules.ClassInput(
            c.Id, c.Code, c.Level, PhpCast.StrOrNull(c.Teacher), c.TeacherToken, PhpCast.StrOrNull(mobile), c.StartedOn, cells,
            flags.TryGetValue(c.Id, out var subjects) ? subjects.ToDictionary(p => p.Key, p => p.Value) : new Dictionary<string, bool[]>());
    }

    // PHP getAll: the level must exist (inner join), the teacher's name may be missing; order gender, level order, id.
    private static async Task<List<ClassRow>> ClassesAsync(NpgsqlDataSource db, int[] ids, CancellationToken ct) =>
        await db.ListAsync(
            $"""
                select c.id as "Id", c.code::text as "Code", cl.name::text as "Level", u.name::text as "Teacher", c.teacher as "TeacherToken",
                       coalesce(c.started_on, (c.created_at at time zone 'UTC')::date) as "StartedOn"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members u on u.token = c.teacher
                where c.id = any({ids})
                order by c.gender, cl.sort_order, c.id
                """,
            r => new ClassRow(r.Int("Id"), r.Text("Code"), r.Text("Level"), r.TextOrNull("Teacher"), r.IntOrNull("TeacherToken"), r.Date("StartedOn")),
            ct);

    // PHP subjectsTaughtOnDays: the held sessions of the window with the subjects taught (flag '1' or 'Y').
    private static async Task<List<(int ClassId, DateOnly On, IReadOnlySet<string> Subjects)>> TaughtAsync(NpgsqlDataSource db, int[] ids, DateOnly from, DateOnly to, CancellationToken ct)
    {
        var rows = await db.ListAsync(
            $"""
                select s.class_id as "ClassId", s.conducted_on as "ConductedOn", s.arabic_conducted in ('1', 'Y') as "Arabic", s.aqaed_conducted in ('1', 'Y') as "Aqaed",
                       s.ahkam_conducted in ('1', 'Y') as "Ahkam", s.akhlaq_conducted in ('1', 'Y') as "Akhlaq"
                from classes.class_sessions s
                where s.conducted_on >= {from} and s.conducted_on <= {to} and s.conducted = 1 and s.class_id = any({ids})
                limit {MaxRows}
                """,
            r => new TaughtRow(r.Int("ClassId"), r.Date("ConductedOn"), r.Bool("Arabic"), r.Bool("Aqaed"), r.Bool("Ahkam"), r.Bool("Akhlaq")),
            ct);
        return [.. rows.Select(r => (r.ClassId, r.ConductedOn, (IReadOnlySet<string>)Taught(r)))];
    }

    private static HashSet<string> Taught(TaughtRow row)
    {
        var taught = new HashSet<string>();
        foreach (var (subject, flag) in new[] { ("arabic", row.Arabic), ("aqaed", row.Aqaed), ("ahkam", row.Ahkam), ("akhlaq", row.Akhlaq) })
        {
            if (flag)
            {
                taught.Add(subject);
            }
        }

        return taught;
    }

    // PHP weekAttendance: present over marked of the sessions held in the week; a class with nothing marked is left out.
    private static async Task<Dictionary<int, double>> AttendanceAsync(NpgsqlDataSource db, int[] ids, DateOnly from, DateOnly to, CancellationToken ct)
    {
        var rows = await db.ListAsync(
            $"""
                select s.class_id as "ClassId", coalesce(sum(a.present), 0)::bigint as "Present", count(a.session_id) as "Marked"
                from classes.class_attendance a
                join classes.class_sessions s on s.id = a.session_id
                where s.conducted = 1 and s.conducted_on >= {from} and s.conducted_on <= {to} and s.class_id = any({ids})
                group by s.class_id
                """,
            r => new AttendanceRow(r.Int("ClassId"), r.Long("Present"), r.Long("Marked")),
            ct);
        return rows.Where(r => r.Marked > 0).ToDictionary(r => r.ClassId, r => (double)r.Present / r.Marked);
    }

    // PHP teacherMobiles: a teacher's mobile only where TeachersModel::canView allows; the decision depends on the teacher's gender alone (every listed teacher teaches a class).
    private static async Task<Dictionary<int, string>> MobilesAsync(NpgsqlDataSource db, Permissions permissions, Caller caller, List<ClassRow> classes, CancellationToken ct)
    {
        var tokens = classes.Where(c => c.TeacherToken is not null).Select(c => c.TeacherToken!.Value).Distinct().ToArray();
        if (tokens.Length == 0 || !await permissions.CanAsync(caller, "teachers:lookup", AccessTarget.None, ct))
        {
            return [];
        }

        var rows = await db.ListAsync(
            $"""
                select m.token as "Token", m.gender::text as "Gender", m.mobile::text as "Mobile", m.country::text as "Country" from membership.v_members m
                where m.token = any({tokens}) order by m.user_id
                """,
            r => new TeacherRow(r.Int("Token"), r.TextOrNull("Gender"), r.TextOrNull("Mobile"), r.TextOrNull("Country")),
            ct);
        var genders = new Dictionary<int, int>();
        foreach (var row in rows)
        {
            genders.TryAdd(row.Token, (int)PhpValue.IntOfText(row.Gender ?? string.Empty));
        }

        var visible = new Dictionary<int, bool>();
        var mobiles = new Dictionary<int, string>();
        foreach (var token in tokens)
        {
            var gender = genders.GetValueOrDefault(token);
            if (!visible.TryGetValue(gender, out var ok))
            {
                ok = await TeacherView.CanViewAsync(permissions, caller, gender, () => Task.FromResult(true), ct);
                visible[gender] = ok;
            }

            if (!ok)
            {
                continue;
            }

            // In full, with the teacher's own country code; one that cannot be completed is left out, as a teacher with no number is.
            var mobile = rows.Where(r => r.Token == token).Select(r => DialableNumber.Of(r.Mobile, r.Country)).LastOrDefault(number => number.Length > 0);
            if (mobile is not null)
            {
                mobiles[token] = mobile;
            }
        }

        return mobiles;
    }
}
