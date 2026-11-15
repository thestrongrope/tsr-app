using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>PHP's <c>api_cast</c> for the field types the /admin routes use (lib/response.php): what a stored value becomes on the wire.</summary>
internal static class PhpCast
{
    /// <summary><c>text</c> (not nullable): HTML entities decoded; null or empty is the number 0, not an empty string.</summary>
    public static object Text(string? value) => string.IsNullOrEmpty(value) ? 0 : PhpText.HtmlDecode(value);

    /// <summary><c>text?</c>: HTML entities decoded; null or empty is null.</summary>
    public static string? TextOrNull(string? value) => string.IsNullOrEmpty(value) ? null : PhpText.HtmlDecode(value);

    /// <summary><c>str?</c>: null or empty is null.</summary>
    public static string? StrOrNull(string? value) => string.IsNullOrEmpty(value) ? null : value;

    /// <summary><c>str</c> (not nullable): null is an empty string.</summary>
    public static string Str(string? value) => value ?? string.Empty;
}
