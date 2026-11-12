using Npgsql;

namespace Tsr.Assessment.Api.Domain;

/// <summary>The unique index that makes a second set of answers for one member and question impossible (online or entered offline), and how to tell its violation.</summary>
internal static class DuplicateAnswer
{
    public const string UniqueIndex = "spot_quiz_responses_question_token";

    public static bool IsViolation(Exception e) =>
        e is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation, ConstraintName: UniqueIndex }
        || e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation, ConstraintName: UniqueIndex };
}
