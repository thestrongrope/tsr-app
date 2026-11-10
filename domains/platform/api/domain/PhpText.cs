namespace Tsr.Platform.Api.Domain;

/// <summary>
/// PHP's string functions as the geo rules use them. .NET's own Trim() and ToUpperInvariant() differ
/// (Unicode whitespace, non-ASCII letters), and the geo rules must accept and refuse the same input as the PHP API.
/// </summary>
internal static class PhpText
{
    // trim()'s default set: space, tab, newline, carriage return, NUL, vertical tab.
    private static readonly char[] TrimChars = [' ', '\t', '\n', '\r', '\0', '\v'];

    public static string Trim(string value) => value.Trim(TrimChars);

    /// <summary>strtoupper: ASCII letters only (PHP 8 ignores the locale).</summary>
    public static string ToUpperAscii(string value)
    {
        return string.Create(value.Length, value, static (span, source) =>
        {
            for (var i = 0; i < span.Length; i++)
            {
                var c = source[i];
                span[i] = c is >= 'a' and <= 'z' ? (char)(c - 32) : c;
            }
        });
    }

    /// <summary>mb_strlen: Unicode code points, not UTF-16 units.</summary>
    public static int CodePointCount(string value) => value.EnumerateRunes().Count();
}
