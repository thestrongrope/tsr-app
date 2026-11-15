using System.Text.Json;
using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>The values PATCH /me stores, as PDO and MariaDB make them (probed on the parity stack).</summary>
public sealed class ProfileColumnsTests
{
    private static JsonElement Json(string json) => JsonElement.Parse(json);

    [TestCase("\"abc\"", "abc")]
    [TestCase("12345", "12345")]
    [TestCase("1.9", "1.9")]
    [TestCase("true", "1")]
    [TestCase("false", "")]
    [TestCase("[1]", "Array")]
    [TestCase("\"\"", "")]
    public void A_text_column_takes_the_string_cast(string json, string expected) =>
        Assert.That(ProfileColumns.Text(Json(json)), Is.EqualTo(expected));

    [Test]
    public void A_text_column_takes_null_for_JSON_null() => Assert.That(ProfileColumns.Text(Json("null")), Is.Null);

    [TestCase("2", 2)]
    [TestCase("2.4", 2)]
    [TestCase("2.5", 3)]
    [TestCase("3.5", 4)]
    [TestCase("\"2\"", 2)]
    [TestCase("\" 2\"", 2)]
    [TestCase("\"2 \"", 2)]
    [TestCase("\"2.5\"", 3)]
    [TestCase("true", 1)]
    public void The_language_column_converts_numbers_as_MariaDB_does(string json, int expected) =>
        Assert.That(ProfileColumns.Language(Json(json)), Is.EqualTo(expected));

    [TestCase("\"2abc\"")]
    [TestCase("\"\"")]
    [TestCase("[1]")]
    [TestCase("{\"a\":1}")]
    public void A_language_that_is_not_entirely_a_number_refuses_the_write(string json) =>
        Assert.Throws<InvalidOperationException>(() => ProfileColumns.Language(Json(json)));
}
