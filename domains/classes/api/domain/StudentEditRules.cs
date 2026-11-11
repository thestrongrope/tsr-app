using System.Text.RegularExpressions;

namespace Tsr.Classes.Api.Domain;

/// <summary>PHP <c>ClassStudentsModel::studentEmailError</c> and the name rule of <c>updateStudentInClass</c>.</summary>
internal static partial class StudentEditRules
{
    private const int MaxLocalPart = 64;
    private const int MaxLength = 254; // PHP's filter refuses a longer address

    // PHP's FILTER_VALIDATE_EMAIL, approximated: a dot-atom local part of at most 64 characters, then a domain of at least two dot-separated labels.
    [GeneratedRegex(@"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$", RegexOptions.CultureInvariant, matchTimeoutMilliseconds: 200)]
    private static partial Regex Address();

    [GeneratedRegex(@"^(\d+)@thestrongrope\.com$", RegexOptions.CultureInvariant | RegexOptions.IgnoreCase, matchTimeoutMilliseconds: 200)]
    private static partial Regex TokenAddress();

    /// <summary>The refusal for an edited (already trimmed) email, or null when it is acceptable. A blank email means "not changing it".</summary>
    public static string? EmailError(int token, string email)
    {
        if (email.Length == 0)
        {
            return null;
        }

        var placeholder = TokenAddress().Match(email);
        if (placeholder.Success && !(long.TryParse(placeholder.Groups[1].Value, out var named) && named == token))
        {
            return $"Email can only be {token}@thestrongrope.com (your token) or a real email address. Cannot use other token emails.";
        }

        var at = email.IndexOf('@', StringComparison.Ordinal);
        if (email.Length > MaxLength || at < 1 || at > MaxLocalPart || !Address().IsMatch(email))
        {
            return "Please provide a valid email address";
        }

        return null;
    }

    /// <summary>PHP's <c>!empty($name)</c>: "" and "0" are not written. Null when the name is left alone.</summary>
    public static string? NameToWrite(string name) => name is "" or "0" ? null : name;
}
