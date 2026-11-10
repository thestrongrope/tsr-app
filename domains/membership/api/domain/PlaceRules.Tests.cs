using NUnit.Framework;
using Tsr.Membership.Api.Domain;
using Tsr.Platform.Api;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>The postal code and place name rules of LocationModel::check() that need no database.</summary>
public sealed class PlaceRulesTests
{
    private static readonly GeoCountryInfo Switzerland = new("CH", "Switzerland", true, null);
    private static readonly GeoCountryInfo Iran = new("IR", "Iran", false, @"^\d{10}$");

    [TestCase("ab3", true)]
    [TestCase("abc", false)]
    [TestCase("٣abc", true)]
    [TestCase("", false)]
    public void A_place_name_with_any_decimal_digit_is_refused(string value, bool hasDigit) =>
        Assert.That(PlaceRules.ContainsDigit(value), Is.EqualTo(hasDigit));

    [Test]
    public void An_email_address_is_personal_data()
    {
        Assert.That(PlaceRules.LooksLikePersonalData("a@b.c", Switzerland, false), Is.True);
        Assert.That(PlaceRules.LooksLikePersonalData("a@b.c", null, false), Is.True);
    }

    [Test]
    public void Fewer_than_ten_digits_is_never_personal_data()
    {
        Assert.That(PlaceRules.LooksLikePersonalData("123456789", null, false), Is.False);
        Assert.That(PlaceRules.LooksLikePersonalData("SW1A 1AA", Switzerland, false), Is.False);
    }

    [Test]
    public void Ten_digits_are_personal_data_unless_the_country_vouches_for_them()
    {
        Assert.That(PlaceRules.LooksLikePersonalData("0123456789", null, false), Is.True, "no country matched");
        Assert.That(PlaceRules.LooksLikePersonalData("0123456789", Switzerland, false), Is.True, "country without that code");
        Assert.That(PlaceRules.LooksLikePersonalData("0123456789", Switzerland, true), Is.False, "a code we hold");
        Assert.That(PlaceRules.LooksLikePersonalData("1234567890", Iran, false), Is.False, "the country's own regex matches");
        Assert.That(PlaceRules.LooksLikePersonalData("12345678901", Iran, false), Is.True, "the regex does not match");
    }

    [Test]
    public void A_held_code_only_counts_for_a_country_that_has_postal_data()
    {
        Assert.That(PlaceRules.LooksLikePersonalData("01234567890", Iran, true), Is.True);
    }

    [Test]
    public void Only_ascii_digits_count_toward_ten()
    {
        Assert.That(PlaceRules.LooksLikePersonalData("١٢٣٤٥٦٧٨٩٠", null, false), Is.False);
    }

    [Test]
    public void The_country_regex_is_case_insensitive_and_a_broken_one_matches_nothing()
    {
        var letters = new GeoCountryInfo("XX", "Xland", false, @"^[a-z0-9]{12}$");
        var broken = new GeoCountryInfo("YY", "Yland", false, "([");

        Assert.That(PlaceRules.LooksLikePersonalData("ABCDEF123456", letters, false), Is.False);
        Assert.That(PlaceRules.LooksLikePersonalData("0123456789", broken, false), Is.True);
    }

    [Test]
    public void A_tilde_in_the_regex_is_a_literal_tilde()
    {
        var tilde = new GeoCountryInfo("ZZ", "Zland", false, "^1234567890~$");

        Assert.That(PlaceRules.LooksLikePersonalData("1234567890~", tilde, false), Is.False);
    }
}
