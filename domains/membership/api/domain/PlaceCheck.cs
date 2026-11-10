using Tsr.Platform.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>The place a profile holds: country, state, city and postal code as text (PHP casts null to empty).</summary>
internal sealed record PlaceFacts(string Country, string State, string City, string Zip);

/// <summary>
/// PHP's <c>LocationModel::check()</c> and the postal code override of PATCH /me (routes/users.php). Only a value that differs
/// from the stored one (compared trimmed) is checked, so old data and a client that sends every field keep saving. The first problem
/// wins: state, city, country, then postal code. Reads the geo tables through platform's <see cref="Geo"/>.
/// </summary>
internal sealed class PlaceCheck(Geo geo)
{
    /// <summary>The message of the first problem, or null when the place is acceptable.</summary>
    public async Task<string?> ProblemAsync(PlaceFacts stored, PlaceFacts after, CancellationToken ct)
    {
        if (Changed(stored.State, after.State) && PlaceRules.ContainsDigit(after.State))
        {
            return PlaceRules.StateHasNumbers;
        }

        if (Changed(stored.City, after.City) && PlaceRules.ContainsDigit(after.City))
        {
            return PlaceRules.CityHasNumbers;
        }

        var countryName = PhpText.Trim(after.Country);
        var country = countryName.Length == 0 ? null : await geo.CountryByNameAsync(countryName, ct);
        if (countryName.Length > 0 && Changed(stored.Country, after.Country) && country is null && await geo.HasCountriesAsync(ct))
        {
            return PlaceRules.CountryNotInList;
        }

        var zip = PhpText.Trim(after.Zip);
        if (zip.Length > 0 && Changed(stored.Zip, zip) && await LooksLikePersonalDataAsync(zip, country, ct))
        {
            return PlaceRules.NotAPostalCode;
        }

        return null;
    }

    /// <summary>
    /// The state and city the postal code gives, when the code or the country changed to a non-empty code we hold. PHP's <c>!empty()</c>
    /// drops an empty value and the text "0".
    /// </summary>
    public async Task<(string? State, string? City)> FromPostalCodeAsync(PlaceFacts stored, PlaceFacts after, bool zipSent, bool countrySent, CancellationToken ct)
    {
        var changed = after.Zip != stored.Zip || after.Country != stored.Country;
        if (PhpText.Trim(after.Zip).Length == 0 || !(zipSent || countrySent) || !changed)
        {
            return (null, null);
        }

        var found = await geo.FromPostalCodeAsync(after.Country, after.Zip, ct);
        return (Present(found?.State), Present(found?.City));
    }

    private static bool Changed(string stored, string value) => PhpText.Trim(stored) != PhpText.Trim(value);

    private static string? Present(string? value) => string.IsNullOrEmpty(value) || value == "0" ? null : value;

    private async Task<bool> LooksLikePersonalDataAsync(string zip, GeoCountryInfo? country, CancellationToken ct)
    {
        var held = country is { HasPostalCodes: true } && await geo.ByPostalCodeAsync(country.Code, zip, ct) is not null;
        return PlaceRules.LooksLikePersonalData(zip, country, held);
    }
}
