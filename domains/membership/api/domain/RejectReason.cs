using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>The reason of POST /registrations/{id}/reject (routes/registrations.php): trimmed, required, at most 500 characters.</summary>
internal static class RejectReason
{
    public const int MaxLength = 500;
    public const string Required = "reason is required, at most 500 characters";

    /// <summary>The trimmed reason, or null when it is missing, blank, too long (code points, as mb_strlen) or holds a NUL byte (PostgreSQL text cannot; PHP stores it: a recorded deviation).</summary>
    public static string? Parse(string? typed)
    {
        var reason = PhpText.Trim(typed ?? string.Empty);
        if (reason.Length == 0 || reason.Contains('\0', StringComparison.Ordinal) || PhpText.CodePointCount(reason) > MaxLength)
        {
            return null;
        }

        return reason;
    }
}
