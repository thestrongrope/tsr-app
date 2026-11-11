using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportStudents;

// Slice: GET /reports/students?gender&from&to (days YYYY-MM-DD, default the last 30 days) -> {gender, from, to, levels, classes[{class, level}], students[{token, name, level, class, sessions, attendance, totalMcqs, mcqAttempted, mcqPerformance,
// recitation, recitationAvg, tsrScore}]}: every student of every class the caller reaches who has an attendance mark in the range, best score first. Level, class and search narrow it in the app. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_students (:528, api_require_students_report :508), mis.php studentPerformanceReport (:1354), studentPerformance (:1213), withRecitation, quranrecitation.php getLeaderboardData (:17).
// Queries: the class ids of the scope, the level order, the students with their attendance and quiz figures (PHP: five derived tables), the recitation leaderboard: 4.
// Copied: only students with an attendance mark of a held session in the range are listed (a student of a class with none is dropped), one row per enrolment not removed (a student in two classes is listed twice, each with that class's figures);
// quizzes count by their publish time as a time (one published after midnight of the `to` day is not in the range); the figures are decimals at four places and the score their mean at eight; percentages are whole numbers, half away from zero.
// THE RECITATION is PHP's global leaderboard, not the class's own marks: every attendance mark of the range (held or not, any class, any gender) is summed per token and ranked, THEN limited to enrolments with status 'A' (not removed_at) in an
// active class, to the members whose own gender is the asked one (the stored text), and, for a caller whose reach is assigned classes only, to those classes; only the first 1000 such rows (by rank) count, so a student ranked after them has recitation 0
// (a student with two enrolments takes two rows). Ties at the cut are decided by token here (PHP: by the database). Deviation: at most 20000 student rows (PHP has none).

internal static class ReportStudentsSlice
{
    private const int DefaultDays = 30;
    private const int LeaderboardRows = 1000;
    private const int MaxStudents = 20000;

    internal sealed record Student(
        string Token, string Name, string Level, string Class, int Sessions, int Attendance, int TotalMcqs, int McqAttempted, int McqPerformance, int Recitation, PhpFloat RecitationAvg, int TsrScore);

    internal sealed record Answer(int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<StudentRules.Pick> Classes, IReadOnlyList<Student> Students);

    private sealed record StudentRow(
        long Token, string? Name, string Level, string Class, int Sessions, long Present, int Quizzes, long Questions, int Responded, long Correct);

    private sealed record RecitationRow(long Token, long Total);

    public static IEndpointRouteBuilder MapReportStudents(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/students", HandleAsync).RequireMember(createsMember: true);
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

        var ids = await scope!.ClassIdsAsync(db, 0, ct);
        var rows = await StudentsAsync(db, ids, range!, ct);
        var assigned = (await permissions.ReachAsync(caller, "reports:read", ct)).AssignedOnlyIds;
        var recited = rows.Count == 0 ? [] : await RecitationAsync(db, scope.Gender, assigned, range!, ct);
        var students = Rank(rows, recited);
        var (levels, classes) = StudentRules.Pickers(students.Select(s => new StudentRules.Pick(s.Class, s.Level)), await LevelNamesAsync(db, ct));
        return Results.Json(new Answer(scope.Gender, range!.From, range.To, levels, classes, students));
    }

    private static List<Student> Rank(List<StudentRow> rows, Dictionary<long, long> recited)
    {
        var scored = rows.Select(r =>
        {
            var f = StudentRules.Of(new StudentRules.Sums(r.Sessions, r.Present, r.Quizzes, r.Questions, r.Responded, r.Correct));
            var total = recited.GetValueOrDefault(r.Token);
            var student = new Student(
                r.Token.ToString(CultureInfo.InvariantCulture), r.Name ?? string.Empty, r.Level, r.Class, r.Sessions, f.Attendance, r.Quizzes, f.Attempted, f.QuizPercent, (int)total,
                StudentRules.AverageRecitation(total, r.Sessions), f.Performance);
            return (Student: student, f.PerformanceExact);
        });
        return [.. scored.OrderByDescending(s => s.PerformanceExact).ThenBy(s => s.Student.Class, StringComparer.Ordinal).ThenBy(s => s.Student.Token, StringComparer.Ordinal).Select(s => s.Student)];
    }

    // PHP ClassesModel::getLevels (array_flip of the names in order): the levels' names by sort order.
    private static async Task<List<string>> LevelNamesAsync(ClassesContext db, CancellationToken ct) =>
        await db.Database
            .SqlQuery<string>($"""select name::text as "Value" from classes.class_levels order by sort_order, id limit 1000""")
            .ToListAsync(ct);

    // PHP studentPerformance: the roster (not removed) of the classes in reach joined to the attendance of the held sessions in the range (inner join: no mark, no row) and to the class's quizzes and the student's answers.
    private static async Task<List<StudentRow>> StudentsAsync(ClassesContext db, int[] ids, DateRange range, CancellationToken ct)
    {
        var from = range.FromDay;
        var to = range.ToDay;
        var fromTime = range.FromDay.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var toTime = range.ToDay.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        return await db.Database
            .SqlQuery<StudentRow>($"""
                with att as (
                    select s.class_id, ca.token, count(ca.id)::int as sessions, coalesce(sum(ca.present), 0)::bigint as present
                    from classes.class_sessions s
                    join classes.class_attendance ca on ca.session_id = s.id
                    where s.class_id = any({ids}) and s.conducted = 1 and s.conducted_on >= {from} and s.conducted_on <= {to}
                    group by s.class_id, ca.token),
                qc as (
                    select q.class_id, count(*)::int as quizzes, coalesce(sum(q.max_marks), 0)::bigint as questions
                    from assessment.v_quizzes q
                    where q.class_id = any({ids}) and q.published_at >= {fromTime} and q.published_at <= {toTime}
                    group by q.class_id),
                qr as (
                    select r.class_id, r.token, count(*)::int as responded, coalesce(sum(r.correct), 0)::bigint as correct
                    from assessment.v_quiz_results r
                    where r.class_id = any({ids}) and r.published_at >= {fromTime} and r.published_at <= {toTime}
                    group by r.class_id, r.token)
                select u.token::bigint as "Token", u.name::text as "Name", cl.name::text as "Level", c.code::text as "Class", att.sessions as "Sessions", att.present as "Present",
                       coalesce(qc.quizzes, 0) as "Quizzes", coalesce(qc.questions, 0)::bigint as "Questions", coalesce(qr.responded, 0) as "Responded", coalesce(qr.correct, 0)::bigint as "Correct"
                from classes.class_students cs
                join classes.classes c on c.id = cs.class_id
                join classes.class_levels cl on cl.id = c.class_level_id
                join membership.v_members u on u.token = cs.token_no
                join att on att.class_id = c.id and att.token = cs.token_no
                left join qc on qc.class_id = c.id
                left join qr on qr.class_id = c.id and qr.token = cs.token_no
                where c.id = any({ids}) and c.status = 'A' and cs.removed_at is null
                order by c.id, u.token
                limit {MaxStudents}
                """)
            .ToListAsync(ct);
    }

    // PHP getLeaderboardData(1000, 0, from, to, level 0, gender, minimum 0): rank every token's recitation of the range, then keep the enrolments (status 'A') in active classes of members of the gender, in the assigned classes when that is all the caller reaches, and cut at 1000 rows.
    private static async Task<Dictionary<long, long>> RecitationAsync(ClassesContext db, int gender, IReadOnlyList<int>? assigned, DateRange range, CancellationToken ct)
    {
        var from = range.FromDay;
        var to = range.ToDay;
        var genderText = gender.ToString(CultureInfo.InvariantCulture);
        var limited = assigned is not null;
        int[] assignedIds = assigned is null ? [] : [.. assigned];
        var rows = await db.Database
            .SqlQuery<RecitationRow>($"""
                with ranked as (
                    select ca.token, sum(ca.recitation) as total, rank() over (order by sum(ca.recitation) desc) as rnk
                    from classes.class_attendance ca
                    join classes.class_sessions s on s.id = ca.session_id
                    where s.conducted_on between {from} and {to}
                    group by ca.token)
                select ra.token::bigint as "Token", ra.total::bigint as "Total"
                from ranked ra
                join classes.class_students cs on cs.token_no = ra.token
                join classes.classes c on c.id = cs.class_id
                join membership.v_members u on u.token = ra.token
                where cs.status = 'A' and c.status = 'A' and u.gender = {genderText} and ({limited} = false or c.id = any({assignedIds})) and ra.total >= 0
                order by ra.rnk, ra.token, c.id
                limit {LeaderboardRows}
                """)
            .ToListAsync(ct);
        return rows.GroupBy(r => r.Token).ToDictionary(g => g.Key, g => g.Last().Total);
    }
}
