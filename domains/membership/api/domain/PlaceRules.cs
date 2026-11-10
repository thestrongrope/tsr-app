using System.Text;
using System.Text.RegularExpressions;
using Tsr.Platform.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>PHP's <c>LocationModel::check()</c> rules that need no database: digits in a place name, and what looks like personal data in a postal code field.</summary>
internal static class PlaceRules
{
    public const string StateHasNumbers = "State cannot contain numbers";
    public const string CityHasNumbers = "City cannot contain numbers";
    public const string CountryNotInList = "Choose your country from the list";
    public const string NotAPostalCode = "That does not look like a postal code. Leave it empty if you do not have one.";

    private const int PhoneDigits = 10;

    // The regex comes from the database: a pattern that backtracks badly must not hold a request.
    private static readonly TimeSpan RegexTimeout = TimeSpan.FromMilliseconds(250);

    /// <summary>preg_match('/\d/u'): any Unicode decimal digit (PHP's /u turns on Unicode properties).</summary>
    public static bool ContainsDigit(string value) => value.EnumerateRunes().Any(Rune.IsDigit);

    /// <summary>
    /// An email address, or ten or more ASCII digits that are neither a postal code we hold nor shaped like the country's own codes.
    /// <paramref name="country"/> is the row for the typed country name (null when none matched).
    /// </summary>
    public static bool LooksLikePersonalData(string zip, GeoCountryInfo? country, bool isHeldPostalCode)
    {
        if (zip.Contains('@', StringComparison.Ordinal))
        {
            return true;
        }

        if (zip.Count(c => c is >= '0' and <= '9') < PhoneDigits)
        {
            return false;
        }

        if (country is null)
        {
            return true;
        }

        if (country.HasPostalCodes && isHeldPostalCode)
        {
            return false;
        }

        return !MatchesCountryRegex(country.PostalCodeRegex, zip);
    }

    // PHP: preg_match('~' . str_replace('~', '\~', $regex) . '~i', $zip) === 1, errors silenced (a broken pattern is "no match").
    private static bool MatchesCountryRegex(string? pattern, string zip)
    {
        if (string.IsNullOrEmpty(pattern))
        {
            return false;
        }

        try
        {
            return Regex.IsMatch(zip, pattern.Replace("~", "\\~", StringComparison.Ordinal), RegexOptions.IgnoreCase | RegexOptions.CultureInvariant, RegexTimeout);
        }
        catch (Exception e) when (e is ArgumentException or RegexMatchTimeoutException)
        {
            return false;
        }
    }
}
