using System.Text;
using System.Text.Json;
using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>A body as PHP's api_body() reads it: empty is an empty array, an object or list is fine, anything else is "Invalid JSON body".</summary>
public sealed class JsonBodyTests
{
    private static Tsr.Shared.Api.Result<JsonBody> Parse(string json) => JsonBody.Parse(Encoding.UTF8.GetBytes(json));

    [TestCase("")]
    [TestCase("{}")]
    [TestCase("[]")]
    [TestCase("[1,2]")]
    public void An_empty_body_an_object_or_a_list_is_accepted(string json) => Assert.That(Parse(json).IsSuccess, Is.True);

    [TestCase("null")]
    [TestCase("5")]
    [TestCase("\"x\"")]
    [TestCase("true")]
    [TestCase("abc")]
    [TestCase("{\"a\":")]
    [TestCase("{\"a\":\"\\ud800\"}")]
    public void Anything_else_is_Invalid_JSON_body(string json)
    {
        var result = Parse(json);

        Assert.That(result.IsSuccess, Is.False);
        Assert.That(result.Error, Is.EqualTo("Invalid JSON body"));
    }

    [Test]
    public void An_explicit_null_is_present_and_a_missing_field_is_not()
    {
        var body = Parse("{\"a\":null,\"b\":1}").Value!;

        Assert.That(body.Has("a"), Is.True);
        Assert.That(body.Get("a").ValueKind, Is.EqualTo(JsonValueKind.Null));
        Assert.That(body.Has("c"), Is.False);
        Assert.That(body.Get("c").ValueKind, Is.EqualTo(JsonValueKind.Undefined));
    }

    [Test]
    public void A_list_has_no_named_fields() => Assert.That(Parse("[1,2]").Value!.Has("a"), Is.False);

    [Test]
    public void When_a_key_repeats_the_last_value_wins()
    {
        var body = Parse("{\"a\":1,\"a\":2}").Value!;

        Assert.That(body.Get("a").GetInt32(), Is.EqualTo(2));
    }

    [Test]
    public void Entries_of_an_object_keep_the_first_position_and_the_last_value()
    {
        var element = JsonDocument.Parse("{\"x\":1,\"y\":2,\"x\":3}", new JsonDocumentOptions { AllowDuplicateProperties = true }).RootElement;

        var entries = JsonBody.Entries(element);

        Assert.That(entries.Select(e => e.Key), Is.EqualTo(["x", "y"]));
        Assert.That(entries.Select(e => e.Value.GetInt32()), Is.EqualTo([3, 2]));
    }

    [Test]
    public void Entries_of_a_list_are_keyed_by_position_and_a_scalar_has_none()
    {
        Assert.That(JsonBody.Entries(JsonDocument.Parse("[\"a\",\"b\"]").RootElement).Select(e => e.Key), Is.EqualTo(["0", "1"]));
        Assert.That(JsonBody.Entries(JsonDocument.Parse("5").RootElement), Is.Empty);
    }
}
