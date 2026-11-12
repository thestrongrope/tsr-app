using Microsoft.EntityFrameworkCore;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The one insert of a quiz row (create, copy a standard MCQ, copy between classes), with the code PHP's trigger gave it (<see cref="QuizCode"/>): drawn, then inserted with <c>on conflict (code) do nothing</c> against the unique
/// index <c>spot_quizzes_code</c> (citext, so letter case does not matter). No row back means the code was taken, even by a transaction not yet committed: draw again, up to <see cref="MaxAttempts"/> times. The statement
/// does not fail, so the caller's PostgreSQL transaction is never aborted. A quiz is never published by this insert.
/// </summary>
internal static class NewQuiz
{
    public const int MaxAttempts = 20;

    /// <summary>What a new quiz carries. <paramref name="McqCode"/> is the standard MCQ it was copied from (null otherwise): the column the copy reports read.</summary>
    internal sealed record Fields(int ClassId, string Name, string? Topic, string? McqCode, int RestrictToClass, int CreatedBy);

    public static async Task<int> InsertAsync(AssessmentContext db, Fields quiz, DateTimeOffset at, CancellationToken ct, Func<string>? draw = null)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(quiz);
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("A quiz is inserted inside the caller's transaction.");
        }

        for (var attempt = 0; attempt < MaxAttempts; attempt++)
        {
            var code = (draw ?? QuizCode.Generate)();
            var ids = await db.Database
                .SqlQuery<int>($"""
                    insert into assessment.spot_quizzes (code, mcq_code, name, class_id, topic, restrict_to_class, created_by, created_at)
                    values ({code}, {quiz.McqCode}, {quiz.Name}, {quiz.ClassId}, {quiz.Topic}, {quiz.RestrictToClass}::smallint, {quiz.CreatedBy}, {at})
                    on conflict (code) do nothing
                    returning id as "Value"
                    """)
                .ToListAsync(ct);
            if (ids.Count == 1)
            {
                return ids[0];
            }
        }

        throw new InvalidOperationException("No free quiz code was found");
    }
}
