using System.Globalization;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// One member's attendance and quiz figures in a class: PHP's <c>ClassStudentsModel</c> getStudentAttendanceHistory, ...Summary and getStudentQuizSummary,
/// shared by my-attendance, my-performance and the three child routes. The summary is computed from the history rows, which have the same WHERE.
/// PHP hands a date bound to MariaDB, which reads Y-m-d with one or two digit parts and any punctuation, YYYYMMDD and either with a time (a T or a space);
/// <see cref="Bound"/> reads the same. Text MariaDB cannot read as a date is ignored here (Postgres would throw).
/// </summary>
internal static class StudentAttendance
{
    private const int MaxSessions = 5000;

    internal sealed record Session(int SessionId, DateOnly ConductedOn, int Duration, bool Present, int Recitation, bool Attended);

    internal sealed record Summary(int TotalSessions, int AttendedSessions, int TotalRecitation);

    internal sealed record Quiz(int QuizzesAttempted, double AverageScore);

    private sealed record Row(int SessionId, DateOnly ConductedOn, int Duration, int Present, int Recitation);

    private sealed record QuizRow(int Correct, int Answered);

    /// <summary>The conducted sessions of the class newest first, each with the member's attendance (absent when there is no row).</summary>
    public static async Task<IReadOnlyList<Session>> HistoryAsync(ClassesContext db, int classId, int token, string? from, string? to, CancellationToken ct)
    {
        var start = Bound(from);
        var end = Bound(to);
        var rows = await db.Database
            .SqlQuery<Row>($"""
                select cs.id as "SessionId", cs.conducted_on as "ConductedOn", coalesce(cs.duration, 0) as "Duration",
                       coalesce(ca.present, 0)::int as "Present", coalesce(ca.recitation, 0) as "Recitation"
                from classes.class_sessions cs
                left join classes.class_attendance ca on ca.session_id = cs.id and ca.token = {token}
                where cs.class_id = {classId} and cs.conducted = 1
                  and ({start}::timestamptz is null or cs.conducted_on::timestamp at time zone 'UTC' >= {start}::timestamptz)
                  and ({end}::timestamptz is null or cs.conducted_on::timestamp at time zone 'UTC' <= {end}::timestamptz)
                order by cs.conducted_on desc, cs.id
                limit {MaxSessions}
                """)
            .ToListAsync(ct);
        return rows.Select(r => new Session(r.SessionId, r.ConductedOn, r.Duration, r.Present != 0, r.Recitation, r.Present == 1)).ToList();
    }

    public static Summary Summarise(IReadOnlyList<Session> history) =>
        new(history.Count, history.Count(s => s.Attended), history.Sum(s => s.Recitation));

    /// <summary>PHP's round(attended / total * 100, places), or 0 with no sessions.</summary>
    public static PhpFloat Percent(Summary summary, int places) =>
        summary.TotalSessions > 0 ? PhpFloat.Round(summary.AttendedSessions * 100m / summary.TotalSessions, places) : new PhpFloat(0);

    /// <summary>
    /// The quizzes of the class the member answered and the mean of their per-quiz percent correct (assessment's published view). PHP bounds each
    /// response by its own time; the view carries the time of the first one per quiz, so a quiz is in or out as a whole (recorded in fill-b1-notes.md).
    /// </summary>
    public static async Task<Quiz> QuizAsync(ClassesContext db, int classId, int token, string? from, string? to, CancellationToken ct)
    {
        var start = Bound(from);
        var end = Bound(to);
        var rows = await db.Database
            .SqlQuery<QuizRow>($"""
                select coalesce(correct, 0) as "Correct", answered as "Answered" from assessment.v_quiz_results
                where class_id = {classId} and token = {token}
                  and ({start}::timestamptz is null or answered_at >= {start}::timestamptz)
                  and ({end}::timestamptz is null or answered_at <= {end}::timestamptz)
                limit {MaxSessions}
                """)
            .ToListAsync(ct);
        if (rows.Count == 0)
        {
            return new Quiz(0, 0);
        }

        var mean = rows.Average(r => r.Correct * 100m / r.Answered);
        return new Quiz(rows.Count, PhpFloat.Round(mean, 2).Value);
    }

    private static readonly Regex DateText = new(
        @"^(\d{4})\D(\d{1,2})\D(\d{1,2})(?:[T ](\d{1,2}):(\d{1,2}):(\d{1,2})(?:\.\d+)?)?$|^(\d{4})(\d{2})(\d{2})$",
        RegexOptions.CultureInvariant | RegexOptions.NonBacktracking);

    /// <summary>A bound as a point in time (a bare date is its midnight, as in MariaDB; read as UTC, the zone of the stored times), or null when it is empty or not a real date.</summary>
    private static DateTime? Bound(string? raw)
    {
        var match = DateText.Match(raw?.Trim() ?? string.Empty);
        if (!match.Success)
        {
            return null;
        }

        var first = match.Groups[7].Success ? 7 : 1;
        var year = Part(match, first);
        var month = Part(match, first + 1);
        var day = Part(match, first + 2);
        if (year < 1 || month is < 1 or > 12 || day < 1 || day > DateTime.DaysInMonth(year, month))
        {
            return null;
        }

        var (hour, minute, second) = (Part(match, first + 3), Part(match, first + 4), Part(match, first + 5));
        return hour > 23 || minute > 59 || second > 59 ? null : new DateTime(year, month, day, hour, minute, second, DateTimeKind.Utc);
    }

    /// <summary>A captured number, 0 when the group did not take part (no time given; the compact form has only three groups).</summary>
    private static int Part(Match match, int group) =>
        match.Groups[group].Success ? int.Parse(match.Groups[group].Value, CultureInfo.InvariantCulture) : 0;
}
