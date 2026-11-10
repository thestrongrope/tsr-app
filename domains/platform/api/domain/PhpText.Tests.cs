using NUnit.Framework;
using Tsr.Platform.Api.Domain;

namespace Tsr.Platform.Api.Tests.Domain;

/// <summary>PHP's trim, strtoupper and mb_strlen, which the geo rules are defined in terms of.</summary>
public sealed class PhpTextTests
{
    [Test]
    public void Trim_removes_only_space_tab_newline_return_nul_and_vertical_tab()
    {
        Assert.That(PhpText.Trim(" \t\n\r\0\v ab \t\n\r\0\v"), Is.EqualTo("ab"));
    }

    [Test]
    public void Trim_keeps_other_whitespace_such_as_a_no_break_space_and_form_feed()
    {
        // .NET's string.Trim() would remove these; PHP's trim() does not.
        Assert.That(PhpText.Trim("\u00a0ab\u00a0"), Is.EqualTo("\u00a0ab\u00a0"));
        Assert.That(PhpText.Trim("\fab\f"), Is.EqualTo("\fab\f"));
    }

    [Test]
    public void Trim_keeps_inner_spaces()
    {
        Assert.That(PhpText.Trim("  SW1A 1AA "), Is.EqualTo("SW1A 1AA"));
    }

    [Test]
    public void ToUpperAscii_changes_a_to_z_only()
    {
        Assert.That(PhpText.ToUpperAscii("sw1a \u00e9\u00fc\u00df i"), Is.EqualTo("SW1A \u00e9\u00fc\u00df I"));
    }

    [Test]
    public void CodePointCount_counts_code_points_not_utf16_units()
    {
        Assert.That(PhpText.CodePointCount("ab"), Is.EqualTo(2));
        Assert.That(PhpText.CodePointCount("\U0001F600"), Is.EqualTo(1));
        Assert.That(PhpText.CodePointCount("e\u0301"), Is.EqualTo(2));
    }
}
