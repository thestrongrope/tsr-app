using System.Globalization;
using Npgsql;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP <c>MisModel::summary</c>'s query, shared by the summary report and the pending report (its "Not Filled" figure comes from <c>summaryReport</c>): per class over the months, the sums the figures are made of.
/// Only classes with a schedule slot in a finished week are listed (inner join on the expected slots); the expected slots count from 2021-11-01.
/// </summary>
internal static class SummaryRows
{
    private static readonly DateOnly SchoolStart = new(2021, 11, 1);

    internal sealed record Row(
        int Id, string Level, string Class, string? Teacher, int Expected, int Submitted, int Conducted, long Attended, long Marked, int DurationCount, long Duration,
        int Arabic, int Aqaed, int Ahkam, int Akhlaq, int Other);

    /// <summary>The rows of the classes <paramref name="ids"/> for the months <paramref name="from"/> to <paramref name="to"/> ('MM-YYYY', already checked); none when the window starts after it ends. One query.</summary>
    public static async Task<List<Row>> ForMonthsAsync(NpgsqlDataSource db, int[] ids, string from, string to, DateOnly today, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(ids);
        var (start, end) = ReportCalendar.Window(from, to, today);
        if (start > end)
        {
            return [];
        }

        var weeks = ReportCalendar.Weeks(start > SchoolStart ? start : SchoolStart, end < today ? end : today);
        return await RowsAsync(db, ids, weeks, start, end, today, ct);
    }

    // `e`: each class's schedule slots in the finished weeks of the window (a week counts when it lies inside the class's own start and end and is over); `a`: its sessions of the window;
    // `t`: the attendance marks of its held sessions. The class must have slots (inner join), the others are left joins.
    private static async Task<List<Row>> RowsAsync(NpgsqlDataSource db, int[] ids, IReadOnlyList<ReportCalendar.Week> weeks, DateOnly start, DateOnly end, DateOnly today, CancellationToken ct)
    {
        var mins = weeks.Select(w => w.Min.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)).ToArray();
        var maxs = weeks.Select(w => w.Max.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)).ToArray();
        var schoolStart = SchoolStart;
        return await db.ListAsync(
            $"""
                with wk as (select min_dt, max_dt from unnest({mins}::date[], {maxs}::date[]) as w(min_dt, max_dt)),
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
                """,
            r => new Row(
                r.Int("Id"), r.Text("Level"), r.Text("Class"), r.TextOrNull("Teacher"), r.Int("Expected"), r.Int("Submitted"), r.Int("Conducted"), r.Long("Attended"), r.Long("Marked"),
                r.Int("DurationCount"), r.Long("Duration"), r.Int("Arabic"), r.Int("Aqaed"), r.Int("Ahkam"), r.Int("Akhlaq"), r.Int("Other")),
            ct);
    }
}
