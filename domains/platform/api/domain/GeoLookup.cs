using System.Globalization;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;

namespace Tsr.Platform.Api.Domain;

/// <summary>The rules of tsr-account's LocationModel and of the "text" cast that need no database.</summary>
internal static partial class GeoLookup
{
    /// <summary>
    /// The postal codes to try, in order: the code as given, then (when it holds a space) the part before the first
    /// space. Falsy values are dropped, as PHP's array_filter does: that includes a try of exactly "0".
    /// </summary>
    public static IReadOnlyList<string> PostalCodeTries(string code)
    {
        var tries = new List<string> { code };
        var space = code.IndexOf(' ', StringComparison.Ordinal);
        if (space >= 0)
        {
            tries.Add(code[..space]);
        }

        return tries.Where(t => t.Length > 0 && t != "0" && CanMatchStoredText(t)).ToList();
    }

    /// <summary>Stored geo text never holds a NUL (and PostgreSQL refuses one), so a value with a NUL matches nothing.</summary>
    public static bool CanMatchStoredText(string value) => !value.Contains('\0', StringComparison.Ordinal);

    /// <summary>
    /// The LIKE pattern for a prefix search with '|' as the escape character: '|', '%' and '_' in the
    /// query become literals, then a trailing '%'.
    /// </summary>
    public static string CityLikePattern(string query)
    {
        var pattern = new StringBuilder(query.Length + 8);
        foreach (var c in query)
        {
            if (c is '|' or '%' or '_')
            {
                pattern.Append('|');
            }

            pattern.Append(c);
        }

        return pattern.Append('%').ToString();
    }

    /// <summary>
    /// PHP's html_entity_decode(ENT_QUOTES | ENT_HTML5) for stored text (api_cast "text"), in one pass: a numeric reference
    /// is decoded when HTML5 allows that code point (so &#0; stays), a named one when .NET knows it (the HTML 4 names)
    /// or it is one of the common HTML5 upper-case aliases. HTML5-only names beyond those stay as written: a known,
    /// accepted difference (docs/specs/initial-build/phase-3a-notes.md).
    /// </summary>
    public static string DecodeEntities(string value) => value.Contains('&', StringComparison.Ordinal)
        ? EntityReference().Replace(value, DecodeOne)
        : value;

    private static string DecodeOne(Match match)
    {
        var name = match.Groups["name"].Value;
        if (name[0] != '#')
        {
            return NamedAliases.TryGetValue(name, out var alias) ? alias : WebUtility.HtmlDecode(match.Value);
        }

        var hex = name.Length > 1 && name[1] is 'x' or 'X';
        var digits = hex ? name[2..] : name[1..];
        var style = hex ? NumberStyles.AllowHexSpecifier : NumberStyles.None;
        if (!int.TryParse(digits, style, CultureInfo.InvariantCulture, out var codePoint) || !IsAllowedInHtml5(codePoint))
        {
            return match.Value;
        }

        return char.ConvertFromUtf32(codePoint);
    }

    /// <summary>PHP's unicode_cp_is_allowed for HTML5 documents.</summary>
    private static bool IsAllowedInHtml5(int cp) =>
        (cp >= 0x20 && cp <= 0x7E)
        || (cp >= 0x09 && cp <= 0x0D && cp != 0x0B)
        || (cp >= 0xA0 && cp <= 0xD7FF)
        || (cp >= 0xE000 && cp <= 0x10FFFF && (cp & 0xFFFF) < 0xFFFE && (cp < 0xFDD0 || cp > 0xFDEF));

    private static readonly Dictionary<string, string> NamedAliases = new(StringComparer.Ordinal)
    {
        ["AMP"] = "&",
        ["LT"] = "<",
        ["GT"] = ">",
        ["QUOT"] = "\"",
        ["COPY"] = "\u00a9",
        ["REG"] = "\u00ae",
    };

    [GeneratedRegex("&(?<name>#[0-9]{1,8}|#[xX][0-9a-fA-F]{1,8}|[A-Za-z][A-Za-z0-9]{1,31});", RegexOptions.None, 1000)]
    private static partial Regex EntityReference();
}
