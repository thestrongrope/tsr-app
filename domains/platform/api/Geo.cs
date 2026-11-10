using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Tsr.Platform.Api.Domain;

namespace Tsr.Platform.Api;

/// <summary>A country of the geo list. <c>PostalCodeRegex</c> is the pattern of the country's own postal codes, or null.</summary>
public sealed record GeoCountryInfo(string Code, string Name, bool HasPostalCodes, string? PostalCodeRegex);

/// <summary>What a postal code suggests: a city (approximate) and a state. Either may be null.</summary>
public sealed record GeoPlace(string? City, string? State);

/// <summary>
/// The module's public read interface for the geo tables (PHP's <c>LocationModel</c>): the lookups the profile and the
/// registration form validate with, and the one the postal code slice answers from. Like PHP, a missing geo table answers
/// "nothing" (logged), so a profile can always be saved as plain text; any other database error is thrown.
/// </summary>
public sealed class Geo
{
    private readonly PlatformContext _db;
    private readonly ILogger<Geo> _logger;

    internal Geo(PlatformContext db, ILogger<Geo> logger)
    {
        _db = db;
        _logger = logger;
    }

    /// <summary>Is the country list loaded? Without it nothing about a country can be checked.</summary>
    public Task<bool> HasCountriesAsync(CancellationToken ct) =>
        GeoTables.OrEmptyAsync(() => _db.GeoCountries.AnyAsync(ct), false, _logger);

    /// <summary>The country for a name (trimmed; case and accents do not matter), or null.</summary>
    public async Task<GeoCountryInfo?> CountryByNameAsync(string name, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(name);
        var wanted = PhpText.Trim(name);
        if (wanted.Length == 0 || !GeoLookup.CanMatchStoredText(wanted))
        {
            return null;
        }

        var row = await GeoTables.OrEmptyAsync(
            () => _db.GeoCountries.AsNoTracking().Where(c => c.Name == wanted).OrderBy(c => c.Code).FirstOrDefaultAsync(ct),
            null,
            _logger);
        return row is null ? null : new GeoCountryInfo(row.Code, row.Name, row.HasPostalCodes, row.PostalCodeRegex);
    }

    /// <summary>
    /// The place for a postal code of the country with this two-letter code: the code (trimmed, upper-cased) is tried whole, then
    /// by the part before its first space. Null when none is held. A code of exactly "0" is never looked up (PHP's falsy filter).
    /// </summary>
    public async Task<GeoPlace?> ByPostalCodeAsync(string countryCode, string postalCode, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(countryCode);
        ArgumentNullException.ThrowIfNull(postalCode);
        var country = PhpText.ToUpperAscii(PhpText.Trim(countryCode));
        if (!GeoLookup.CanMatchStoredText(country))
        {
            return null;
        }

        var tries = GeoLookup.PostalCodeTries(PhpText.ToUpperAscii(PhpText.Trim(postalCode)));
        return await GeoTables.OrEmptyAsync(() => FindAsync(country, tries, ct), null, _logger);
    }

    /// <summary>The place for a postal code in the named country, when that country has postal data and the code is held. Null otherwise.</summary>
    public async Task<GeoPlace?> FromPostalCodeAsync(string countryName, string postalCode, CancellationToken ct)
    {
        var country = await CountryByNameAsync(countryName, ct);
        return country is { HasPostalCodes: true } ? await ByPostalCodeAsync(country.Code, postalCode, ct) : null;
    }

    private async Task<GeoPlace?> FindAsync(string country, IReadOnlyList<string> tries, CancellationToken ct)
    {
        foreach (var attempt in tries)
        {
            var row = await _db.GeoPostalCodes.AsNoTracking()
                .Where(p => p.CountryCode == country && p.PostalCode == attempt)
                .FirstOrDefaultAsync(ct);
            if (row is not null)
            {
                return new GeoPlace(row.City, row.State);
            }
        }

        return null;
    }
}
