using System.Text.Json;
using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>PHP's api_validate_profile_field(), field by field, first problem wins. The messages are the ones the app shows.</summary>
public sealed class ProfileFieldsTests
{
    private static JsonElement Json(string json) => JsonElement.Parse(json);

    private static string? Check(string field, string json) => ProfileFields.Validate(field, Json(json));

    [Test]
    public void The_updatable_fields_are_PHPs_nine_in_PHPs_order() =>
        Assert.That(ProfileFields.Updatable, Is.EqualTo(["name", "gender", "age_range", "mobile", "country", "state", "city", "language", "zip"]));

    [TestCase("name")]
    [TestCase("gender")]
    [TestCase("mobile")]
    [TestCase("language")]
    [TestCase("zip")]
    [TestCase("country")]
    public void A_null_value_is_not_validated(string field) => Assert.That(Check(field, "null"), Is.Null);

    [TestCase("1")]
    [TestCase("2")]
    [TestCase("\"1\"")]
    [TestCase("1.9")]
    [TestCase("true")]
    [TestCase("\"1abc\"")]
    [TestCase("[1]")]
    public void A_gender_whose_int_cast_is_1_or_2_is_valid(string json) => Assert.That(Check("gender", json), Is.Null);

    [TestCase("0")]
    [TestCase("3")]
    [TestCase("\"abc\"")]
    [TestCase("false")]
    [TestCase("\"\"")]
    [TestCase("[]")]
    public void Any_other_gender_is_refused(string json) =>
        Assert.That(Check("gender", json), Is.EqualTo("Invalid gender value. Use 1 for Male, 2 for Female."));

    [TestCase("1")]
    [TestCase("3")]
    [TestCase("\"2abc\"")]
    [TestCase("2.5")]
    public void A_language_whose_int_cast_is_1_2_or_3_is_valid(string json) => Assert.That(Check("language", json), Is.Null);

    [TestCase("0")]
    [TestCase("4")]
    [TestCase("\"x\"")]
    public void Any_other_language_is_refused(string json) =>
        Assert.That(Check("language", json), Is.EqualTo("Invalid language value. Use 1 for English, 2 for Urdu, 3 for Gujarati."));

    [TestCase("\"\"")]
    [TestCase("\"+911234567890\"")]
    [TestCase("\"1234567890\"")]
    [TestCase("\"123456789012345\"")]
    [TestCase("1234567890123")]
    [TestCase("\"1234567890\\n\"")]
    public void A_mobile_number_is_empty_or_ten_to_fifteen_digits_with_an_optional_plus(string json) =>
        Assert.That(Check("mobile", json), Is.Null);

    [TestCase("\"123456789\"")]
    [TestCase("\"1234567890123456\"")]
    [TestCase("\"++911234567890\"")]
    [TestCase("\"+91 1234567890\"")]
    [TestCase("false")]
    [TestCase("\"\\u0661\\u0662\\u0663\\u0664\\u0665\\u0666\\u0667\\u0668\\u0669\\u0660\"")]
    public void Any_other_mobile_is_refused(string json) => Assert.That(Check("mobile", json), Is.EqualTo("Invalid mobile number"));

    [TestCase("\"\"")]
    [TestCase("\"8001\"")]
    [TestCase("\"SW1A 1AA\"")]
    [TestCase("\"123 456-789\"")]
    [TestCase("12345")]
    [TestCase("\"abc\\n\"")]
    public void A_zip_is_empty_or_three_to_twelve_letters_digits_spaces_or_hyphens(string json) =>
        Assert.That(Check("zip", json), Is.Null);

    [TestCase("\"ab\"")]
    [TestCase("\"a_b\"")]
    [TestCase("\"1234567890123\"")]
    [TestCase("\"a@b.c\"")]
    [TestCase("\"\\u00e9\\u00e9\\u00e9\"")]
    public void Any_other_zip_is_refused(string json) => Assert.That(Check("zip", json), Is.EqualTo("Invalid ZIP code"));

    [TestCase("name", "\"\"", "Name cannot be empty")]
    [TestCase("name", "\"   \"", "Name cannot be empty")]
    [TestCase("city", "\"\"", "City cannot be empty")]
    [TestCase("state", "\" \"", "State cannot be empty")]
    [TestCase("country", "\"\"", "Country cannot be empty")]
    [TestCase("name", "\"a\"", "Must be at least 2 characters")]
    [TestCase("name", "\" a \"", "Must be at least 2 characters")]
    [TestCase("name", "true", "Must be at least 2 characters")]
    [TestCase("name", "\"a\\tb\"", "Contains invalid characters")]
    [TestCase("name", "\"ab\\u007f\"", "Contains invalid characters")]
    [TestCase("name", "\"ab\\u0001\"", "Contains invalid characters")]
    public void A_text_field_is_refused_when_empty_short_or_holding_a_control_character(string field, string json, string message) =>
        Assert.That(Check(field, json), Is.EqualTo(message));

    [Test]
    public void A_text_field_longer_than_fifty_characters_after_trimming_is_refused()
    {
        Assert.That(Check("name", "\"" + new string('a', 51) + "\""), Is.EqualTo("Must be at most 50 characters"));
        Assert.That(Check("name", "\"" + new string('a', 50) + "\""), Is.Null);
        Assert.That(Check("name", "\"  " + new string('a', 50) + "  \""), Is.Null, "the length is counted after trim");
    }

    [Test]
    public void Length_counts_characters_not_bytes_and_every_script_is_allowed()
    {
        Assert.That(Check("name", "\"" + string.Concat(Enumerable.Repeat("\\ud83d\\ude00", 50)) + "\""), Is.Null, "50 emoji are 50 characters");
        Assert.That(Check("name", "\"R\\u00e9union\""), Is.Null);
        Assert.That(Check("name", "\"\\u0645\\u062d\\u0645\\u062f\""), Is.Null);
        Assert.That(Check("city", "\"Nerul (Navi mumbai)\""), Is.Null);
    }

    [Test]
    public void Age_range_and_unknown_fields_are_never_validated()
    {
        Assert.That(Check("age_range", "\"anything at all\""), Is.Null);
        Assert.That(Check("age_range", "[1]"), Is.Null);
        Assert.That(Check("bogus", "1"), Is.Null);
    }
}
