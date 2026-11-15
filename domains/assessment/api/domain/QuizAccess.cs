using System.Globalization;
using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// What the student-facing quiz routes ask of the database, each PHP's own (models/mcq.php): the quiz a student may see, their attempt, the question count, and the enrolment check.
/// Enrolment comes from classes' published view <c>classes.v_enrolments</c>, the member's gender from membership's <c>membership.v_members</c> (api_require_identity).
/// </summary>
internal static class QuizAccess
{
    /// <summary>PHP getForStudent's row: a published quiz of a class the member is an enrolled student of. Deactivation is not a filter (a student who answered still sees the result).</summary>
    internal sealed record VisibleQuiz(int Id, string? Code, string? Name, string? Topic, int ClassId, DateTimeOffset? PublishedAt, DateTimeOffset? DeactivatedAt);

    /// <summary>PHP getStudentAttempt: whether the member has any response to the quiz, and the sum of their correct flags (null with no response).</summary>
    internal sealed record Attempt(bool Attempted, int? Score);

    private sealed record AttemptRow(int Answered, int? Score);

    /// <summary>The JSON text of a datetime column as PHP's api_cast makes it: <c>Y-m-d\TH:i:s</c>, no zone (the stored times are UTC).</summary>
    public static string? Stamp(DateTimeOffset? value) => value?.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss", CultureInfo.InvariantCulture);

    /// <summary>PHP's api_require_identity: the member's stored gender is a number.</summary>
    public static async Task<bool> HasNumericGenderAsync(AssessmentContext db, Caller caller, CancellationToken ct)
    {
        var gender = await db.Database
            .SqlQuery<string>($"""select coalesce(gender, '') as "Value" from membership.v_members where user_id = {caller.UserId} limit 1""")
            .ToListAsync(ct);
        return gender.Count == 1 && PhpValue.IsNumeric(gender[0]);
    }

    /// <summary>PHP isEnrolledStudent: a current student of the class (status A, not removed); a teacher is not one.</summary>
    public static async Task<bool> IsEnrolledStudentAsync(AssessmentContext db, long classId, int token, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<int>($"""
                select 1 as "Value" from classes.v_enrolments
                where class_id = {classId} and token_no = {token} and status = 'A' and removed_at is null
                limit 1
                """)
            .ToListAsync(ct);
        return rows.Count > 0;
    }

    public static async Task<VisibleQuiz?> VisibleAsync(AssessmentContext db, long quizId, int token, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<VisibleQuiz>($"""
                select q.id as "Id", q.code::text as "Code", q.name::text as "Name", q.topic::text as "Topic", q.class_id as "ClassId",
                       q.published_at as "PublishedAt", q.deactivated_at as "DeactivatedAt"
                from assessment.spot_quizzes q
                where q.id = {quizId} and q.published_at is not null
                  and exists (
                    select 1 from classes.v_enrolments cs
                    where cs.class_id = q.class_id and cs.token_no = {token} and cs.status = 'A' and cs.removed_at is null)
                limit 1
                """)
            .ToListAsync(ct);
        return rows.Count == 0 ? null : rows[0];
    }

    public static async Task<Attempt> AttemptAsync(AssessmentContext db, long quizId, int token, CancellationToken ct)
    {
        var row = await db.Database
            .SqlQuery<AttemptRow>($"""
                select count(*)::int as "Answered", sum(is_correct)::int as "Score"
                from assessment.spot_quiz_responses where spot_quiz_id = {quizId} and token = {token}
                """)
            .SingleAsync(ct);
        return new Attempt(row.Answered > 0, row.Score);
    }

    public static async Task<int> CountQuestionsAsync(AssessmentContext db, long quizId, CancellationToken ct) =>
        await db.Database
            .SqlQuery<int>($"""select count(*)::int as "Value" from assessment.spot_quiz_questions where spot_quiz_id = {quizId}""")
            .SingleAsync(ct);
}
