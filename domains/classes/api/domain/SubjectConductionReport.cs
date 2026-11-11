using System.Globalization;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

// The subject conduction report as data, for the screen (GET /reports/subject-conduction?gender&from&to&level&classId, months MM-YYYY, default this month) and the download (its /download): per class and week of the months, the date it last met and the topics each subject covered.
// PHP: routes/reports.php api_require_subject_conduction_report (:996), mis.php subjectConductionClasses (:2119) and subjectConductionWeekly (:1858). Queries: the class ids of the scope,
// the classes (the choices), the held sessions.
// Copied: a class asked for that the caller does not reach is 403 (after the months, before any data); "levels" are those of the rows before the level and class narrowing; the week label is the calendar year and
// WEEK(day, 1) (SubjectWeeks); a session's topic is its subject's topic only where the subject was taught, "Conducted" when it was taught with no topic; the later session's date stands for a week.
// MariaDB to PostgreSQL: DATE_FORMAT('%d %b %Y') is "dd MMM yyyy" with English month names; the topic text is compared as written ("0" and "" are skipped as PHP's empty()).

internal static class SubjectConductionReport
{
    private const int MaxSessions = 50000;

    internal sealed record Choice(int ClassId, string Class, string Level, string Teacher);

    internal sealed record RowItem(string Class, string Level, string Teacher, string Week, string HeldOn, string Arabic, string Aqaed, string Ahkam, string Akhlaq, string Other);

    internal sealed record Loaded(int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<Choice> Classes, IReadOnlyList<RowItem> Rows);

    private sealed record ClassRow(int Id, string Code, string Level, string? Teacher);

    private sealed record SessionRow(string ClassCode, string Level, string? Teacher, DateOnly ConductedOn, string Arabic, string Aqaed, string Ahkam, string Akhlaq, string Other);

    private sealed class WeekAcc(string week, string heldOn)
    {
        public string Week { get; } = week;

        public string HeldOn { get; set; } = heldOn;

        public string[] Topics { get; } = ["", "", "", "", ""];
    }

    public static async Task<(Loaded? Report, IResult? Refusal)> OpenAsync(HttpContext context, ClassesContext db, Permissions permissions, Caller caller, DateOnly today, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(context);
        var (scope, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return (null, refusal);
        }

        var from = ReportMonths.Param(context, "from") ?? today.ToString("MM-yyyy", CultureInfo.InvariantCulture);
        var to = ReportMonths.Param(context, "to") ?? from;
        var invalid = ReportMonths.Check(from, to, limitToTwelve: true);
        if (invalid is not null)
        {
            return (null, Problem.Detail(StatusCodes.Status422UnprocessableEntity, invalid));
        }

        var ids = await scope!.ClassIdsAsync(db, 0, ct);
        var classes = await ClassesAsync(db, ids, ct);
        var classId = ClassGuards.QueryInt(context, "classId", 0);
        var chosen = classes.FirstOrDefault(c => c.Id == classId);
        if (classId != 0 && chosen is null)
        {
            return (null, Refusals.NotPermitted());
        }

        var first = MonthStart(from);
        var last = MonthStart(to).AddMonths(1).AddDays(-1);
        var rows = Group(await SessionsAsync(db, ids, first, last, ct));
        var level = ReportScope.LevelOf(context);
        var shown = rows
            .Where(r => level.Length == 0 || r.Level == level)
            .Where(r => chosen is null || r.Class == chosen.Code)
            .ToList();
        return (new Loaded(
            scope.Gender, from, to, [.. rows.Select(r => r.Level).Distinct()],
            [.. classes.Select(c => new Choice(c.Id, c.Code, c.Level, PhpCast.Str(c.Teacher)))], shown), null);
    }

    private static DateOnly MonthStart(string month)
    {
        var parts = month.Split('-');
        return new DateOnly((int)PhpValue.IntOfText(parts[1]), (int)PhpValue.IntOfText(parts[0]), 1);
    }

    // PHP's grouping: by class code in the order the rows come (level order, code, day), then by week label; later sessions add topics and move the week's date.
    private static List<RowItem> Group(List<SessionRow> sessions)
    {
        var order = new List<string>();
        var heads = new Dictionary<string, (string Level, string Teacher)>();
        var weeks = new Dictionary<string, List<WeekAcc>>();
        foreach (var s in sessions)
        {
            if (!weeks.TryGetValue(s.ClassCode, out var list))
            {
                list = [];
                weeks[s.ClassCode] = list;
                heads[s.ClassCode] = (s.Level, PhpCast.Str(s.Teacher));
                order.Add(s.ClassCode);
            }

            var label = SubjectWeeks.Label(s.ConductedOn);
            var date = s.ConductedOn.ToString("dd MMM yyyy", CultureInfo.InvariantCulture);
            var week = list.Find(w => w.Week == label);
            if (week is null)
            {
                week = new WeekAcc(label, date);
                list.Add(week);
            }
            else
            {
                week.HeldOn = date;
            }

            string[] topics = [s.Arabic, s.Aqaed, s.Ahkam, s.Akhlaq, s.Other];
            for (var i = 0; i < topics.Length; i++)
            {
                week.Topics[i] = SubjectWeeks.Join(week.Topics[i], topics[i]);
            }
        }

        return
        [
            .. order.SelectMany(code => weeks[code].Select(w =>
                new RowItem(code, heads[code].Level, heads[code].Teacher, w.Week, w.HeldOn, w.Topics[0], w.Topics[1], w.Topics[2], w.Topics[3], w.Topics[4]))),
        ];
    }

    // subjectConductionClasses: the classes of the scope whose level and teacher exist, level order then code.
    private static async Task<List<ClassRow>> ClassesAsync(ClassesContext db, int[] ids, CancellationToken ct) =>
        await db.Database
            .SqlQuery<ClassRow>($"""
                select c.id as "Id", c.code::text as "Code", cl.name::text as "Level", t.name::text as "Teacher"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                join membership.v_members t on t.token = c.teacher
                where c.id = any({ids})
                order by cl.sort_order, c.code
                """)
            .ToListAsync(ct);

    private static async Task<List<SessionRow>> SessionsAsync(ClassesContext db, int[] ids, DateOnly first, DateOnly last, CancellationToken ct) =>
        await db.Database
            .SqlQuery<SessionRow>($"""
                select c.code::text as "ClassCode", cl.name::text as "Level", t.name::text as "Teacher", s.conducted_on as "ConductedOn",
                       case when s.arabic_conducted in ('1', 'Y') then coalesce(nullif(s.arabic_topic, ''), 'Conducted')::text else '' end as "Arabic",
                       case when s.aqaed_conducted in ('1', 'Y') then coalesce(nullif(s.aqaed_topic, ''), 'Conducted')::text else '' end as "Aqaed",
                       case when s.ahkam_conducted in ('1', 'Y') then coalesce(nullif(s.ahkam_topic, ''), 'Conducted')::text else '' end as "Ahkam",
                       case when s.akhlaq_conducted in ('1', 'Y') then coalesce(nullif(s.akhlaq_topic, ''), 'Conducted')::text else '' end as "Akhlaq",
                       case when s.other_conducted in ('1', 'Y') then coalesce(nullif(s.other_topic, ''), 'Conducted')::text else '' end as "Other"
                from classes.class_sessions s
                join classes.classes c on c.id = s.class_id
                join classes.class_levels cl on cl.id = c.class_level_id
                join membership.v_members t on t.token = c.teacher
                where s.conducted_on >= {first} and s.conducted_on <= {last} and s.conducted = 1 and c.id = any({ids})
                order by cl.sort_order, c.code, s.conducted_on, s.id
                limit {MaxSessions}
                """)
            .ToListAsync(ct);
}
