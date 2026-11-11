using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportSummary;

// Slice: GET /reports/summary?gender&from&to&level (months MM-YYYY) -> per class, over the months: sessions expected (schedule slots in the weeks that are over), held, not filled, not held, averages and the subjects taught.
// PHP: routes/reports.php route_reports_summary (:407, api_require_summary_report :380), mis.php summary (:917) and summaryReport. Queries: the class ids of the scope, one for the figures (PHP: one, with three derived tables).
// Copied: only classes with a schedule slot in a finished week appear (inner join on the expected slots); the expected slots are counted from 2021-11-01 on; no 12-month limit (PHP has none here);
// "from" is required: PHP's default (three months back) is built with strtotime('first day of this'), which is false, so a request with no "from" is always 422 "from and to must be months".
// MariaDB to PostgreSQL: dayofweek(d) is extract(dow) + 1 and is compared with class_schedules.day as it is; least(now(), date) is a comparison of days; every ratio is rounded to four decimals as MariaDB does (SummaryFigures).

internal static class ReportSummarySlice
{
    private static readonly DateOnly SchoolStart = new(2021, 11, 1);

    internal sealed record Subject(int Count, int Percent);

    internal sealed record Subjects(Subject Arabic, Subject Aqaed, Subject Ahkam, Subject Akhlaq, Subject Other);

    internal sealed record ClassItem(
        int ClassId, string Level, string Class, string? Teacher, int Expected, int Conducted, int NotFilled, int NotConducted, int AvgStudents, int AvgDuration,
        int PercentNotFilled, int PercentConduction, int PercentAttendance, Subjects? Subjects);

    internal sealed record Answer(int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<ClassItem> Classes);

    private sealed record Row(
        int Id, string Level, string Class, string? Teacher, int Expected, int Submitted, int Conducted, long Attended, long Marked, int DurationCount, long Duration,
        int Arabic, int Aqaed, int Ahkam, int Akhlaq, int Other);

    public static IEndpointRouteBuilder MapReportSummary(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/summary", HandleAsync).RequireMember(createsMember: true);
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
        var from = ReportMonths.Param(context, "from") ?? string.Empty;
        var to = ReportMonths.Param(context, "to") ?? today.ToString("MM-yyyy", CultureInfo.InvariantCulture);
        var invalid = ReportMonths.Check(from, to, limitToTwelve: false);
        if (invalid is not null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, invalid);
        }

        var (start, end) = ReportCalendar.Window(from, to, today);
        List<Row> rows = [];
        if (start <= end)
        {
            var ids = await scope!.ClassIdsAsync(db, 0, ct);
            var weeks = ReportCalendar.Weeks(start > SchoolStart ? start : SchoolStart, end < today ? end : today);
            rows = await RowsAsync(db, ids, weeks, start, end, today, ct);
        }

        var level = ReportScope.LevelOf(context);
        var classes = rows.Where(r => level.Length == 0 || r.Level == level).Select(ToItem).ToList();
        return Results.Json(new Answer(scope!.Gender, from, to, [.. rows.Select(r => r.Level).Distinct()], classes));
    }

    private static ClassItem ToItem(Row row)
    {
        var f = SummaryFigures.Of(new SummaryFigures.Sums(
            row.Expected, row.Submitted, row.Conducted, row.Attended, row.Marked, row.DurationCount, row.Duration, row.Arabic, row.Aqaed, row.Ahkam, row.Akhlaq, row.Other));
        var subjects = f.Arabic + f.Aqaed + f.Ahkam + f.Akhlaq + f.Other > 0
            ? new Subjects(new Subject(f.Arabic, f.PercentArabic), new Subject(f.Aqaed, f.PercentAqaed), new Subject(f.Ahkam, f.PercentAhkam), new Subject(f.Akhlaq, f.PercentAkhlaq), new Subject(f.Other, f.PercentOther))
            : null;
        return new ClassItem(
            row.Id, row.Level, row.Class, PhpCast.StrOrNull(row.Teacher), f.Expected, f.Conducted, f.NotFilled, f.NotConducted, f.AvgStudents, f.AvgDuration,
            f.PercentNotFilled, f.PercentConduction, f.PercentAttendance, subjects);
    }

    // `e`: each class's schedule slots in the finished weeks of the window (a week counts when it lies inside the class's own start and end and is over); `a`: its sessions of the window;
    // `t`: the attendance marks of its held sessions. The class must have slots (inner join), the others are left joins.
    private static async Task<List<Row>> RowsAsync(ClassesContext db, int[] ids, IReadOnlyList<ReportCalendar.Week> weeks, DateOnly start, DateOnly end, DateOnly today, CancellationToken ct)
    {
        var mins = weeks.Select(w => w.Min).ToArray();
        var maxs = weeks.Select(w => w.Max).ToArray();
        var schoolStart = SchoolStart;
        return await db.Database
            .SqlQuery<Row>($"""
                with wk as (select min_dt, max_dt from unnest({mins}, {maxs}) as w(min_dt, max_dt)),
                e as (
                    select c.id, count(cs.id)::int as expected
                    from classes.classes c
                    join classes.class_schedules cs on cs.class_id = c.id and cs.deleted_at is null
                    join wk on wk.min_dt >= greatest(coalesce(c.started_on, {schoolStart}), {start})
                           and wk.max_dt <= least({today}, coalesce(c.shutdown_on, {today}), coalesce(c.completed_on, {today}), {end})
                    where c.id = any({ids})
                      and extract(dow from wk.min_dt)::int + 1 <= cs.day and extract(dow from wk.max_dt)::int + 1 >= cs.day
                    group by c.id),
                a as (
                    select s.class_id as id, count(s.id)::int as submitted, coalesce(sum(s.conducted), 0)::int as conducted,
                           (count(*) filter (where s.conducted = 1 and s.duration > 0))::int as duration_count,
                           coalesce(sum(case when s.conducted = 1 and s.duration > 0 then s.duration else 0 end), 0)::bigint as duration,
                           (count(*) filter (where s.conducted = 1 and s.arabic_conducted in ('1', 'Y')))::int as arabic,
                           (count(*) filter (where s.conducted = 1 and s.aqaed_conducted in ('1', 'Y')))::int as aqaed,
                           (count(*) filter (where s.conducted = 1 and s.ahkam_conducted in ('1', 'Y')))::int as ahkam,
                           (count(*) filter (where s.conducted = 1 and s.akhlaq_conducted in ('1', 'Y')))::int as akhlaq,
                           (count(*) filter (where s.conducted = 1 and s.other_conducted in ('1', 'Y')))::int as other
                    from classes.class_sessions s
                    where s.class_id = any({ids}) and s.conducted_on >= {start} and s.conducted_on <= {end}
                    group by s.class_id),
                m as (
                    select s.class_id, count(ca.id)::bigint as marked, coalesce(sum(ca.present), 0)::bigint as attended
                    from classes.class_sessions s
                    join classes.class_attendance ca on ca.session_id = s.id
                    where s.conducted = 1 and s.class_id = any({ids}) and s.conducted_on >= {start} and s.conducted_on <= {end}
                    group by s.class_id)
                select c.id as "Id", cl.name::text as "Level", c.code::text as "Class", u.name::text as "Teacher",
                       e.expected as "Expected", coalesce(a.submitted, 0) as "Submitted", coalesce(a.conducted, 0) as "Conducted",
                       coalesce(m.attended, 0)::bigint as "Attended", coalesce(m.marked, 0)::bigint as "Marked",
                       coalesce(a.duration_count, 0) as "DurationCount", coalesce(a.duration, 0)::bigint as "Duration",
                       coalesce(a.arabic, 0) as "Arabic", coalesce(a.aqaed, 0) as "Aqaed", coalesce(a.ahkam, 0) as "Ahkam", coalesce(a.akhlaq, 0) as "Akhlaq", coalesce(a.other, 0) as "Other"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                join platform.v_genders g on g.id = c.gender
                join membership.v_members u on u.token = c.teacher
                join e on e.id = c.id
                left join a on a.id = c.id
                left join m on m.class_id = c.id
                where c.status = 'A' and c.id = any({ids})
                order by cl.sort_order, c.id
                """)
            .ToListAsync(ct);
    }
}
