using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// One member's attendance and quiz figures in a class: PHP's <c>ClassStudentsModel</c> getStudentAttendanceHistory, ...Summary and getStudentQuizSummary,
/// shared by my-attendance, my-performance and the three child routes. The summary is computed from the history rows, which have the same WHERE.
/// PHP hands a date bound to MariaDB, which reads Y-m-d with one or two digit parts and any punctuation, YYYYMMDD and either with a time (a T or a space);
/// <see cref="PhpDateBound"/> reads the same. Text MariaDB cannot read as a date is ignored here (Postgres would throw).
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
    public static async Task<IReadOnlyList<Session>> HistoryAsync(NpgsqlDataSource source, int classId, int token, string? from, string? to, CancellationToken ct)
    {
        var start = ClassesRows.Bound(from);
        var end = ClassesRows.Bound(to);
        var rows = await source.ListAsync(
            $"""
                select cs.id as "SessionId", cs.conducted_on as "ConductedOn", coalesce(cs.duration, 0) as "Duration",
                       coalesce(ca.present, 0)::int as "Present", coalesce(ca.recitation, 0) as "Recitation"
                from classes.class_sessions cs
                left join classes.class_attendance ca on ca.session_id = cs.id and ca.token = {token}
                where cs.class_id = {classId} and cs.conducted = 1
                  and ({start}::timestamptz is null or cs.conducted_on::timestamp at time zone 'UTC' >= {start}::timestamptz)
                  and ({end}::timestamptz is null or cs.conducted_on::timestamp at time zone 'UTC' <= {end}::timestamptz)
                order by cs.conducted_on desc, cs.id
                limit {MaxSessions}
                """,
            row => new Row(row.Int("SessionId"), row.Date("ConductedOn"), row.Int("Duration"), row.Int("Present"), row.Int("Recitation")),
            ct);
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
    public static async Task<Quiz> QuizAsync(NpgsqlDataSource source, int classId, int token, string? from, string? to, CancellationToken ct)
    {
        var start = ClassesRows.Bound(from);
        var end = ClassesRows.Bound(to);
        var rows = await source.ListAsync(
            $"""
                select coalesce(correct, 0) as "Correct", answered as "Answered" from assessment.v_quiz_results
                where class_id = {classId} and token = {token}
                  and ({start}::timestamptz is null or answered_at >= {start}::timestamptz)
                  and ({end}::timestamptz is null or answered_at <= {end}::timestamptz)
                limit {MaxSessions}
                """,
            row => new QuizRow(row.Int("Correct"), row.Int("Answered")),
            ct);
        if (rows.Count == 0)
        {
            return new Quiz(0, 0);
        }

        var mean = rows.Average(r => r.Correct * 100m / r.Answered);
        return new Quiz(rows.Count, PhpFloat.Round(mean, 2).Value);
    }
}
