using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>The month parameters of the reports (PHP <c>api_reports_month_ok</c> and <c>api_reports_month_key</c>), 'MM-YYYY', in PHP's words.</summary>
internal static partial class ReportMonths
{
    public const string NotMonths = "from and to must be months as MM-YYYY, from not after to";
    public const string TooLong = "The range can cover at most 12 months";

    // [0-9], not \d: .NET's \d also matches other scripts' digits. $ also matches before a final newline, as PHP's does.
    [GeneratedRegex("^(0[1-9]|1[0-2])-(20[0-9][0-9])$")]
    private static partial Regex Pattern();

    /// <summary>PHP <c>(string) ($_GET[name] ?? default)</c>: the last value given, null when it is absent (the caller supplies the default).</summary>
    public static string? Param(HttpContext context, string name)
    {
        ArgumentNullException.ThrowIfNull(context);
        var values = context.Request.Query[name];
        return values.Count == 0 ? null : values[^1] ?? string.Empty;
    }

    public static bool IsMonth(string month) => Pattern().IsMatch(month);

    /// <summary>PHP: year times 12 plus month, from <c>explode('-')</c> and (int) casts.</summary>
    public static int Key(string month)
    {
        var parts = month.Split('-');
        return (int)(PhpValue.IntOfText(parts[1]) * 12 + PhpValue.IntOfText(parts[0]));
    }

    /// <summary>The refusal for the two months, or null: both real, from not after to, and (where the report limits it) at most twelve months.</summary>
    public static string? Check(string from, string to, bool limitToTwelve)
    {
        if (!IsMonth(from) || !IsMonth(to) || Key(from) > Key(to))
        {
            return NotMonths;
        }

        return limitToTwelve && Key(to) - Key(from) > 11 ? TooLong : null;
    }
}
