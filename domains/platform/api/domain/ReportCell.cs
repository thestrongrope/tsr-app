using System.Globalization;

namespace Tsr.Platform.Api.Domain;

/// <summary>What a report value is: PHP wrote an int or float as a number and everything else as text (<c>(string)</c> of it).</summary>
internal static class ReportCell
{
    public static bool IsNumber(object? value) =>
        value is sbyte or byte or short or ushort or int or uint or long or ulong or decimal
        || (value is float or double && double.IsFinite(Convert.ToDouble(value, CultureInfo.InvariantCulture)));

    /// <summary>PHP's <c>(string) $value</c>: null is empty, true is "1", false is empty, numbers use no culture.</summary>
    public static string Text(object? value) => value switch
    {
        null => string.Empty,
        bool flag => flag ? "1" : string.Empty,
        string text => text,
        IFormattable formattable => formattable.ToString(null, CultureInfo.InvariantCulture),
        _ => value.ToString() ?? string.Empty,
    };
}
