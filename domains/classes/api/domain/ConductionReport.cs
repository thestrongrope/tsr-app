using System.Globalization;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP <c>MisModel::summary_legacy</c>, <c>conductionSummary</c> and <c>conductionReport</c>: one row per class and week of a window, and the per-class figures over them. The weeks come from
/// <see cref="ReportCalendar"/> (PHP read them from <c>calendar_table</c>). Used by the conduction report and its CSV.
/// </summary>
internal static class ConductionReport
{
    private const int MaxRows = 50000;

    /// <summary>One row of <c>summary_legacy</c>. <c>Conducted</c> is "Yes", "No" or "Not Filled"; a week with two sessions gives two rows (PHP's left join).</summary>
    internal sealed record Row(
        int Id, string Level, string Gender, string Class, string? Teacher, DateTime StartedOn, int Year, int Week, DateOnly From, DateOnly To,
        string Conducted, DateOnly? ConductedOn, string? Reason, int? Duration, int? Attendance, int? Registered, int? Extra, string? AqaedTopic);

    internal sealed record ClassFigures(
        string Level, string Gender, string Class, string? Teacher, int Expected, int Conducted, int NotFilled, int NotConducted, int Students, int Attendance,
        int PercentNotFilled, int PercentConduction, int PercentAttendance);

    /// <summary>
    /// PHP <c>(int) number_format($x, 0)</c> as <c>api_cast</c> reads it: rounded half away from zero; from a thousand up number_format writes "1,000", which is not numeric, so the cast gives 0.
    /// </summary>
    public static int Percent(double value)
    {
        var rounded = Math.Round(value, MidpointRounding.AwayFromZero);
        return Math.Abs(rounded) >= 1000 ? 0 : (int)rounded;
    }

    /// <summary>PHP <c>conductionSummary</c>: per class code, in the order first met. Students are those of the class's first row.</summary>
    public static IReadOnlyList<ClassFigures> Summarise(IReadOnlyList<Row> rows)
    {
        ArgumentNullException.ThrowIfNull(rows);
        var order = new List<string>();
        var byClass = new Dictionary<string, List<Row>>();
        foreach (var row in rows)
        {
            if (!byClass.TryGetValue(row.Class, out var list))
            {
                list = [];
                byClass[row.Class] = list;
                order.Add(row.Class);
            }

            list.Add(row);
        }

        return [.. order.Select(code => FiguresOf(byClass[code]))];
    }

    private static ClassFigures FiguresOf(List<Row> rows)
    {
        var first = rows[0];
        var students = (first.Registered ?? 0) + (first.Extra ?? 0);
        var expected = rows.Count;
        var held = rows.Where(r => r.Conducted == "Yes").ToList();
        var notFilled = rows.Count(r => r.Conducted == "Not Filled");
        var notConducted = rows.Count(r => r.Conducted == "No");
        var attendance = held.Sum(r => r.Attendance ?? 0);
        double percentNotFilled = expected == 0 ? 0 : (double)notFilled / expected * 100;
        double percentConduction = expected - notFilled == 0 ? 0 : (double)held.Count / (expected - notFilled) * 100;
        double percentAttendance = students == 0 || held.Count == 0 ? 0 : ((double)attendance / held.Count) / students * 100;
        return new ClassFigures(
            first.Level, first.Gender, first.Class, first.Teacher, expected, held.Count, notFilled, notConducted, students, attendance,
            Percent(percentNotFilled), Percent(percentConduction), Percent(percentAttendance));
    }

    /// <summary>
    /// PHP <c>summary_legacy</c> over the window's weeks (one query): every class of the scope that had begun by the week's last day, left-joined to its sessions of the week, ordered gender, level order, the
    /// numeric part of the code, week start. MariaDB's <c>cast(substr(code, 3) as unsigned)</c> reads "-7" of "SM-7" as 2^64 - 7 (a negative wraps), so "SM-7" sorts before "SM-5" and a code with no
    /// number after the dash gives 0; ported as it is. A row is kept when its week starts no earlier than the class's start (its first day, else its creation time).
    /// </summary>
    public static async Task<List<Row>> RowsAsync(ClassesContext db, int[] classIds, IReadOnlyList<ReportCalendar.Week> weeks, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(weeks);
        var years = weeks.Select(w => w.Year).ToArray();
        var numbers = weeks.Select(w => w.Number).ToArray();
        var firsts = weeks.Select(w => w.Min).ToArray();
        var lasts = weeks.Select(w => w.Max).ToArray();
        return await db.Database
            .SqlQuery<Row>($"""
                select c.id as "Id", l.name::text as "Level", case when c.gender = 1 then 'Gents' else 'Ladies' end as "Gender", c.code::text as "Class", t.name::text as "Teacher",
                       coalesce(c.started_on::timestamp, c.created_at at time zone 'UTC') as "StartedOn",
                       wk.y as "Year", wk.w as "Week", wk.min_dt as "From", wk.max_dt as "To",
                       case when s.conducted is null then 'Not Filled' when s.conducted = 1 then 'Yes' else 'No' end as "Conducted",
                       s.conducted_on as "ConductedOn", s.non_conduction_reason::text as "Reason", s.duration as "Duration", s.attendance as "Attendance",
                       st.cnt as "Registered", char_length(c.extra_students) - char_length(replace(c.extra_students, E'\n', '')) as "Extra", s.aqaed_topic::text as "AqaedTopic"
                from unnest({years}, {numbers}, {firsts}, {lasts}) as wk(y, w, min_dt, max_dt)
                join classes.classes c on c.id = any({classIds}) and (c.started_on is null or c.started_on <= wk.max_dt)
                join classes.class_levels l on l.id = c.class_level_id
                join membership.v_members t on t.token = c.teacher
                left join (select class_id, count(1)::int as cnt from classes.class_students where removed_at is null group by class_id) st on st.class_id = c.id
                left join classes.class_sessions s on s.class_id = c.id and wk.min_dt <= s.conducted_on and wk.max_dt >= s.conducted_on
                where c.status = 'A'
                  and wk.min_dt::timestamp >= coalesce(c.started_on::timestamp, c.created_at at time zone 'UTC')
                order by c.gender, l.sort_order,
                         (case when coalesce(substring(substr(c.code::text, 3) from '^\s*[+-]?[0-9]+'), '0')::numeric < 0
                               then coalesce(substring(substr(c.code::text, 3) from '^\s*[+-]?[0-9]+'), '0')::numeric + 18446744073709551616
                               else coalesce(substring(substr(c.code::text, 3) from '^\s*[+-]?[0-9]+'), '0')::numeric end),
                         wk.min_dt, s.conducted_on, s.id
                limit {MaxRows}
                """)
            .ToListAsync(ct);
    }

    /// <summary>The CSV of <c>conductionDetailsCsv</c>: every raw row, PHP's column names and formats ("%age Conduction" is a four-decimal quotient, 0 for no students, empty when unknown).</summary>
    public static string? Csv(IReadOnlyList<Row> rows)
    {
        ArgumentNullException.ThrowIfNull(rows);
        string[] headers =
        [
            "Id", "Level", "Gender", "Class", "Teacher", "Started On", "Year", "Week", "From", "To", "Conducted", "Conducted On",
            "Reason for Non-Conduction", "Duration", "Attendance", "Registered", "Extra", "%age Conduction", "Aqaed Topic",
        ];
        var lines = rows.Select(r => (IReadOnlyList<string?>)
        [
            Number(r.Id), r.Level, r.Gender, r.Class, r.Teacher, r.StartedOn.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture), Number(r.Year), Number(r.Week),
            Day(r.From), Day(r.To), r.Conducted, r.ConductedOn is { } on ? Day(on) : null, r.Reason, Number(r.Duration), Number(r.Attendance), Number(r.Registered), Number(r.Extra), Quotient(r), r.AqaedTopic,
        ]).ToList();
        return ReportCsv.Build(headers, lines);
    }

    private static string? Number(int? value) => value?.ToString(CultureInfo.InvariantCulture);

    private static string Day(DateOnly day) => day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    // if((Registered + Extra) = 0, 0, Attendance / (Registered + Extra)): NULL while either count is unknown; the division of two integers has four decimals.
    private static string? Quotient(Row row)
    {
        if (row.Registered is null || row.Extra is null)
        {
            return null;
        }

        var students = row.Registered.Value + row.Extra.Value;
        if (students == 0)
        {
            return "0";
        }

        return row.Attendance is null
            ? null
            : Math.Round((decimal)row.Attendance.Value / students, 4, MidpointRounding.AwayFromZero).ToString("0.0000", CultureInfo.InvariantCulture);
    }

    /// <summary>What the screen and the download both show of a loaded report: the figures and the week rows narrowed to a level (PHP: after the figures, by exact name), the week's dates and the window.</summary>
    internal sealed record Shaped(IReadOnlyList<string> Levels, IReadOnlyList<ClassFigures> Classes, IReadOnlyList<Row> LastWeek, string WeekOf, string SummaryStart, string SummaryEnd);

    public static Shaped Shape(Loaded report, string level)
    {
        ArgumentNullException.ThrowIfNull(report);
        ArgumentNullException.ThrowIfNull(level);
        var figures = Summarise(report.Rows);
        var thisWeek = report.Rows.Where(r => r.Week == report.Week && r.Year == report.Year).ToList();
        var weekOf = thisWeek.Count == 0 ? string.Empty : ShortDay(thisWeek[^1].From) + " to " + ShortDay(thisWeek[^1].To);
        return new Shaped(
            [.. figures.Select(f => f.Level).Distinct()],
            [.. figures.Where(f => level.Length == 0 || f.Level == level)],
            [.. thisWeek.Where(r => level.Length == 0 || r.Level == level)],
            weekOf,
            LongDay(report.WindowStart),
            LongDay(report.WindowEnd));
    }

    private static string ShortDay(DateOnly day) => day.ToString("dd-MMM", CultureInfo.InvariantCulture);

    private static string LongDay(DateOnly day) => day.ToString("ddd, dd-MMM-yy", CultureInfo.InvariantCulture);

    /// <summary>What <see cref="OpenAsync"/> gives: the chosen week, the window's dates, and every row of the window.</summary>
    internal sealed record Loaded(int Gender, int Year, int Week, DateOnly WindowStart, DateOnly WindowEnd, IReadOnlyList<Row> Rows);

    /// <summary>
    /// PHP <c>api_require_conduction_report</c>: the gender and the <c>reports:read</c> guard, then year and week (default the last completed week; 422 "Invalid year or week"), then
    /// <c>conductionReport</c>: the months of the week's first and last day, the window over them, the rows. A week the table does not have reads as the epoch (PHP's <c>strtotime(null)</c>: 1970 dates,
    /// no rows). A window wholly in the future gives no rows (PHP dies on it with a warning and a fatal error: not copied).
    /// </summary>
    public static async Task<(Loaded? Report, IResult? Refusal)> OpenAsync(HttpContext context, ClassesContext db, Permissions permissions, Caller caller, DateOnly today, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(context);
        var (scope, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return (null, refusal);
        }

        var (lastYear, lastWeek) = ReportCalendar.LastCompleted(today);
        var year = ClassGuards.QueryInt(context, "year", lastYear);
        var week = ClassGuards.QueryInt(context, "week", lastWeek);
        if (week < 0 || week > 53 || year < 2000 || year > 2100)
        {
            return (null, Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Invalid year or week"));
        }

        var range = ReportCalendar.Range((int)year, (int)week);
        var first = range?.Min ?? new DateOnly(1970, 1, 1);
        var last = range?.Max ?? new DateOnly(1970, 1, 1);
        var (start, end) = ReportCalendar.Window(first.ToString("MM-yyyy", CultureInfo.InvariantCulture), last.ToString("MM-yyyy", CultureInfo.InvariantCulture), today);
        List<Row> rows = [];
        if (start <= end)
        {
            var ids = await scope!.ClassIdsAsync(db, 0, ct);
            rows = await RowsAsync(db, ids, ReportCalendar.Weeks(start, end), ct);
        }

        return (new Loaded(scope!.Gender, (int)year, (int)week, start, end, rows), null);
    }
}
