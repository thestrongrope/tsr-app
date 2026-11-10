using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Platform.Api;

namespace Tsr.Db.Tests;

/// <summary>platform's public read interfaces: the geo lookups a profile validates with, and the lookup labels a registration validates with.</summary>
public sealed class PlatformReadsTests
{
    private WebApplicationFactory<Program> factory = null!;

    [OneTimeSetUp]
    public async Task StartAsync()
    {
        factory = TestApi.Create();
        var fixtures = await File.ReadAllTextAsync(Path.Combine(TestDatabase.RepoRoot(), "db", "synthetic", "geo-fixtures.sql"));
        await TestDatabase.ExecuteAsync("set search_path = platform, public;\n" + fixtures);
    }

    [OneTimeTearDown]
    public void Stop() => factory.Dispose();

    [Test]
    public async Task The_country_list_is_loaded()
    {
        Assert.That(await WithScopeAsync(s => s.GetRequiredService<Geo>().HasCountriesAsync(CancellationToken.None)), Is.True);
    }

    [TestCase("switzerland")]
    [TestCase("  SWITZERLAND ")]
    public async Task A_country_is_found_by_name_ignoring_case_and_surrounding_space(string name)
    {
        var country = await WithScopeAsync(s => s.GetRequiredService<Geo>().CountryByNameAsync(name, CancellationToken.None));

        Assert.That(country, Is.EqualTo(new GeoCountryInfo("CH", "Switzerland", true, null)));
    }

    [Test]
    public async Task A_country_is_found_ignoring_accents_as_MariaDB_did()
    {
        var country = await WithScopeAsync(s => s.GetRequiredService<Geo>().CountryByNameAsync("cote d'ivoire", CancellationToken.None));

        Assert.That(country?.Code, Is.EqualTo("CI"));
    }

    [Test]
    public async Task A_country_carries_its_postal_code_pattern()
    {
        var country = await WithScopeAsync(s => s.GetRequiredService<Geo>().CountryByNameAsync("United Kingdom", CancellationToken.None));

        Assert.That(country?.PostalCodeRegex, Is.EqualTo("^[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}$"));
    }

    [Test]
    public async Task An_unknown_country_is_null()
    {
        Assert.That(await WithScopeAsync(s => s.GetRequiredService<Geo>().CountryByNameAsync("Atlantis", CancellationToken.None)), Is.Null);
    }

    [Test]
    public async Task A_postal_code_gives_its_state_and_suggested_city_trimmed_and_upper_cased()
    {
        var place = await WithScopeAsync(s => s.GetRequiredService<Geo>().ByPostalCodeAsync(" ch ", " 8001 ", CancellationToken.None));

        Assert.That(place, Is.EqualTo(new GeoPlace("Zürich", "Zürich")));
    }

    [Test]
    public async Task A_full_code_with_a_space_falls_back_to_the_part_before_the_space()
    {
        var place = await WithScopeAsync(s => s.GetRequiredService<Geo>().ByPostalCodeAsync("GB", "sw1a 1aa", CancellationToken.None));

        Assert.That(place, Is.EqualTo(new GeoPlace("Westminster", "England")));
    }

    [Test]
    public async Task A_code_of_exactly_zero_is_never_looked_up()
    {
        Assert.That(await WithScopeAsync(s => s.GetRequiredService<Geo>().ByPostalCodeAsync("CH", "0", CancellationToken.None)), Is.Null);
    }

    [Test]
    public async Task From_a_country_name_the_place_needs_a_country_with_postal_data()
    {
        var geo = (IServiceProvider s) => s.GetRequiredService<Geo>();

        Assert.That(await WithScopeAsync(s => geo(s).FromPostalCodeAsync("switzerland", "8001", CancellationToken.None)), Is.EqualTo(new GeoPlace("Zürich", "Zürich")));
        Assert.That(await WithScopeAsync(s => geo(s).FromPostalCodeAsync("Colombia", "8001", CancellationToken.None)), Is.Null);
        Assert.That(await WithScopeAsync(s => geo(s).FromPostalCodeAsync("Atlantis", "8001", CancellationToken.None)), Is.Null);
    }

    [Test]
    public async Task Lookup_labels_come_in_display_order()
    {
        var labels = await WithScopeAsync(s => s.GetRequiredService<Lookups>().LabelsAsync("education", CancellationToken.None));

        Assert.That(labels, Has.Count.EqualTo(8));
        Assert.That(labels[0], Is.EqualTo("Doctorate (PhD / DPhil)"));
        Assert.That(labels[7], Is.EqualTo("Undergraduate (up to Grade 14)"));
    }

    [Test]
    public async Task An_inactive_option_is_not_offered()
    {
        await TestDatabase.ExecuteAsync("update platform.lookups set is_active = false where type = 'role_level' and sort_order = 70");
        try
        {
            var labels = await WithScopeAsync(s => s.GetRequiredService<Lookups>().LabelsAsync("role_level", CancellationToken.None));

            Assert.That(labels, Has.Count.EqualTo(6));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("update platform.lookups set is_active = true where type = 'role_level'");
        }
    }

    [Test]
    public async Task An_unseeded_type_throws_instead_of_returning_an_empty_list()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => WithScopeAsync(s => s.GetRequiredService<Lookups>().LabelsAsync("no_such_type", CancellationToken.None)));
    }

    private async Task<T> WithScopeAsync<T>(Func<IServiceProvider, Task<T>> action)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        return await action(scope.ServiceProvider);
    }
}
