using System.Text.Json;
using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>What PHP's (string), (int) and is_numeric make of a decoded JSON value.</summary>
public sealed class PhpValueTests
{
    private static JsonElement Json(string json) => JsonDocument.Parse(json).RootElement.Clone();

    [TestCase("\"abc\"", "abc")]
    [TestCase("5", "5")]
    [TestCase("-12", "-12")]
    [TestCase("1.5", "1.5")]
    [TestCase("1.0", "1")]
    [TestCase("true", "1")]
    [TestCase("false", "")]
    [TestCase("null", "")]
    [TestCase("[1]", "Array")]
    [TestCase("{\"a\":1}", "Array")]
    public void Text_is_the_string_cast(string json, string expected) =>
        Assert.That(PhpValue.Text(Json(json)), Is.EqualTo(expected));

    [Test]
    public void Text_of_a_missing_value_is_empty() =>
        Assert.That(PhpValue.Text(default), Is.EqualTo(string.Empty));

    [TestCase("5", 5)]
    [TestCase("1.9", 1)]
    [TestCase("-1.9", -1)]
    [TestCase("\"1abc\"", 1)]
    [TestCase("\"abc\"", 0)]
    [TestCase("\" 12\"", 12)]
    [TestCase("\"1e3\"", 1000)]
    [TestCase("\"1.9\"", 1)]
    [TestCase("\".5\"", 0)]
    [TestCase("\"+3\"", 3)]
    [TestCase("true", 1)]
    [TestCase("false", 0)]
    [TestCase("null", 0)]
    [TestCase("[]", 0)]
    [TestCase("[7]", 1)]
    [TestCase("{\"a\":1}", 1)]
    public void Int_is_the_int_cast(string json, long expected) =>
        Assert.That(PhpValue.Int(Json(json)), Is.EqualTo(expected));

    [Test]
    public void Int_of_a_huge_number_text_clamps_like_PHP()
    {
        Assert.That(PhpValue.IntOfText("9999999999999999999"), Is.EqualTo(long.MaxValue));
        Assert.That(PhpValue.IntOfText("-9999999999999999999"), Is.EqualTo(long.MinValue));
    }

    [TestCase("1", true)]
    [TestCase("1.5", true)]
    [TestCase(" 1", true)]
    [TestCase("1 ", true)]
    [TestCase("1e3", true)]
    [TestCase(".5", true)]
    [TestCase("+1", true)]
    [TestCase("-1.5e-3", true)]
    [TestCase("", false)]
    [TestCase("abc", false)]
    [TestCase("1abc", false)]
    [TestCase("0x1A", false)]
    [TestCase("1 2", false)]
    [TestCase(".", false)]
    [TestCase("\u0663", false)]
    public void IsNumeric_follows_PHP_8(string value, bool expected) =>
        Assert.That(PhpValue.IsNumeric(value), Is.EqualTo(expected));
}
