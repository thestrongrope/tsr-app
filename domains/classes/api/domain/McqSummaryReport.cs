using System.Globalization;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

// The MCQ summary as data, for the list (GET /reports/mcq-summary?gender&from&to, days YYYY-MM-DD, default the last 30 days), one class (/{class_id}), the CSV of every class (/download-all?classIds) and the class's file (/{class_id}/download).
// PHP: routes/reports.php api_require_mcq_summary_report (:1263), mis.php mcqSummaryReport (:1531) and mcqSummaryCsv (:617), classstudents.php getStudentMcqPerformance (:1282, three queries per class in PHP).
// Queries: the class ids of the scope, the classes, the quiz count per class, the question count per topic per class, the students with their answers per topic (only classes that published a quiz) = 5, for every class at once.
// Copied: only classes that published at least one quiz in the range are listed, in class order (gender, level order, id); the range is midnight of `from` to midnight of `to` on the publish time (a quiz published later on the `to` day is not in it), every quiz counts
// (deactivated or without a topic too); a topic's maximum is the number of questions of the range's quizzes of that topic (a quiz with no questions adds nothing, a quiz with no topic has no topic line but its answers count in the totals);
// students are the enrolments not removed with a member row, answers of quizzes in the range only; a member enrolled twice in one class is one student whose figures add up (their topic lines overwrite, as PHP's); students order by correct answers, best first, ties by enrolment;
// {class_id} is cast as PHP's (int): 0 or a word means NO narrowing, so the class routes answer with the first class of the whole report.
// Assumptions: ties keep the enrolment order (PHP leaves the order of equal scores to the database); a topic is grouped as its column is (citext: case-insensitive, as MariaDB's collation); the whole percent is Math.Round(correct / max * 100) on a double.

internal static class McqSummaryReport
{
    private const int DefaultDays = 30;
    private const int MaxStudentRows = 200000;

    internal sealed record TopicFigure(int Correct, int Total);

    internal sealed record Student(string Name, int Attempted, int Pending, int Correct, IReadOnlyDictionary<string, TopicFigure> Topics);

    internal sealed record TopicMax(string Topic, int Max);

    internal sealed record ClassSummary(PendingRules.ClassRow Class, int Quizzes, int MaxMarks, IReadOnlyList<TopicMax> Topics, IReadOnlyList<Student> Students);

    internal sealed record Loaded(int Gender, string From, string To, IReadOnlyList<ClassSummary> Classes);

    internal sealed record TopicScore(string Topic, int Max, int? Correct);

    internal sealed record StudentLine(string Name, int Attempted, int Pending, int Correct, int? Percent, IReadOnlyList<TopicScore> Topics);

    /// <summary>What the class route answers: the quiz count, the maximum marks and the students as the web page's table (all zero and none for a class with no quiz in the range or out of reach).</summary>
    internal sealed record ClassBody(int Mcqs, int MaxMarks, IReadOnlyList<StudentLine> Students);

    private sealed record QuizCount(int ClassId, int Quizzes);

    private sealed record TopicRow(int ClassId, string Topic, int Max);

    private sealed record StudentRow(int ClassId, int EnrolmentId, long Token, string? Name, string? Topic, int Correct, int Total, int Attempted);

    public static async Task<(Loaded? Report, IResult? Refusal)> OpenAsync(HttpContext context, ClassesContext db, Permissions permissions, Caller caller, DateOnly today, long classId, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(context);
        var (scope, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return (null, refusal);
        }

        var (range, invalid) = ReportDates.Check(ReportMonths.Param(context, "from"), ReportMonths.Param(context, "to"), today, DefaultDays);
        if (invalid is not null)
        {
            return (null, Problem.Detail(StatusCodes.Status422UnprocessableEntity, invalid));
        }

        var ids = await ReportScope.KeepAssignedAsync(await scope!.ClassIdsAsync(db, classId, ct), permissions, caller, ct);
        var classes = await ReportClasses.ForIdsAsync(db, ids, ct);
        var fromTime = range!.FromDay.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var toTime = range.ToDay.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var quizzes = (await QuizCountsAsync(db, ids, fromTime, toTime, ct)).ToDictionary(q => q.ClassId, q => q.Quizzes);
        var withQuizzes = classes.Where(c => quizzes.ContainsKey(c.Id)).ToList();
        var classIds = withQuizzes.Select(c => c.Id).ToArray();
        var topics = (await TopicsAsync(db, classIds, fromTime, toTime, ct)).ToLookup(t => t.ClassId);
        var students = (await StudentsAsync(db, classIds, fromTime, toTime, ct)).ToLookup(s => s.ClassId);
        var summaries = withQuizzes.Select(c => Summarise(c, quizzes[c.Id], topics[c.Id], students[c.Id])).ToList();
        return (new Loaded(scope.Gender, range.From, range.To, summaries), null);
    }

    /// <summary>PHP <c>api_reports_mcq_summary_class</c>: the first class of the report (PHP <c>$r['report'][0]</c>) as the web page's table.</summary>
    public static ClassBody Body(Loaded report)
    {
        ArgumentNullException.ThrowIfNull(report);
        var c = report.Classes.Count == 0 ? null : report.Classes[0];
        if (c is null)
        {
            return new ClassBody(0, 0, []);
        }

        var students = c.Students.Select(s => new StudentLine(s.Name, s.Attempted, s.Pending, s.Correct, Percent(s, c.MaxMarks), TopicScores(s, c))).ToList();
        return new ClassBody(c.Quizzes, c.MaxMarks, students);
    }

    /// <summary>PHP <c>mcqSummaryCsv</c>: a row per student of every class (or only those of <paramref name="asked"/> when it is not empty), a Score and a Max column for each topic any of them answered (ordinal order), or null when no student is left.</summary>
    public static string? Csv(Loaded report, IReadOnlyCollection<long> asked)
    {
        ArgumentNullException.ThrowIfNull(report);
        var classes = report.Classes.Where(c => asked.Count == 0 || asked.Contains(c.Class.Id)).ToList();
        var topics = classes.SelectMany(c => c.Students).SelectMany(s => s.Topics.Keys).Distinct().Order(StringComparer.Ordinal).ToList();
        var headers = new List<string>(BaseHeaders);
        headers.AddRange(topics.SelectMany(t => new[] { t + " Score", t + " Max" }));
        var rows = new List<IReadOnlyList<string?>>();
        foreach (var c in classes)
        {
            var max = c.Topics.ToDictionary(t => t.Topic, t => t.Max);
            foreach (var s in c.Students)
            {
                var row = new List<string?>
                {
                    c.Class.Code, c.Class.Level, c.Class.TeacherName, c.Class.Location, s.Name, Text(s.Attempted), Text(c.Quizzes), Text(s.Pending), Text(s.Correct), Text(c.MaxMarks), Text(Percent(s, c.MaxMarks) ?? 0),
                };
                foreach (var t in topics)
                {
                    row.Add(Text(s.Topics.TryGetValue(t, out var figure) ? figure.Correct : 0));
                    row.Add(Text(max.GetValueOrDefault(t)));
                }

                rows.Add(row);
            }
        }

        return ReportCsv.Build(headers, rows);
    }

    /// <summary>PHP's whole percent of the class's maximum: null when nothing was attempted or the maximum is 0.</summary>
    public static int? Percent(Student s, int maxMarks)
    {
        ArgumentNullException.ThrowIfNull(s);
        return s.Attempted > 0 && maxMarks > 0 ? (int)Math.Round((double)s.Correct / maxMarks * 100, MidpointRounding.AwayFromZero) : null;
    }

    private static readonly string[] BaseHeaders =
    [
        "Class Code", "Level", "Teacher", "Location", "Student Name", "Attempted", "Total MCQs", "Pending", "Score", "Max Score", "Score %",
    ];

    private static string Text(int value) => value.ToString(CultureInfo.InvariantCulture);

    private static List<TopicScore> TopicScores(Student s, ClassSummary c) =>
        [.. c.Topics.Select(t => new TopicScore(t.Topic, t.Max, s.Attempted > 0 && s.Topics.TryGetValue(t.Topic, out var figure) && figure.Total > 0 ? figure.Correct : null))];

    private static ClassSummary Summarise(PendingRules.ClassRow c, int quizzes, IEnumerable<TopicRow> topicRows, IEnumerable<StudentRow> studentRows)
    {
        var topics = topicRows.Select(t => new TopicMax(t.Topic, t.Max)).ToList();
        return new ClassSummary(c, quizzes, topics.Sum(t => t.Max), topics, Fold(studentRows, quizzes));
    }

    // PHP keys the students by token: a second enrolment adds to the sums and overwrites a topic line. Best score first; the sort is stable, so equal scores keep the enrolment order.
    private static List<Student> Fold(IEnumerable<StudentRow> rows, int quizzes)
    {
        var order = new List<long>();
        var byToken = new Dictionary<long, (string Name, int Correct, int Attempted, Dictionary<string, TopicFigure> Topics)>();
        foreach (var r in rows)
        {
            if (!byToken.TryGetValue(r.Token, out var entry))
            {
                entry = (r.Name ?? string.Empty, 0, 0, []);
                order.Add(r.Token);
            }

            if (!string.IsNullOrEmpty(r.Topic))
            {
                entry.Topics[r.Topic] = new TopicFigure(r.Correct, r.Total);
            }

            byToken[r.Token] = (entry.Name, entry.Correct + r.Correct, entry.Attempted + r.Attempted, entry.Topics);
        }

        return [.. order.Select(token => byToken[token]).Select(e => new Student(e.Name, e.Attempted, quizzes - e.Attempted, e.Correct, e.Topics)).OrderByDescending(s => s.Correct)];
    }

    private static async Task<List<QuizCount>> QuizCountsAsync(ClassesContext db, int[] ids, DateTime from, DateTime to, CancellationToken ct) =>
        await db.Database
            .SqlQuery<QuizCount>($"""
                select q.class_id as "ClassId", count(*)::int as "Quizzes"
                from assessment.v_quizzes q
                where q.class_id = any({ids}) and q.published_at >= {from} and q.published_at <= {to}
                group by q.class_id
                """)
            .ToListAsync(ct);

    private static async Task<List<TopicRow>> TopicsAsync(ClassesContext db, int[] ids, DateTime from, DateTime to, CancellationToken ct) =>
        await db.Database
            .SqlQuery<TopicRow>($"""
                select q.class_id as "ClassId", q.topic::text as "Topic", sum(q.max_marks)::int as "Max"
                from assessment.v_quizzes q
                where q.class_id = any({ids}) and q.published_at >= {from} and q.published_at <= {to} and q.topic is not null and q.topic <> ''
                group by q.class_id, q.topic
                having sum(q.max_marks) > 0
                order by q.class_id, q.topic
                """)
            .ToListAsync(ct);

    // PHP's third query: the roster (not removed) left-joined to the answers of the range's quizzes, one row per enrolment and topic. Bound: 200000 rows.
    private static async Task<List<StudentRow>> StudentsAsync(ClassesContext db, int[] ids, DateTime from, DateTime to, CancellationToken ct) =>
        await db.Database
            .SqlQuery<StudentRow>($"""
                select cs.class_id as "ClassId", cs.id as "EnrolmentId", u.token::bigint as "Token", u.name::text as "Name", r.topic::text as "Topic",
                       coalesce(sum(r.correct), 0)::int as "Correct", coalesce(sum(r.answered), 0)::int as "Total", count(r.quiz_id)::int as "Attempted"
                from classes.class_students cs
                join membership.v_members u on u.token = cs.token_no
                left join assessment.v_quiz_results r on r.class_id = cs.class_id and r.token = cs.token_no and r.published_at >= {from} and r.published_at <= {to}
                where cs.class_id = any({ids}) and cs.removed_at is null
                group by cs.class_id, cs.id, u.token, u.name, r.topic
                order by cs.class_id, cs.id
                limit {MaxStudentRows}
                """)
            .ToListAsync(ct);
}
