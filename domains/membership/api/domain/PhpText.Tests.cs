using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>PHP's trim, ucfirst, mb_strlen, strtolower and html_entity_decode as the profile rules use them.</summary>
public sealed class PhpTextTests
{
    [Test]
    public void Trim_strips_the_six_characters_PHP_strips_and_nothing_else()
    {
        Assert.That(PhpText.Trim(" \t\n\r\0\v x \t\n\r\0\v"), Is.EqualTo("x"));
        Assert.That(PhpText.Trim("\u00a0x\u00a0"), Is.EqualTo("\u00a0x\u00a0"), "a no-break space is not trimmed");
        Assert.That(PhpText.Trim("\fx"), Is.EqualTo("\fx"), "a form feed is not trimmed");
    }

    [TestCase("name", "Name")]
    [TestCase("Name", "Name")]
    [TestCase("", "")]
    [TestCase("\u00e9cole", "\u00e9cole")]
    public void UcFirst_upper_cases_an_ascii_first_letter_only(string input, string expected) =>
        Assert.That(PhpText.UcFirst(input), Is.EqualTo(expected));

    [Test]
    public void CodePointCount_counts_code_points_not_utf16_units()
    {
        Assert.That(PhpText.CodePointCount("a\U0001F600"), Is.EqualTo(2));
        Assert.That(PhpText.CodePointCount(string.Empty), Is.EqualTo(0));
    }

    [Test]
    public void LowerAscii_changes_ascii_letters_only()
    {
        Assert.That(PhpText.LowerAscii("FaTHeR"), Is.EqualTo("father"));
        Assert.That(PhpText.LowerAscii("\u212a\u0130"), Is.EqualTo("\u212a\u0130"), "the Kelvin sign and a dotted capital I stay as they are");
    }

    [TestCase("O&#039;Neil", "O'Neil")]
    [TestCase("a &amp; b", "a & b")]
    [TestCase("&quot;hi&quot;", "\"hi\"")]
    [TestCase("&lt;b&gt;", "<b>")]
    [TestCase("&apos;", "'")]
    [TestCase("&#x27;", "'")]
    [TestCase("&amp;amp;", "&amp;")]
    [TestCase("a & b", "a & b")]
    [TestCase("&nosuchentity;", "&nosuchentity;")]
    [TestCase("caf&eacute;", "caf\u00e9")]
    public void HtmlDecode_decodes_entities_once(string input, string expected) =>
        Assert.That(PhpText.HtmlDecode(input), Is.EqualTo(expected));
}
