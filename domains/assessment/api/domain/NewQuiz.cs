using Microsoft.EntityFrameworkCore;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The one insert of a quiz row (create, copy a standard MCQ, copy between classes), with the code PHP's trigger gave it (<see cref="QuizCode"/>): drawn, checked with <c>not exists</c> inside the caller's transaction, drawn again
/// up to <see cref="MaxAttempts"/> times. PORTED AS PHP HAS IT: the check is racy exactly as PHP's trigger was (two inserts at the same moment can draw the same code) and there is no unique index on <c>code</c> in either schema;
/// adding one is a decision for the test phase. A quiz is never published by this insert.
/// </summary>
internal static class NewQuiz
{
    public const int MaxAttempts = 20;

    /// <summary>What a new quiz carries. <paramref name="McqCode"/> is the standard MCQ it was copied from (null otherwise): the column the copy reports read.</summary>
    internal sealed record Fields(int ClassId, string Name, string? Topic, string? McqCode, int RestrictToClass, int CreatedBy);

    public static async Task<int> InsertAsync(AssessmentContext db, Fields quiz, DateTimeOffset at, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(quiz);
        if (db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("A quiz is inserted inside the caller's transaction.");
        }

        for (var attempt = 0; attempt < MaxAttempts; attempt++)
        {
            var code = QuizCode.Generate();
            var taken = await db.Database
                .SqlQuery<bool>($"""select exists (select 1 from assessment.spot_quizzes where code = {code}::citext) as "Value" """)
                .SingleAsync(ct);
            if (taken)
            {
                continue;
            }

            var ids = await db.Database
                .SqlQuery<int>($"""
                    insert into assessment.spot_quizzes (code, mcq_code, name, class_id, topic, restrict_to_class, created_by, created_at)
                    values ({code}, {quiz.McqCode}, {quiz.Name}, {quiz.ClassId}, {quiz.Topic}, {quiz.RestrictToClass}::smallint, {quiz.CreatedBy}, {at})
                    returning id as "Value"
                    """)
                .ToListAsync(ct);
            return ids.Single();
        }

        throw new InvalidOperationException("No free quiz code was found");
    }
}
