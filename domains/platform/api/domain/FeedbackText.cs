using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// The text of one feedback message: trimmed, 1 to 2000 characters. Characters are Unicode code
/// points, exactly as tsr-account's FeedbackModel counts them (mb_strlen), so both
/// implementations accept and refuse the same messages (an Arabic mark counts as one).
/// </summary>
internal sealed record FeedbackText
{
    public const int MaxLength = 2000;

    private FeedbackText(string value) => Value = value;

    public string Value { get; }

    public static Result<FeedbackText> Create(string? raw)
    {
        var text = raw?.Trim() ?? string.Empty;
        var length = text.EnumerateRunes().Count();
        if (length == 0)
        {
            return Result.Fail<FeedbackText>("text is required");
        }

        if (length > MaxLength)
        {
            return Result.Fail<FeedbackText>("text must be at most " + MaxLength + " characters");
        }

        return Result.Ok<FeedbackText>(new FeedbackText(text));
    }
}
