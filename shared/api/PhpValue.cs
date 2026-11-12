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

    /// <summary>filter_var($value, FILTER_VALIDATE_BOOLEAN) cast to bool, after PHP's <c>?? default</c> (a missing or null value takes the default). Only 1, true, on and yes (any case, trimmed; a number only when it equals 1) are true.</summary>
    public static bool Truthy(JsonElement value, bool whenMissing) => value.ValueKind switch
    {
        JsonValueKind.Undefined or JsonValueKind.Null => whenMissing,
        JsonValueKind.True => true,
        JsonValueKind.String => PhpText.LowerAscii(PhpText.Trim(value.GetString() ?? string.Empty)) is "1" or "true" or "on" or "yes",
        JsonValueKind.Number => value.TryGetDouble(out var number) && number == 1.0,
        _ => false,
    };

    /// <summary>PHP <c>is_int()</c> of a decoded JSON value: a number written without a fraction or exponent that fits 64 bits (<c>1.0</c> and <c>1e2</c> decode to floats).</summary>
    public static bool IsInt(JsonElement value, out long number)
    {
        number = 0;
        if (value.ValueKind != JsonValueKind.Number || !value.TryGetInt64(out number))
        {
            return false;
        }

        var raw = value.GetRawText();
        return !raw.Contains('.', StringComparison.Ordinal) && !raw.Contains('e', StringComparison.OrdinalIgnoreCase);
    }

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
