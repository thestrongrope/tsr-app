using System.Globalization;
using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class ReportFiguresTests
{
    [TestCase("1", "3", "0.3333")]
    [TestCase("2", "3", "0.6667")]
    [TestCase("1", "8", "0.1250")]
    [TestCase("1", "16", "0.0625")]
    [TestCase("1", "32", "0.0313")]
    [TestCase("5", "0", "0")]
    [TestCase("0", "7", "0")]
    public void A_quotient_has_four_decimals_rounded_half_up_and_a_zero_divisor_is_zero(string number, string divisor, string expected) =>
        Assert.That(ReportFigures.Quotient(Parse(number), Parse(divisor)), Is.EqualTo(Parse(expected)));

    [TestCase(null, 0)]
    [TestCase("0.7", 70)]
    [TestCase("0.5", 50)]
    [TestCase("0.1235", 12)]
    [TestCase("0.1250", 13)]
    [TestCase("0.00500000", 1)]
    [TestCase("1.0", 100)]
    public void A_fraction_becomes_a_whole_percent_half_away_from_zero(string? fraction, int expected) =>
        Assert.That(ReportFigures.WholePercent(fraction is null ? null : Parse(fraction)), Is.EqualTo(expected));

    private static decimal Parse(string text) => decimal.Parse(text, CultureInfo.InvariantCulture);
}
