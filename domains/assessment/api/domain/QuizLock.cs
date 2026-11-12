using Microsoft.EntityFrameworkCore;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The quiz row lock that keeps an edit and an answer apart. An edit of a quiz (<c>manage-update</c>) locks the row <c>for update</c>, then refuses when any answer exists. Whoever writes answers (an online submit, an offline entry)
/// first takes the same row <c>for share</c>: it waits while an edit runs, and an edit waits while answers are being written. Several answer writers share the lock and do not block each other.
/// </summary>
internal static class QuizLock
{
    /// <summary>Locks the quiz row for share, inside the caller's transaction. False when the quiz is gone or its questions are no longer exactly <paramref name="questionIds"/> (an edit committed after the caller read them): write nothing.</summary>
    public static async Task<bool> ShareUnchangedAsync(AssessmentContext db, long quizId, IReadOnlyCollection<long> questionIds, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(questionIds);
        var ids = questionIds.ToArray();
        var locked = await db.Database
            .SqlQuery<int>($"""select id as "Value" from assessment.spot_quizzes where id = {quizId} for share""")
            .ToListAsync(ct);
        if (locked.Count == 0)
        {
            return false;
        }

        return await db.Database
            .SqlQuery<bool>($"""
                select ((select count(*) from assessment.spot_quiz_questions where spot_quiz_id = {quizId}) = {ids.Length}
                    and (select count(*) from assessment.spot_quiz_questions where spot_quiz_id = {quizId} and id = any({ids})) = {ids.Length}) as "Value"
                """)
            .SingleAsync(ct);
    }

    /// <summary>Locks the quiz row for update, inside the caller's transaction, and says whether any online answer or offline submission exists. Null when the quiz row is gone.</summary>
    public static async Task<bool?> LockAndCheckAnsweredAsync(AssessmentContext db, long quizId, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        var locked = await db.Database
            .SqlQuery<int>($"""select id as "Value" from assessment.spot_quizzes where id = {quizId} for update""")
            .ToListAsync(ct);
        if (locked.Count == 0)
        {
            return null;
        }

        return await db.Database
            .SqlQuery<bool>($"""
                select (exists (select 1 from assessment.spot_quiz_responses where spot_quiz_id = {quizId})
                    or exists (select 1 from assessment.spot_quiz_submissions where spot_quiz_id = {quizId})) as "Value"
                """)
            .SingleAsync(ct);
    }
}
