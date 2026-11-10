using NUnit.Framework;
using Tsr.Platform.Api.Domain;

namespace Tsr.Platform.Api.Tests.Domain;

/// <summary>The rules of web/models/location.php that need no database.</summary>
public sealed class GeoLookupTests
{
    private static string Join(IReadOnlyList<string> tries) => string.Join("\u0001", tries);

    private static string Joined(params string[] tries) => string.Join("\u0001", tries);

    [Test]
    public void A_code_without_a_space_is_tried_whole_only()
    {
        Assert.That(Join(GeoLookup.PostalCodeTries("8001")), Is.EqualTo(Joined("8001")));
    }

    [Test]
    public void A_code_with_a_space_is_tried_whole_then_by_the_part_before_the_first_space()
    {
        Assert.That(Join(GeoLookup.PostalCodeTries("SW1A 1AA")), Is.EqualTo(Joined("SW1A 1AA", "SW1A")));
        Assert.That(Join(GeoLookup.PostalCodeTries("M5V 3L9 X")), Is.EqualTo(Joined("M5V 3L9 X", "M5V")));
    }

    [Test]
    public void Only_an_ascii_space_splits_a_code()
    {
        Assert.That(Join(GeoLookup.PostalCodeTries("AB\tCD")), Is.EqualTo(Joined("AB\tCD")));
        Assert.That(Join(GeoLookup.PostalCodeTries("AB\u00a0CD")), Is.EqualTo(Joined("AB\u00a0CD")));
    }

    [Test]
    public void A_code_of_exactly_zero_is_never_tried_because_php_array_filter_drops_it()
    {
        Assert.That(GeoLookup.PostalCodeTries("0"), Is.Empty);
    }

    [Test]
    public void A_part_before_the_space_of_exactly_zero_is_dropped_but_the_whole_code_is_kept()
    {
        Assert.That(Join(GeoLookup.PostalCodeTries("0 123")), Is.EqualTo(Joined("0 123")));
        Assert.That(Join(GeoLookup.PostalCodeTries("00")), Is.EqualTo(Joined("00")));
        Assert.That(Join(GeoLookup.PostalCodeTries("0.0")), Is.EqualTo(Joined("0.0")));
    }

    [TestCase("zur", "zur%")]
    [TestCase("100%", "100|%%")]
    [TestCase("a_b", "a|_b%")]
    [TestCase("Pipe|", "Pipe||%")]
    [TestCase("|%_", "||" + "|%" + "|_%")]
    [TestCase("a\\b", "a\\b%")]
    [TestCase("K\u00f6l", "K\u00f6l%")]
    public void The_like_pattern_escapes_the_pipe_percent_and_underscore_and_adds_a_trailing_percent(string query, string expected)
    {
        Assert.That(GeoLookup.CityLikePattern(query), Is.EqualTo(expected));
    }

    // Expected values are PHP 8.5 html_entity_decode($s, ENT_QUOTES | ENT_HTML5, 'UTF-8').
    [TestCase("Ben &amp; Jerry", "Ben & Jerry")]
    [TestCase("Rock &#039;n Roll", "Rock 'n Roll")]
    [TestCase("&apos;", "'")]
    [TestCase("&quot;x&quot;", "\"x\"")]
    [TestCase("&lt;b&gt;", "<b>")]
    [TestCase("&amp;amp;", "&amp;")]
    [TestCase("&#x41;", "A")]
    [TestCase("&#65;", "A")]
    [TestCase("&#128512;", "\U0001F600")]
    [TestCase("&eacute;", "\u00e9")]
    [TestCase("&Aacute;", "\u00c1")]
    [TestCase("&hellip;", "\u2026")]
    [TestCase("&AElig;", "\u00c6")]
    [TestCase("&unknown;", "&unknown;")]
    [TestCase("a &amp b", "a &amp b")]
    [TestCase("&copy", "&copy")]
    [TestCase("&copy;", "\u00a9")]
    [TestCase("&nbsp;x", "\u00a0x")]
    [TestCase("&#0;", "&#0;")]
    [TestCase("&#xD800;", "&#xD800;")]
    [TestCase("&AElig", "&AElig")]
    [TestCase("&AMP;", "&")]
    [TestCase("plain", "plain")]
    public void Html_entities_are_decoded_like_php(string stored, string expected)
    {
        Assert.That(GeoLookup.DecodeEntities(stored), Is.EqualTo(expected));
    }

    [Test]
    public void A_try_holding_a_nul_is_dropped_because_no_stored_code_holds_one()
    {
        Assert.That(GeoLookup.PostalCodeTries("80\01"), Is.Empty);
        Assert.That(Join(GeoLookup.PostalCodeTries("123 4\0X")), Is.EqualTo(Joined("123")));
    }

    [Test]
    public void A_city_query_holding_a_nul_cannot_match_a_stored_name()
    {
        Assert.That(GeoLookup.CanMatchStoredText("z\0y"), Is.False);
        Assert.That(GeoLookup.CanMatchStoredText("zur"), Is.True);
    }
}
