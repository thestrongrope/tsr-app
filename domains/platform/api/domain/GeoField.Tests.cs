using System.Text;
using NUnit.Framework;
using Tsr.Platform.Api.Domain;

namespace Tsr.Platform.Api.Tests.Domain;

/// <summary>
/// api_geo_text() of routes/geo.php: a string, not blank after trim, at most N code points counted
/// BEFORE the trim; the message is "FIELD is required and must be at most N characters".
/// </summary>
public sealed class GeoFieldTests
{
    private static Tsr.Shared.Api.Result<string> Read(string json, string field, int max) =>
        GeoField.Read(GeoBody.Parse(Encoding.UTF8.GetBytes(json)).Value!, field, max);

    [Test]
    public void A_valid_value_is_returned_trimmed()
    {
        Assert.That(Read("{\"code\":\"  SW1A 1AA \"}", "code", 20).Value, Is.EqualTo("SW1A 1AA"));
    }

    [Test]
    public void A_missing_field_is_refused_with_the_php_message()
    {
        var result = Read("{}", "country", 2);

        Assert.That(result.IsSuccess, Is.False);
        Assert.That(result.Error, Is.EqualTo("country is required and must be at most 2 characters"));
    }

    [TestCase("5")]
    [TestCase("null")]
    [TestCase("true")]
    [TestCase("[\"CH\"]")]
    [TestCase("\"\"")]
    [TestCase("\"   \"")]
    [TestCase("\"\\t\\n\\r\\u0000\\u000b \"")]
    public void A_value_that_is_not_a_string_or_is_blank_is_refused(string value)
    {
        Assert.That(Read("{\"country\":" + value + "}", "country", 2).Error, Is.EqualTo("country is required and must be at most 2 characters"));
    }

    [Test]
    public void A_no_break_space_is_not_blank_to_php_so_it_is_accepted_and_kept()
    {
        Assert.That(Read("{\"country\":\"\\u00a0\"}", "country", 2).Value, Is.EqualTo("\u00a0"));
    }

    [Test]
    public void One_character_for_a_country_is_allowed()
    {
        Assert.That(Read("{\"country\":\"C\"}", "country", 2).Value, Is.EqualTo("C"));
    }

    [Test]
    public void The_length_is_measured_before_the_trim()
    {
        Assert.That(Read("{\"country\":\"  AB  \"}", "country", 6).IsSuccess, Is.True);
        Assert.That(Read("{\"country\":\"  AB  \"}", "country", 5).IsSuccess, Is.False);
        Assert.That(Read("{\"country\":\" CH \"}", "country", 2).Error, Is.EqualTo("country is required and must be at most 2 characters"));
    }

    [Test]
    public void Exactly_the_limit_is_accepted_and_one_over_is_refused_in_code_points()
    {
        Assert.That(Read("{\"query\":\"" + new string('a', 100) + "\"}", "query", 100).IsSuccess, Is.True);
        Assert.That(Read("{\"query\":\"" + new string('a', 101) + "\"}", "query", 100).Error, Is.EqualTo("query is required and must be at most 100 characters"));
        Assert.That(Read("{\"country\":\"\U0001F600\U0001F600\"}", "country", 2).IsSuccess, Is.True);
        Assert.That(Read("{\"country\":\"\U0001F600\U0001F600\U0001F600\"}", "country", 2).IsSuccess, Is.False);
    }
}
