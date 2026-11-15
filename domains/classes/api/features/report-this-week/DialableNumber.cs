namespace Tsr.Classes.Api.Features.ReportThisWeek;

/// <summary>
/// A member's saved number as a dialer needs it: PHP <c>PhoneNumberModel::dialable</c> (models/phonenumber.php).
/// Members type their number as they know it, most without a country code, and their country as free text. A number with no code takes
/// the calling code of the member's own country. It is never assumed to be Indian: a number that cannot be completed is empty.
/// </summary>
internal static class DialableNumber
{
    /// <summary>Fewer digits than this is not a phone number.</summary>
    private const int MinDigits = 7;

    /// <summary>A number without a plus and longer than this already carries its code.</summary>
    private const int MaxLocalDigits = 10;

    /// <summary>A country name shorter than this must match whole, not as a prefix.</summary>
    private const int MinPrefixLength = 4;

    // PHP trim()'s characters.
    private static readonly char[] PhpSpace = [' ', '\t', '\n', '\r', '\0', '\v'];

    /// <summary>Calling code by country as members write it (lower case), in PHP's order: the first name a country starts with wins.</summary>
    private static readonly (string Name, string Code)[] CallingCodes =
    [
        ("india", "91"), ("pakistan", "92"), ("bangladesh", "880"),
        ("united states", "1"), ("usa", "1"), ("us", "1"), ("canada", "1"),
        ("united arab emirates", "971"), ("uae", "971"), ("oman", "968"), ("qatar", "974"),
        ("kuwait", "965"), ("bahrain", "973"), ("saudi arabia", "966"), ("iran", "98"), ("iraq", "964"),
        ("tanzania", "255"), ("kenya", "254"), ("uganda", "256"), ("zambia", "260"),
        ("angola", "244"), ("madagascar", "261"), ("south africa", "27"), ("reunion", "262"),
        ("united kingdom", "44"), ("uk", "44"), ("ireland", "353"), ("france", "33"),
        ("germany", "49"), ("italy", "39"), ("the netherlands", "31"), ("netherlands", "31"),
        ("belgium", "32"), ("switzerland", "41"), ("denmark", "45"), ("sweden", "46"),
        ("australia", "61"), ("singapore", "65"), ("thailand", "66"), ("indonesia", "62"),
        ("philippines", "63"), ("south korea", "82"), ("hong kong", "852"),
    ];

    /// <summary>The number in full, a plus then digits, or empty when it cannot be dialled: too short, or saved without a code by a member whose country is unknown.</summary>
    public static string Of(string? mobile, string? country)
    {
        var saved = (mobile ?? string.Empty).Trim(PhpSpace);
        var digits = string.Concat(saved.Where(char.IsAsciiDigit));
        if (saved.StartsWith('+'))
        {
            return digits.Length >= MinDigits ? "+" + digits : string.Empty;
        }

        // A trunk 0, or the 00 that stands for a plus.
        digits = digits.TrimStart('0');
        if (digits.Length < MinDigits)
        {
            return string.Empty;
        }

        if (digits.Length > MaxLocalDigits)
        {
            return "+" + digits;
        }

        var code = CallingCode(country);
        return code is null ? string.Empty : "+" + code + digits;
    }

    /// <summary>The calling code of a country as a member wrote it, or null if unknown. "India Mumbai", "United States of America": the country, then more.</summary>
    private static string? CallingCode(string? country)
    {
        // PHP strtolower: the letters A to Z only.
        var written = (country ?? string.Empty).Trim(PhpSpace).ToLowerInvariant();
        if (written.Length == 0)
        {
            return null;
        }

        foreach (var (name, code) in CallingCodes)
        {
            if (written == name)
            {
                return code;
            }
        }

        foreach (var (name, code) in CallingCodes)
        {
            if (name.Length >= MinPrefixLength && written.StartsWith(name, StringComparison.Ordinal))
            {
                return code;
            }
        }

        return null;
    }
}
