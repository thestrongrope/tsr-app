using System.Globalization;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassStudentsPerformance;

// Slice: GET /classes/{class_id}/students/performance?from&to -> each current student's attendance, quiz results and recitation over a range. Contract: spec/api.yaml.
// PHP: routes/class_manage.php route_class_students_performance (:303), ClassStudentsModel::reportRangeError and classStudentsReport. Guards: active complete class (404), mcqs:manage on the class (403),
// then the range (422). `to` defaults to today and `from` to a year before it.
// Quirks copied: a quiz is in the range when its published_at (UTC) lies from `from` at 00:00 to `to` at 00:00 (so a quiz published on the `to` day is out); sessions by their day, both ends included;
// topics in the order Quran, Aqaed, Ahkam, Akhlaq, the others after by name; a student's `topics` is [] when there are none (PHP's empty array); name is the stored text (no entity decoding).
// Deviation: a member with two live enrolment rows is counted once in the quiz figures (PHP adds the rows up).

internal static partial class ClassStudentsPerformanceSlice
{
    private const int MaxRows = 20000;
    private const int MaxDays = 366;
    private static readonly string[] TopicOrder = ["Quran", "Aqaed", "Ahkam", "Akhlaq"];

    internal sealed record Attendance(int Token, int Expected, int Present);

    internal sealed record Recitation(int Token, long Total);

    internal sealed record MaxMarks(string Topic, int Marks);

    internal sealed record QuizFigure(int Token, string? Topic, long Correct, long Total, long Attempted);

    // [0-9], not \d: .NET's \d also matches other scripts' digits, which int.Parse then refuses.
    [GeneratedRegex(@"^([0-9]{4})-([0-9]{2})-([0-9]{2})$", RegexOptions.CultureInvariant | RegexOptions.NonBacktracking)]
    private static partial Regex DateShape();

    public static IEndpointRouteBuilder MapClassStudentsPerformance(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/students/performance", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var head = await ClassGuards.FindActiveClassAsync(source, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "mcqs:manage", AccessTarget.ForClass(head.Id), ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to see this class's student figures");
        }

        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var to = Query(context, "to") ?? Format(today);
        var from = Query(context, "from") ?? Format(YearBefore(ParseDate(to) ?? today));
        if (RangeError(from, to) is { } error)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, error);
        }

        return Results.Json(await ReportAsync(source, head.Id, from, to, ct), ClassesJson.Answers.Answer);
    }

    private static string? Query(HttpContext context, string name)
    {
        var values = context.Request.Query[name];
        return values.Count == 0 ? null : values[^1] ?? string.Empty;
    }

    private static string Format(DateOnly date) => date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    // PHP strtotime('-1 year'): a 29 February goes to 1 March.
    private static DateOnly YearBefore(DateOnly date) =>
        date is { Month: 2, Day: 29 } ? new DateOnly(date.Year - 1, 3, 1) : date.AddYears(-1);

    private static DateOnly? ParseDate(string text)
    {
        var match = DateShape().Match(text);
        if (!match.Success)
        {
            return null;
        }

        var year = int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture);
        var month = int.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture);
        var day = int.Parse(match.Groups[3].Value, CultureInfo.InvariantCulture);
        var real = year >= 1 && month is >= 1 and <= 12 && day >= 1 && day <= DateTime.DaysInMonth(year, month);
        return real ? new DateOnly(year, month, day) : null;
    }

    // ClassStudentsModel::reportRangeError. The dates are YYYY-MM-DD, so the text compares as the dates do.
    internal static string? RangeError(string from, string to)
    {
        if (ParseDate(from) is not { } start || ParseDate(to) is not { } end)
        {
            return "from and to must be dates as YYYY-MM-DD";
        }

        if (string.CompareOrdinal(from, to) > 0)
        {
            return "from must not be after to";
        }

        return end.DayNumber - start.DayNumber > MaxDays ? "The range can cover at most a year" : null;
    }

    private static async Task<Dictionary<string, object?>> ReportAsync(NpgsqlDataSource source, int classId, string from, string to, CancellationToken ct)
    {
        var students = await ClassRoster.ActiveAsync(source, classId, ct);
        var attendance = (await AttendanceAsync(source, classId, from, to, ct)).ToDictionary(a => a.Token);
        var recitation = (await RecitationAsync(source, classId, from, to, ct)).ToDictionary(r => r.Token);
        var totalQuizzes = await source.ScalarAsync<int>(
            $"""
            select count(*)::int as "Value" from assessment.v_quizzes
            where class_id = {classId} and (published_at at time zone 'UTC') >= {from}::timestamp and (published_at at time zone 'UTC') <= {to}::timestamp
            """,
            ct) ?? throw new InvalidOperationException("A count returned no row.");
        var maxMarks = OrderTopics(await MaxMarksAsync(source, classId, from, to, ct));
        var figures = (await QuizFiguresAsync(source, classId, from, to, ct)).ToLookup(f => f.Token);

        var rows = students.Select(s => StudentWire(s, attendance, recitation, figures[s.Token].ToList(), maxMarks)).ToList();
        return new Dictionary<string, object?>
        {
            ["from"] = from,
            ["to"] = to,
            ["totalMcqs"] = totalQuizzes,
            ["maxMarks"] = new Dictionary<string, object?>
            {
                ["total"] = maxMarks.Sum(m => m.Marks),
                ["topics"] = maxMarks.Select(m => new Dictionary<string, object?> { ["name"] = m.Topic, ["max"] = m.Marks }).ToList(),
            },
            ["students"] = rows,
        };
    }

    internal static int TopicCorrect(List<QuizFigure> figures, string topic) =>
        (int)figures.Where(f => string.Equals(f.Topic, topic, StringComparison.OrdinalIgnoreCase)).Sum(f => f.Correct);

    private static Dictionary<string, object?> StudentWire(
        ClassRoster.Student s,
        Dictionary<int, Attendance> attendance,
        Dictionary<int, Recitation> recitation,
        List<QuizFigure> figures,
        List<MaxMarks> maxMarks)
    {
        var expected = attendance.TryGetValue(s.Token, out var a) ? a.Expected : 0;
        var present = a?.Present ?? 0;
        var topics = new Dictionary<string, object?>();
        foreach (var topic in maxMarks)
        {
            topics[topic.Topic] = TopicCorrect(figures, topic.Topic);
        }

        return new Dictionary<string, object?>
        {
            ["token"] = s.Token,
            ["name"] = s.Name ?? string.Empty,
            ["expected"] = expected,
            ["present"] = present,
            ["attendance"] = expected > 0 ? (int)Math.Round(present * 100.0 / expected, MidpointRounding.AwayFromZero) : 0,
            ["mcqAttempted"] = (int)figures.Sum(f => f.Attempted),
            ["mcqCorrect"] = (int)figures.Sum(f => f.Correct),

            // PHP's empty array is a JSON list.
            ["topics"] = topics.Count == 0 ? new List<object?>() : topics,
            ["recitation"] = recitation.TryGetValue(s.Token, out var r) ? (int)r.Total : 0,
        };
    }

    // PHP getStudentAttendance: the conducted sessions of the range that took a register, per member.
    private static async Task<List<Attendance>> AttendanceAsync(NpgsqlDataSource source, int classId, string from, string to, CancellationToken ct) =>
        await source.ListAsync(
            $"""
            select ca.token as "Token", count(cs.id)::int as "Expected", coalesce(sum(ca.present), 0)::int as "Present"
            from classes.class_sessions cs join classes.class_attendance ca on ca.session_id = cs.id
            where cs.class_id = {classId} and cs.conducted = 1 and cs.conducted_on >= {from}::date and cs.conducted_on <= {to}::date
            group by ca.token
            limit {MaxRows}
            """,
            row => new Attendance(row.Int("Token"), row.Int("Expected"), row.Int("Present")),
            ct);

    private static async Task<List<Recitation>> RecitationAsync(NpgsqlDataSource source, int classId, string from, string to, CancellationToken ct) =>
        await source.ListAsync(
            $"""
            select ca.token as "Token", coalesce(sum(ca.recitation), 0)::bigint as "Total"
            from classes.class_sessions cs join classes.class_attendance ca on ca.session_id = cs.id
            where cs.class_id = {classId} and cs.conducted = 1 and cs.conducted_on >= {from}::date and cs.conducted_on <= {to}::date
            group by ca.token
            limit {MaxRows}
            """,
            row => new Recitation(row.Int("Token"), row.Long("Total")),
            ct);

    // The questions of the quizzes of the range by topic, answered or not (a topic nobody attempted still counts against everyone).
    private static async Task<List<MaxMarks>> MaxMarksAsync(NpgsqlDataSource source, int classId, string from, string to, CancellationToken ct) =>
        await source.ListAsync(
            $"""
            select topic as "Topic", sum(max_marks)::int as "Marks" from assessment.v_quizzes
            where class_id = {classId} and (published_at at time zone 'UTC') >= {from}::timestamp and (published_at at time zone 'UTC') <= {to}::timestamp
              and topic is not null and topic <> ''
            group by topic
            order by topic
            limit {MaxRows}
            """,
            row => new MaxMarks(row.Text("Topic"), row.Int("Marks")),
            ct);

    // What each enrolled member answered in the range, per topic.
    private static async Task<List<QuizFigure>> QuizFiguresAsync(NpgsqlDataSource source, int classId, string from, string to, CancellationToken ct) =>
        await source.ListAsync(
            $"""
            select r.token as "Token", nullif(r.topic, '') as "Topic", coalesce(sum(r.correct), 0)::bigint as "Correct",
                   coalesce(sum(r.answered), 0)::bigint as "Total", count(*)::bigint as "Attempted"
            from assessment.v_quiz_results r
            where r.class_id = {classId} and (r.published_at at time zone 'UTC') >= {from}::timestamp and (r.published_at at time zone 'UTC') <= {to}::timestamp
            group by r.token, nullif(r.topic, '')
            limit {MaxRows}
            """,
            row => new QuizFigure(row.Int("Token"), row.TextOrNull("Topic"), row.Long("Correct"), row.Long("Total"), row.Long("Attempted")),
            ct);

    private static List<MaxMarks> OrderTopics(List<MaxMarks> topics) =>
        topics
            .OrderBy(t => Array.IndexOf(TopicOrder, t.Topic) is var at and >= 0 ? at : TopicOrder.Length)
            .ThenBy(t => t.Topic, StringComparer.Ordinal)
            .ToList();
}
