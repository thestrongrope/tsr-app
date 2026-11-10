using System.Net;

namespace Tsr.Membership.Api.Domain;

/// <summary>PHP's string functions as the profile and registration rules use them. .NET's own differ (Unicode whitespace and case).</summary>
internal static class PhpText
{
    // trim()'s default set: space, tab, newline, carriage return, NUL, vertical tab.
    private static readonly char[] TrimChars = [' ', '\t', '\n', '\r', '\0', '\v'];

    public static string Trim(string value) => value.Trim(TrimChars);

    /// <summary>ucfirst: an ASCII first letter only.</summary>
    public static string UcFirst(string value) =>
        value.Length > 0 && value[0] is >= 'a' and <= 'z' ? char.ToUpperInvariant(value[0]) + value[1..] : value;

    /// <summary>mb_strlen: Unicode code points, not UTF-16 units.</summary>
    public static int CodePointCount(string value) => value.EnumerateRunes().Count();

    /// <summary>strtolower: ASCII letters only (PHP 8 ignores the locale).</summary>
    public static string LowerAscii(string value) =>
        string.Create(value.Length, value, static (span, source) =>
        {
            for (var i = 0; i < span.Length; i++)
            {
                var c = source[i];
                span[i] = c is >= 'A' and <= 'Z' ? (char)(c + 32) : c;
            }
        });

    /// <summary>
    /// html_entity_decode($v, ENT_QUOTES | ENT_HTML5): entities decoded once. .NET's decoder knows the HTML 4 names plus a few
    /// more; PHP knows all the HTML5 names, so an obscure name PHP decodes stays as text here (phase-3b-notes.md).
    /// </summary>
    public static string HtmlDecode(string value) => WebUtility.HtmlDecode(value);
}
