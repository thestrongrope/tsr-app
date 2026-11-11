using System.Globalization;
using System.Text;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>PHP <c>ClassesModel::deactivate</c>'s checks on the request, in PHP's order and words, and the removal reason it writes on every student.</summary>
internal static class DeactivationRules
{
    private const int MaxReasonBytes = 300;
    private const string StudentPrefix = "Class deactivated: ";

    internal sealed record Input(string Type, DateOnly EffectiveDate, string Reason);

    public static Result<Input> Parse(string type, string date, string reason)
    {
        if (type is not ("completed" or "shutdown"))
        {
            return Result.Fail<Input>("Invalid type; expected completed or shutdown");
        }

        if (!DateOnly.TryParseExact(date, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var effective))
        {
            return Result.Fail<Input>("Invalid effective date; expected YYYY-MM-DD");
        }

        var trimmed = PhpText.Trim(reason);
        if (trimmed.Length == 0)
        {
            return Result.Fail<Input>("Reason is required");
        }

        if (Encoding.UTF8.GetByteCount(trimmed) > MaxReasonBytes)
        {
            return Result.Fail<Input>("Reason must be 300 characters or fewer");
        }

        return Result.Ok(new Input(type, effective, trimmed));
    }

    /// <summary>"Class deactivated: " and the reason, cut to 300 bytes (PHP's substr; here never inside a character).</summary>
    public static string StudentReason(string reason)
    {
        var full = StudentPrefix + reason;
        if (Encoding.UTF8.GetByteCount(full) <= MaxReasonBytes)
        {
            return full;
        }

        var kept = new StringBuilder();
        var bytes = 0;
        foreach (var rune in full.EnumerateRunes())
        {
            bytes += rune.Utf8SequenceLength;
            if (bytes > MaxReasonBytes)
            {
                break;
            }

            kept.Append(rune.ToString().AsSpan());
        }

        return kept.ToString();
    }
}
