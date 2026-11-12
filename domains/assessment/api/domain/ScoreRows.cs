using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// PHP's McqModel::getStudentScoresByClass, shared by GET /classes/{id}/my-scores and the parent's child scores: every published quiz of the class the member has answered, newest attempt first
/// (by the highest response id), with the member's score, the quiz's question count and the time of the last response. The date bounds apply to each RESPONSE's own time (<c>created_at</c>): a quiz is listed when
/// one response falls in the range; the score and total are never narrowed. A bound is read as MariaDB reads a date (<see cref="PhpDateBound"/>); text it cannot read is the zero date there, so an unreadable
/// <c>start_date</c> bounds nothing and an unreadable <c>end_date</c> lists nothing. Row cap: 5000 quizzes.
/// </summary>
internal static class ScoreRows
{
    private const int MaxQuizzes = 5000;

    internal sealed record Row(int QuizId, string? QuizName, string? Topic, int Total, int? Score, DateTimeOffset? AttemptedAt);

    public static async Task<IReadOnlyList<Row>> ForAsync(AssessmentContext db, long classId, int token, string? from, string? to, CancellationToken ct)
    {
        var start = Offset(PhpDateBound.Bound(from));
        var end = Offset(PhpDateBound.Bound(to));
        if (!string.IsNullOrEmpty(to) && end is null)
        {
            return [];
        }

        return await db.Database
            .SqlQuery<Row>($"""
                select q.id as "QuizId", q.name::text as "QuizName", q.topic::text as "Topic",
                       (select count(*) from assessment.spot_quiz_questions qq where qq.spot_quiz_id = q.id)::int as "Total",
                       (select sum(r.is_correct) from assessment.spot_quiz_responses r where r.spot_quiz_id = q.id and r.token = {token})::int as "Score",
                       (select max(r.created_at) from assessment.spot_quiz_responses r where r.spot_quiz_id = q.id and r.token = {token}) as "AttemptedAt"
                from assessment.spot_quizzes q
                where q.class_id = {classId} and q.published_at is not null
                  and exists (
                    select 1 from assessment.spot_quiz_responses r
                    where r.spot_quiz_id = q.id and r.token = {token}
                      and ({start}::timestamptz is null or r.created_at >= {start}::timestamptz)
                      and ({end}::timestamptz is null or r.created_at <= {end}::timestamptz))
                order by (select max(r.id) from assessment.spot_quiz_responses r where r.spot_quiz_id = q.id and r.token = {token}) desc
                limit {MaxQuizzes}
                """)
            .ToListAsync(ct);
    }

    private static DateTimeOffset? Offset(DateTime? value) => value is null ? null : new DateTimeOffset(value.Value);
}
