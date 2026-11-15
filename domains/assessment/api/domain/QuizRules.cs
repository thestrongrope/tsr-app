using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The pure rules of taking a quiz, ported from PHP's McqModel (models/mcq.php): scoring, the correct option and the state of an MCQ link.
/// Scoring is PHP's <c>scoreResponse</c>: both sides trimmed with PHP's trim set, lower-cased, compared as text; nothing is decoded (no entities, no numeric match).
/// </summary>
internal static class QuizRules
{
    /// <summary>What <see cref="Resolve"/> needs of an MCQ that exists: its id, whether it is released (published) and whether it is deactivated.</summary>
    internal sealed record LinkFacts(int QuizId, bool Published, bool Deactivated);

    /// <summary>PHP resolveLink's answer: the state and, for open and attempted only, the quiz the app opens.</summary>
    internal sealed record LinkState(string State, int? QuizId);

    /// <summary>PHP isLinkCode: 1 to 32 ASCII letters and digits.</summary>
    public static bool IsLinkCode(string code) =>
        code.Length is >= 1 and <= 32 && code.All(c => c is (>= 'a' and <= 'z') or (>= 'A' and <= 'Z') or (>= '0' and <= '9'));

    /// <summary>PHP correctAnswerFor: option{answer}, the answer number defaulting to 1; no answer outside 1 to 5 and none when that option is empty.</summary>
    public static string? CorrectAnswerFor(int? answer, IReadOnlyList<string?> options)
    {
        var index = answer ?? 1;
        return index is < 1 or > 5 ? null : options[index - 1];
    }

    /// <summary>PHP scoreResponse. .NET's <c>ToLowerInvariant</c> stands for mb_strtolower (Arabic has no case; only the exotic full case mappings differ).</summary>
    public static bool Score(string? selected, string? correct)
    {
        if (selected is null || correct is null)
        {
            return false;
        }

        var left = PhpText.Trim(selected);
        var right = PhpText.Trim(correct);
        return left.Length > 0 && right.Length > 0 && string.Equals(left.ToLowerInvariant(), right.ToLowerInvariant(), StringComparison.Ordinal);
    }

    /// <summary>
    /// PHP resolveLink after the lookups: not_found (no such MCQ), not_eligible (not enrolled: nothing more is said), not_released (a draft), attempted (the member
    /// has answers, even if the MCQ is deactivated now), open, closed (deactivated, not answered).
    /// </summary>
    public static LinkState Resolve(LinkFacts? quiz, bool enrolled, bool attempted)
    {
        if (quiz is null)
        {
            return new LinkState("not_found", null);
        }

        if (!enrolled)
        {
            return new LinkState("not_eligible", null);
        }

        if (!quiz.Published)
        {
            return new LinkState("not_released", null);
        }

        if (attempted)
        {
            return new LinkState("attempted", quiz.QuizId);
        }

        return quiz.Deactivated ? new LinkState("closed", null) : new LinkState("open", quiz.QuizId);
    }
}
