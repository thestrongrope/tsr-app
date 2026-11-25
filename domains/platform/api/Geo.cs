using Tsr.Shared.Api;
using Microsoft.Extensions.Logging;
using Npgsql;
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
    private readonly NpgsqlDataSource _source;
    private readonly ILogger<Geo> _logger;

    internal Geo(NpgsqlDataSource source, ILogger<Geo> logger)
    {
        _source = source;
        _logger = logger;
    }

    /// <summary>Is the country list loaded? Without it nothing about a country can be checked.</summary>
    public Task<bool> HasCountriesAsync(CancellationToken ct) =>
        GeoTables.OrEmptyAsync(async () => await _source.ScalarAsync<bool>($"select exists (select 1 from platform.geo_countries)", ct) ?? false, false, _logger);

    /// <summary>The country for a name (trimmed; case and accents do not matter), or null.</summary>
    public async Task<GeoCountryInfo?> CountryByNameAsync(string name, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(name);
        var wanted = PhpText.Trim(name);
        if (wanted.Length == 0 || !GeoLookup.CanMatchStoredText(wanted))
        {
            return null;
        }

        return await GeoTables.OrEmptyAsync(() => FindCountryAsync(wanted, ct), null, _logger);
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

    private async Task<GeoCountryInfo?> FindCountryAsync(string wanted, CancellationToken ct)
    {
        // The name column has the geo collation (case and accents ignored), so a plain comparison finds "Zürich" for "zurich".
        var rows = await _source.ListAsync(
            $"""
            select c.code::text as "Code", c.name as "Name", c.has_postal_codes as "HasPostalCodes", c.postal_code_regex::text as "PostalCodeRegex"
            from platform.geo_countries c
            where c.name = {wanted}
            order by c.code
            limit 1
            """,
            row => new GeoCountryInfo(row.Text("Code"), row.Text("Name"), row.Bool("HasPostalCodes"), row.TextOrNull("PostalCodeRegex")),
            ct);
        return rows.FirstOrDefault();
    }

    private async Task<GeoPlace?> FindAsync(string country, IReadOnlyList<string> tries, CancellationToken ct)
    {
        foreach (var attempt in tries)
        {
            var rows = await _source.ListAsync(
                $"""
                select p.city::text as "City", p.state::text as "State"
                from platform.geo_postal_codes p
                where p.country_code = {country}::citext and p.postal_code = {attempt}
                limit 1
                """,
                row => new GeoPlace(row.TextOrNull("City"), row.TextOrNull("State")),
                ct);
            if (rows.Count > 0)
            {
                return rows[0];
            }
        }

        return null;
    }
}
