namespace Tsr.Assessment.Api;

// One class per PHP table of this domain, columns in PHP's order. Class, level, language, topic and member ("token") references are plain integers.

/// <summary>A quiz a teacher publishes for a class (PHP <c>spot_quizzes</c>). <c>Code</c> is the unique code members enter.</summary>
internal sealed class SpotQuiz
{
    public int Id { get; set; }

    public string? Code { get; set; }

    public string? McqCode { get; set; }

    public int? LanguageId { get; set; }

    public int? LevelId { get; set; }

    public int? TopicId { get; set; }

    public int? SubjectId { get; set; }

    public int? LessonId { get; set; }

    public string? Name { get; set; }

    public int? ClassId { get; set; }

    public string? Topic { get; set; }

    public int? Session { get; set; }

    public short RestrictToClass { get; set; } = 1;

    public DateTimeOffset? PublishedAt { get; set; }

    public int? PublishedBy { get; set; }

    public DateTimeOffset? DeactivatedAt { get; set; }

    public int? DeactivatedBy { get; set; }

    public int? CreatedBy { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public int? ModifiedBy { get; set; }

    public DateTimeOffset? ModifiedAt { get; set; }
}

/// <summary>A question of a spot quiz (PHP <c>spot_quiz_questions</c>). <c>Answer</c> is the number of the right option.</summary>
internal sealed class SpotQuizQuestion
{
    public int Id { get; set; }

    public int? SpotQuizId { get; set; }

    public bool? IsArabic { get; set; }

    public string? Question { get; set; }

    public string? Option1 { get; set; }

    public string? Option2 { get; set; }

    public string? Option3 { get; set; }

    public string? Option4 { get; set; }

    public string? Option5 { get; set; }

    public int? Answer { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public string? OptionDisplayOrder { get; set; }
}

/// <summary>A member's submission of a spot quiz (PHP <c>spot_quiz_submissions</c>).</summary>
internal sealed class SpotQuizSubmission
{
    public int Id { get; set; }

    public int? SpotQuizId { get; set; }

    public int? Token { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? ModifiedAt { get; set; }
}

/// <summary>A member's answer to one question (PHP <c>spot_quiz_responses</c>); one per question and member. <c>IsCorrect</c> is PHP's tinyint flag.</summary>
internal sealed class SpotQuizResponse
{
    public int Id { get; set; }

    public int? SpotQuizId { get; set; }

    public int SpotQuizQuestionId { get; set; }

    public int? Token { get; set; }

    public string? Response { get; set; }

    public string CorrectResponse { get; set; } = string.Empty;

    public short? IsCorrect { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>A set of standard questions (PHP <c>standard_mcqs</c>), found by <c>Code</c>.</summary>
internal sealed class StandardMcq
{
    public int Id { get; set; }

    public string Code { get; set; } = string.Empty;

    public int LanguageId { get; set; }

    public int LevelId { get; set; }

    public string Topic { get; set; } = string.Empty;

    public string Subject { get; set; } = string.Empty;

    public string Lesson { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public int? SortOrder { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public int? CreatedBy { get; set; }

    public DateTimeOffset? ModifiedAt { get; set; }

    public int? ModifiedBy { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int? DeletedBy { get; set; }
}

/// <summary>A question of a standard MCQ set (PHP <c>standard_mcq_questions</c>), tied to its set by <c>McqCode</c>.</summary>
internal sealed class StandardMcqQuestion
{
    public int Id { get; set; }

    public string McqCode { get; set; } = string.Empty;

    public string Question { get; set; } = string.Empty;

    public string Answer { get; set; } = string.Empty;

    public string Option1 { get; set; } = string.Empty;

    public string? Option2 { get; set; }

    public string? Option3 { get; set; }

    public string? ReasonOption1 { get; set; }

    public string? ReasonOption2 { get; set; }

    public string? ReasonOption3 { get; set; }

    public int? SortOrder { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public int? CreatedBy { get; set; }

    public DateTimeOffset? ModifiedAt { get; set; }

    public int? ModifiedBy { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int? DeletedBy { get; set; }
}

/// <summary>A yearly quiz competition (PHP <c>quiz_campaigns</c>): its registration and quiz windows. The dates are PHP's <c>datetime</c>, read as UTC.</summary>
internal sealed class QuizCampaign
{
    public int Id { get; set; }

    public string? Name { get; set; }

    public int? Year { get; set; }

    public DateTimeOffset? RegistrationsStart { get; set; }

    public DateTimeOffset? RegistrationsEnd { get; set; }

    public DateTimeOffset? QuizStart { get; set; }

    public DateTimeOffset? QuizDisabled { get; set; }

    public DateTimeOffset? QuizEnd { get; set; }

    public int? Outof { get; set; }

    public int? Active { get; set; }
}

/// <summary>
/// One document of the quiz competition's state (replaces PHP's JSON files under state/): <c>settings</c> (the settings sheet read), <c>participants</c>, <c>quiz_day</c>, <c>timestamps</c>, <c>scoreboard</c>, <c>winners</c>,
/// and <c>winners_replaced</c> (the append-only record of replaced winners). The documents keep PHP's JSON shape. Member data lives here and in the responses PHP returns, never in logs or events.
/// </summary>
internal sealed class QuizState
{
    public string Name { get; set; } = string.Empty;

    public string Document { get; set; } = "null";

    public DateTimeOffset UpdatedAt { get; set; }
}
