using System.Text;
using NUnit.Framework;
using Tsr.Platform.Api.Domain;

namespace Tsr.Platform.Api.Tests.Domain;

/// <summary>PHP's api_body(): an empty body is an empty array, anything that is not an array or object is "Invalid JSON body".</summary>
public sealed class GeoBodyTests
{
    private static Tsr.Shared.Api.Result<GeoBody> Parse(string json) => GeoBody.Parse(Encoding.UTF8.GetBytes(json));

    [Test]
    public void An_empty_body_is_an_empty_array_so_no_field_is_present()
    {
        var body = GeoBody.Parse([]);

        Assert.That(body.IsSuccess, Is.True);
        Assert.That(body.Value!.Text("country"), Is.Null);
    }

    [TestCase("not json")]
    [TestCase("null")]
    [TestCase("5")]
    [TestCase("\"text\"")]
    [TestCase("true")]
    [TestCase("{\"country\":")]
    [TestCase("  ")]
    [TestCase("{\"country\":\"\\ud800\"}")]
    [TestCase("{\"x\":{\"y\":[\"\\ud800\"]},\"country\":\"CH\"}")]
    [TestCase("{\"x\":1,\"\\udc00\":2}")]
    public void A_body_that_is_not_an_object_or_list_is_an_invalid_json_body(string json)
    {
        var body = Parse(json);

        Assert.That(body.IsSuccess, Is.False);
        Assert.That(body.Error, Is.EqualTo("Invalid JSON body"));
    }

    [Test]
    public void Invalid_utf8_is_an_invalid_json_body()
    {
        var body = GeoBody.Parse([0x7B, 0x22, 0xFF, 0x22, 0x3A, 0x31, 0x7D]);

        Assert.That(body.Error, Is.EqualTo("Invalid JSON body"));
    }

    [Test]
    public void A_list_is_accepted_and_has_no_fields()
    {
        var body = Parse("[\"CH\",\"8001\"]");

        Assert.That(body.IsSuccess, Is.True);
        Assert.That(body.Value!.Text("country"), Is.Null);
    }

    [Test]
    public void A_string_field_is_returned_untrimmed()
    {
        Assert.That(Parse("{\"country\":\" ch \"}").Value!.Text("country"), Is.EqualTo(" ch "));
    }

    [TestCase("5")]
    [TestCase("null")]
    [TestCase("true")]
    [TestCase("[\"CH\"]")]
    [TestCase("{\"a\":1}")]
    public void A_field_that_is_not_a_string_is_absent(string value)
    {
        Assert.That(Parse("{\"country\":" + value + "}").Value!.Text("country"), Is.Null);
    }

    [Test]
    public void When_a_key_repeats_the_last_value_wins_even_if_it_is_not_a_string()
    {
        Assert.That(Parse("{\"country\":\"CH\",\"country\":\"DE\"}").Value!.Text("country"), Is.EqualTo("DE"));
        Assert.That(Parse("{\"country\":\"CH\",\"country\":5}").Value!.Text("country"), Is.Null);
    }

    [Test]
    public void Other_keys_are_ignored()
    {
        Assert.That(Parse("{\"x\":{\"y\":[1,2]},\"country\":\"CH\"}").Value!.Text("country"), Is.EqualTo("CH"));
    }
}
