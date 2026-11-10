using System.Text.Json.Nodes;
using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>The body of GET /me: PHP's api_cast over the 16 fields, null rules and quirks included.</summary>
public sealed class ProfileViewTests
{
    private static JsonObject Build(MemberProfile? profile, string? email = "a@example.invalid", int role = 0) =>
        ProfileView.Build(7, 900001, email, role, profile);

    [Test]
    public void The_keys_are_the_sixteen_of_the_wire_contract_in_order()
    {
        var keys = Build(new MemberProfile { UserId = 7 }).Select(p => p.Key);

        Assert.That(
            keys,
            Is.EqualTo(["id", "token", "email", "name", "roleid", "picture", "gender", "age_range", "mobile", "country", "state", "city", "language", "zip", "sendupdates", "unsubscribe"]));
    }

    [Test]
    public void A_member_with_no_profile_row_shows_PHPs_column_defaults()
    {
        var view = Build(null, role: 3);

        Assert.That(view["id"]!.GetValue<int>(), Is.EqualTo(7));
        Assert.That(view["token"]!.GetValue<int>(), Is.EqualTo(900001));
        Assert.That(view["email"]!.GetValue<string>(), Is.EqualTo("a@example.invalid"));
        Assert.That(view["roleid"]!.GetValue<int>(), Is.EqualTo(3));
        Assert.That(view["name"]!.GetValue<int>(), Is.EqualTo(0), "an empty name is the integer 0");
        Assert.That(view["mobile"], Is.Null);
        Assert.That(view["language"]!.GetValue<int>(), Is.EqualTo(0));
        Assert.That(view["sendupdates"]!.GetValue<string>(), Is.EqualTo("N"));
        Assert.That(view["unsubscribe"]!.GetValue<string>(), Is.EqualTo("N"));
    }

    [Test]
    public void A_missing_email_is_an_empty_string() =>
        Assert.That(Build(new MemberProfile { UserId = 7 }, email: null)["email"]!.GetValue<string>(), Is.EqualTo(string.Empty));

    [TestCase(null)]
    [TestCase("")]
    public void A_null_or_empty_name_is_the_integer_zero(string? name) =>
        Assert.That(Build(new MemberProfile { UserId = 7, Name = name })["name"]!.GetValue<int>(), Is.EqualTo(0));

    [Test]
    public void Text_fields_are_entity_decoded_and_the_picture_is_not()
    {
        var view = Build(new MemberProfile { UserId = 7, Name = "O&#039;Neil &amp; Co", City = "St&#039;s", Picture = "https://example.invalid/p.png?a=1&amp;b=2" });

        Assert.That(view["name"]!.GetValue<string>(), Is.EqualTo("O'Neil & Co"));
        Assert.That(view["city"]!.GetValue<string>(), Is.EqualTo("St's"));
        Assert.That(view["picture"]!.GetValue<string>(), Is.EqualTo("https://example.invalid/p.png?a=1&amp;b=2"));
    }

    [Test]
    public void Empty_text_becomes_null_where_the_field_is_nullable()
    {
        var view = Build(new MemberProfile { UserId = 7, Name = "Ab", Picture = string.Empty, Mobile = string.Empty, Country = string.Empty, Zip = string.Empty });

        Assert.That(view["picture"], Is.Null);
        Assert.That(view["mobile"], Is.Null);
        Assert.That(view["country"], Is.Null);
        Assert.That(view["zip"], Is.Null);
    }

    [TestCase("1", 1)]
    [TestCase("2", 2)]
    [TestCase("1.5", 1)]
    [TestCase(" 2", 2)]
    [TestCase("1e1", 10)]
    public void A_numeric_gender_is_its_int(string stored, int expected) =>
        Assert.That(Build(new MemberProfile { UserId = 7, Gender = stored })["gender"]!.GetValue<long>(), Is.EqualTo(expected));

    [TestCase("Male")]
    [TestCase("Female")]
    [TestCase("1abc")]
    [TestCase("")]
    [TestCase(null)]
    public void A_gender_that_is_not_numeric_is_null_not_zero(string? stored) =>
        Assert.That(Build(new MemberProfile { UserId = 7, Gender = stored })["gender"], Is.Null);

    [Test]
    public void Age_range_follows_the_same_int_rule()
    {
        Assert.That(Build(new MemberProfile { UserId = 7, AgeRange = "5" })["age_range"]!.GetValue<long>(), Is.EqualTo(5));
        Assert.That(Build(new MemberProfile { UserId = 7, AgeRange = "abc" })["age_range"], Is.Null);
    }

    [Test]
    public void Language_zero_stays_zero_and_a_null_language_is_null()
    {
        Assert.That(Build(new MemberProfile { UserId = 7, Language = 0 })["language"]!.GetValue<int>(), Is.EqualTo(0));
        Assert.That(Build(new MemberProfile { UserId = 7, Language = null })["language"], Is.Null);
        Assert.That(Build(new MemberProfile { UserId = 7, Language = 3 })["language"]!.GetValue<int>(), Is.EqualTo(3));
    }

    [Test]
    public void The_update_flags_are_text_and_empty_means_null()
    {
        var view = Build(new MemberProfile { UserId = 7, SendUpdates = "Y", Unsubscribe = string.Empty });

        Assert.That(view["sendupdates"]!.GetValue<string>(), Is.EqualTo("Y"));
        Assert.That(view["unsubscribe"], Is.Null);
    }
}
