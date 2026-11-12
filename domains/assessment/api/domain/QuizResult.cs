using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The result envelope the submit and my-score routes both send (PHP routes/mcq.php): <c>{total, answered, correct, percent, responses}</c> with one detail per answer.
/// <c>percent</c> is over the question count (unanswered questions count against the score); PHP sends the integer 0, not a float, when the quiz has no questions.
/// </summary>
internal static class QuizResult
{
    /// <summary>PHP api_quiz_result_spec: selected is an int (0 when not given), the texts are null when empty.</summary>
    internal sealed record Detail(int QuestionId, string? QuestionText, int Selected, string? SelectedText, string? CorrectText, int IsCorrect);

    internal sealed record Body(int Total, int Answered, int Correct, object Percent, IReadOnlyList<Detail> Responses);

    public static Body Of(int total, IReadOnlyList<Detail> details)
    {
        var correct = details.Count(d => d.IsCorrect == 1);
        return new Body(total, details.Count, correct, Percent(correct, total), details);
    }

    /// <summary>round(correct / total * 100, 2) as PHP sends it (a float), or the integer 0 when there are no questions.</summary>
    public static object Percent(int correct, int total) => total > 0 ? PhpFloat.Round(correct * 100m / total, 2) : 0;

    /// <summary>PHP api_cast 'str?': an empty text is null.</summary>
    public static string? TextOrNull(string? value) => string.IsNullOrEmpty(value) ? null : value;
}
