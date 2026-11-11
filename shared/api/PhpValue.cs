using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Tsr.Shared.Api;

/// <summary>
/// PHP's loose conversions of a decoded JSON value: what <c>(string)</c>, <c>(int)</c> and <c>is_numeric</c> make of it. A missing
/// value (<c>default</c>) behaves as null. The patterns spell out ASCII classes: PCRE and PHP's number parser are ASCII, .NET's
/// <c>\d</c> and <c>\s</c> are not.
/// </summary>
public static partial class PhpValue
{
    private const string Blank = " \t\n\r\v\f";

    [GeneratedRegex(@"\A[ \t\n\r\v\f]*([+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?)", RegexOptions.CultureInvariant)]
    private static partial Regex NumericPrefix();

    [GeneratedRegex(@"\A[ \t\n\r\v\f]*[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?[ \t\n\r\v\f]*\z", RegexOptions.CultureInvariant)]
    private static partial Regex WholeNumber();

    /// <summary>(string): null and a missing value are empty, true is "1", false is empty, an array is "Array".</summary>
    public static string Text(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.String => value.GetString() ?? string.Empty,
        JsonValueKind.Number => value.TryGetInt64(out var whole)
            ? whole.ToString(CultureInfo.InvariantCulture)
            : value.GetDouble().ToString("G14", CultureInfo.InvariantCulture),
        JsonValueKind.True => "1",
        JsonValueKind.Array or JsonValueKind.Object => "Array",
        _ => string.Empty,
    };

    /// <summary>(int): a number truncates, text takes its numeric prefix, true is 1, an empty array is 0 and any other array 1.</summary>
    public static long ToInteger(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Number => value.TryGetInt64(out var whole) ? whole : Clamp(Math.Truncate(value.GetDouble())),
        JsonValueKind.String => IntOfText(value.GetString() ?? string.Empty),
        JsonValueKind.True => 1,
        JsonValueKind.Array => value.GetArrayLength() > 0 ? 1 : 0,
        JsonValueKind.Object => value.EnumerateObject().Any() ? 1 : 0,
        _ => 0,
    };

    /// <summary>(int) of text: the numeric prefix (after leading white space), 0 when there is none, clamped to the 64-bit range.</summary>
    public static long IntOfText(string value)
    {
        var match = NumericPrefix().Match(value);
        if (!match.Success)
        {
            return 0;
        }

        var prefix = match.Groups[1].Value;
        if (long.TryParse(prefix, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var whole))
        {
            return whole;
        }

        if (prefix.AsSpan().IndexOfAny('.', 'e', 'E') < 0)
        {
            return prefix[0] == '-' ? long.MinValue : long.MaxValue;
        }

        return Clamp(Math.Truncate(double.Parse(prefix, NumberStyles.Float, CultureInfo.InvariantCulture)));
    }

    /// <summary>is_numeric on text (PHP 8: leading and trailing white space allowed, no hex).</summary>
    public static bool IsNumeric(string value) => WholeNumber().IsMatch(value);

    private static long Clamp(double value) => value switch
    {
        >= 9.2233720368547758E18 => long.MaxValue,
        <= -9.2233720368547758E18 => long.MinValue,
        _ => (long)value,
    };
}
