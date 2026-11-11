using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportTsr;

// Slice: GET /reports/tsr?gender&from&to (days YYYY-MM-DD, default the last 14 days) -> {gender, from, to, conduction, mcq, attendance, recitation}, each with `levels` (one row per level) and `classes` (one row per class): the share of classes that held a
// session or set an MCQ, the last day of each, their attendance and their Quran recitation. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_tsr (:611, api_require_tsr_report :584), mis.php tsrSummaryReport (:1397) and its eight queries (getSummaryConduction, getConductionReport, getSummaryMCQs, getMCQReport, attendanceSummary,
// getAttendanceReport, recitationSummary, getQuranRecitationSummary). Queries: the class ids of the scope three times (the asked gender; every gender for the level rows; the asked gender with closed classes for the recitation list), the level rows, the class rows, the recitation rows: 6.
// Copied: the LEVEL rows are not narrowed to the asked gender in SQL (every gender of the caller's reach is counted, a level shows when any class of it is in reach, and the `gents_*` or `ladies_*` figures are picked); a level's recitation row exists
// only when the level has an attendance mark in the range; the class lists inner join the teacher and the gender (the level rows do not); the MCQ day is a time: a quiz published after midnight of the `to` day is not in the range, and `lastConducted`
// of the MCQ list is the time of the latest publish; a class's attendance is present over marks of its held sessions (four decimals) and a level's is the average of those (marks of classes with none are not averaged); the recitation CLASS list has no
// status condition in PHP, so a closed class with recitation appears there (for a caller whose reach is all or a gender; a class assigned by a rule is active only); it has no order in PHP, here by class id.
// Deviation: ties in the other lists (PHP leaves them to the database) go by class code.

internal static class ReportTsrSlice
{
    private const int DefaultDays = 14;

    internal sealed record CountsLevel(int LevelId, string Level, int Conducted, int Total, PhpFloat Percent);

    internal sealed record LastClass(string Level, string Class, string? Teacher, string? LastConducted);

    internal sealed record PercentLevel(int LevelId, string Level, int Percent);

    internal sealed record PercentClass(string Level, string Class, string? Teacher, int Percent);

    internal sealed record TotalLevel(int LevelId, string Level, int Total);

    internal sealed record TotalClass(string Level, string Class, string? Teacher, int Total);

    internal sealed record Counts(IReadOnlyList<CountsLevel> Levels, IReadOnlyList<LastClass> Classes);

    internal sealed record Percents(IReadOnlyList<PercentLevel> Levels, IReadOnlyList<PercentClass> Classes);

    internal sealed record Totals(IReadOnlyList<TotalLevel> Levels, IReadOnlyList<TotalClass> Classes);

    internal sealed record Answer(int Gender, string From, string To, Counts Conduction, Counts Mcq, Percents Attendance, Totals Recitation);

    private sealed record LevelRow(
        int Id, string Code, int GentsTotal, int GentsHeld, int GentsQuiz, int LadiesTotal, int LadiesHeld, int LadiesQuiz,
        decimal GentsPerSum, int GentsPerN, decimal LadiesPerSum, int LadiesPerN, int Marks, long GentsRecitation, long LadiesRecitation);

    private sealed record ClassRow(string Level, string Code, string? Teacher, DateOnly? LastConducted, DateTimeOffset? LastPublished, decimal? Per);

    private sealed record RecitationRow(string Level, string Code, string? Teacher, long Total);

    public static IEndpointRouteBuilder MapReportTsr(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/tsr", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
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
        var (range, invalid) = ReportDates.Check(ReportMonths.Param(context, "from"), ReportMonths.Param(context, "to"), today, DefaultDays);
        if (invalid is not null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, invalid);
        }

        var genderIds = await scope!.ClassIdsAsync(db, 0, ct);
        var allGenderIds = await (scope with { Gender = 0 }).ClassIdsAsync(db, 0, ct);
        var recitationIds = await scope.ClassIdsAsync(db, 0, ct, anyStatus: true);
        var levels = await LevelsAsync(db, allGenderIds, range!, ct);
        var classes = await ClassesAsync(db, genderIds, range!, ct);
        var recitation = await RecitationAsync(db, recitationIds, range!, ct);
        return Results.Json(Build(scope.Gender, range!, levels, classes, recitation));
    }

    private static Answer Build(int gender, DateRange range, List<LevelRow> levels, List<ClassRow> classes, List<RecitationRow> recitation)
    {
        var gents = gender == 1;
        var conduction = new Counts(
            [.. levels.Select(l => Count(l, gents ? l.GentsHeld : l.LadiesHeld, gents))],
            [.. TsrRules.NewestFirst(classes, c => Day(c.LastConducted), c => c.Code).Select(c => new LastClass(c.Level, c.Code, PhpCast.StrOrNull(c.Teacher), Day(c.LastConducted)))]);
        var mcq = new Counts(
            [.. levels.Select(l => Count(l, gents ? l.GentsQuiz : l.LadiesQuiz, gents))],
            [.. TsrRules.NewestFirst(classes, c => Time(c.LastPublished), c => c.Code).Select(c => new LastClass(c.Level, c.Code, PhpCast.StrOrNull(c.Teacher), Time(c.LastPublished)))]);
        var attendance = new Percents(
            [.. levels.Select(l => new PercentLevel(l.Id, l.Code, gents ? TsrRules.LevelAttendance(l.GentsPerSum, l.GentsPerN) : TsrRules.LevelAttendance(l.LadiesPerSum, l.LadiesPerN)))],
            [.. TsrRules.HighestFirst(classes, c => c.Per, c => c.Code).Select(c => new PercentClass(c.Level, c.Code, PhpCast.StrOrNull(c.Teacher), ReportFigures.WholePercent(c.Per)))]);
        var recited = new Totals(
            [.. levels.Where(l => l.Marks > 0).Select(l => new TotalLevel(l.Id, l.Code, (int)(gents ? l.GentsRecitation : l.LadiesRecitation)))],
            [.. recitation.Select(r => new TotalClass(r.Level, r.Code, PhpCast.StrOrNull(r.Teacher), (int)r.Total))]);
        return new Answer(gender, range.From, range.To, conduction, mcq, attendance, recited);
    }

    private static CountsLevel Count(LevelRow level, int conducted, bool gents)
    {
        var total = gents ? level.GentsTotal : level.LadiesTotal;
        return new CountsLevel(level.Id, level.Code, conducted, total, TsrRules.Percent(conducted, total));
    }

    private static string? Day(DateOnly? day) => day?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    private static string? Time(DateTimeOffset? time) => time?.UtcDateTime.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);

    // PHP getSummaryConduction, getSummaryMCQs, attendanceSummary and recitationSummary in one pass over the classes of the caller's reach (every gender): per class whether it held a session and set an MCQ in the range and its marks, then per level.
    private static async Task<List<LevelRow>> LevelsAsync(ClassesContext db, int[] ids, DateRange range, CancellationToken ct)
    {
        var from = range.FromDay;
        var to = range.ToDay;
        var fromTime = range.FromDay.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var toTime = range.ToDay.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        return await db.Database
            .SqlQuery<LevelRow>($"""
                with pc as (
                    select c.id, c.class_level_id, c.gender,
                           exists (select 1 from classes.class_sessions s where s.class_id = c.id and s.conducted = 1 and s.conducted_on between {from} and {to}) as held,
                           exists (select 1 from assessment.v_quizzes q where q.class_id = c.id and q.published_at between {fromTime} and {toTime}) as quiz,
                           a.marks, a.present, a.recitation
                    from classes.classes c
                    left join lateral (
                        select count(*) as marks, coalesce(sum(ca.present), 0) as present, coalesce(sum(ca.recitation), 0) as recitation
                        from classes.class_sessions s
                        join classes.class_attendance ca on ca.session_id = s.id
                        where s.class_id = c.id and s.conducted = 1 and s.conducted_on between {from} and {to}) a on true
                    where c.id = any({ids}))
                select cl.id as "Id", cl.code::text as "Code",
                       (count(*) filter (where pc.gender = 1))::int as "GentsTotal", (count(*) filter (where pc.gender = 1 and pc.held))::int as "GentsHeld", (count(*) filter (where pc.gender = 1 and pc.quiz))::int as "GentsQuiz",
                       (count(*) filter (where pc.gender = 2))::int as "LadiesTotal", (count(*) filter (where pc.gender = 2 and pc.held))::int as "LadiesHeld", (count(*) filter (where pc.gender = 2 and pc.quiz))::int as "LadiesQuiz",
                       coalesce(sum(round(pc.present::numeric / pc.marks, 4)) filter (where pc.gender = 1 and pc.marks > 0), 0) as "GentsPerSum", (count(*) filter (where pc.gender = 1 and pc.marks > 0))::int as "GentsPerN",
                       coalesce(sum(round(pc.present::numeric / pc.marks, 4)) filter (where pc.gender = 2 and pc.marks > 0), 0) as "LadiesPerSum", (count(*) filter (where pc.gender = 2 and pc.marks > 0))::int as "LadiesPerN",
                       coalesce(sum(pc.marks), 0)::int as "Marks",
                       coalesce(sum(pc.recitation) filter (where pc.gender = 1), 0)::bigint as "GentsRecitation", coalesce(sum(pc.recitation) filter (where pc.gender = 2), 0)::bigint as "LadiesRecitation"
                from pc
                join classes.class_levels cl on cl.id = pc.class_level_id
                group by cl.id, cl.code, cl.sort_order
                order by cl.sort_order, cl.id
                """)
            .ToListAsync(ct);
    }

    // PHP getConductionReport, getMCQReport and getAttendanceReport: per class of the asked gender (level, teacher and gender must exist), its last held day, its last publish time in the range and its attendance quotient.
    private static async Task<List<ClassRow>> ClassesAsync(ClassesContext db, int[] ids, DateRange range, CancellationToken ct)
    {
        var from = range.FromDay;
        var to = range.ToDay;
        var fromTime = range.FromDay.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var toTime = range.ToDay.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        return await db.Database
            .SqlQuery<ClassRow>($"""
                select cl.code::text as "Level", c.code::text as "Code", u.name::text as "Teacher",
                       (select max(s.conducted_on) from classes.class_sessions s where s.class_id = c.id and s.conducted = 1 and s.conducted_on between {from} and {to}) as "LastConducted",
                       (select max(q.published_at) from assessment.v_quizzes q where q.class_id = c.id and q.published_at between {fromTime} and {toTime}) as "LastPublished",
                       case when a.marks > 0 then round(a.present::numeric / a.marks, 4) end as "Per"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                join platform.v_genders g on g.id = c.gender
                join membership.v_members u on u.token = c.teacher
                left join lateral (
                    select count(*) as marks, coalesce(sum(ca.present), 0) as present
                    from classes.class_sessions s
                    join classes.class_attendance ca on ca.session_id = s.id
                    where s.class_id = c.id and s.conducted = 1 and s.conducted_on between {from} and {to}) a on true
                where c.id = any({ids})
                """)
            .ToListAsync(ct);
    }

    // PHP getQuranRecitationSummary: the recitation marked in the held sessions of the range, per class (no status condition in PHP: the ids may hold a closed class).
    private static async Task<List<RecitationRow>> RecitationAsync(ClassesContext db, int[] ids, DateRange range, CancellationToken ct)
    {
        var from = range.FromDay;
        var to = range.ToDay;
        return await db.Database
            .SqlQuery<RecitationRow>($"""
                select cl.code::text as "Level", c.code::text as "Code", u.name::text as "Teacher", coalesce(sum(ca.recitation), 0)::bigint as "Total"
                from classes.class_attendance ca
                join classes.class_sessions s on s.id = ca.session_id
                join classes.classes c on c.id = s.class_id
                join classes.class_levels cl on cl.id = c.class_level_id
                join membership.v_members u on u.token = c.teacher
                join platform.v_genders g on g.id = c.gender
                where s.conducted = 1 and s.conducted_on between {from} and {to} and c.id = any({ids})
                group by c.id, cl.code, c.code, u.name
                order by c.id
                limit 20000
                """)
            .ToListAsync(ct);
    }
}
