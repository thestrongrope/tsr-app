using NUnit.Framework;

namespace Tsr.Access.Api.Domain;

/// <summary>
/// Class access rules (PHP's class_access_from_rules view): which active classes one rule reaches.
/// Values of one field are ORed, different fields ANDed, negations exclude; text is compared ignoring case.
/// </summary>
public sealed class RuleMatcherTests
{
    private static ClassFacts Class(int id = 1, int gender = 1, string? city = "Pune", string? country = "India", int? level = 2, params string[] tags) =>
        new(id, gender, city, country, level, tags);

    private static RuleCondition Inc(string field, string value) => new(field, false, value, null);

    private static RuleCondition Not(string field, string value) => new(field, true, value, null);

    private static AccessRule Rule(int? gender = null, params RuleCondition[] conditions) => new(gender, conditions);

    [Test]
    public void A_rule_with_no_gender_and_no_conditions_reaches_every_class()
    {
        Assert.That(RuleMatcher.Matches(Rule(), Class(gender: 1)), Is.True);
        Assert.That(RuleMatcher.Matches(Rule(), Class(gender: 2)), Is.True);
    }

    [Test]
    public void A_rule_gender_limits_it_to_classes_of_that_gender()
    {
        Assert.That(RuleMatcher.Matches(Rule(gender: 2), Class(gender: 2)), Is.True);
        Assert.That(RuleMatcher.Matches(Rule(gender: 2), Class(gender: 1)), Is.False);
    }

    [Test]
    public void Values_of_one_field_are_ored()
    {
        var rule = Rule(null, Inc("city", "Pune"), Inc("city", "Mumbai"));

        Assert.That(RuleMatcher.Matches(rule, Class(city: "Mumbai")), Is.True);
        Assert.That(RuleMatcher.Matches(rule, Class(city: "Delhi")), Is.False);
    }

    [Test]
    public void Different_fields_are_anded()
    {
        var rule = Rule(null, Inc("city", "Pune"), Inc("country", "India"));

        Assert.That(RuleMatcher.Matches(rule, Class(city: "Pune", country: "India")), Is.True);
        Assert.That(RuleMatcher.Matches(rule, Class(city: "Pune", country: "UK")), Is.False);
    }

    [Test]
    public void Text_is_compared_ignoring_case()
    {
        Assert.That(RuleMatcher.Matches(Rule(null, Inc("city", "PUNE")), Class(city: "pune")), Is.True);
        Assert.That(RuleMatcher.Matches(Rule(null, Inc("tag", "Online")), Class(tags: "online")), Is.True);
    }

    [Test]
    public void A_level_condition_compares_the_level_id()
    {
        var rule = Rule(null, new RuleCondition("level", false, null, 2));

        Assert.That(RuleMatcher.Matches(rule, Class(level: 2)), Is.True);
        Assert.That(RuleMatcher.Matches(rule, Class(level: 3)), Is.False);
        Assert.That(RuleMatcher.Matches(rule, Class(level: null)), Is.False);
    }

    [Test]
    public void A_negation_excludes_a_matching_class()
    {
        var rule = Rule(null, Not("city", "Pune"));

        Assert.That(RuleMatcher.Matches(rule, Class(city: "Pune")), Is.False);
        Assert.That(RuleMatcher.Matches(rule, Class(city: "Delhi")), Is.True);
    }

    [Test]
    public void A_missing_city_country_or_level_fails_a_negation_too()
    {
        Assert.That(RuleMatcher.Matches(Rule(null, Not("city", "Pune")), Class(city: null)), Is.False);
        Assert.That(RuleMatcher.Matches(Rule(null, Not("country", "UK")), Class(country: null)), Is.False);
        Assert.That(RuleMatcher.Matches(Rule(null, new RuleCondition("level", true, null, 2)), Class(level: null)), Is.False);
    }

    [Test]
    public void A_tag_negation_excludes_a_class_carrying_the_tag_and_keeps_an_untagged_one()
    {
        var rule = Rule(null, Not("tag", "online"));

        Assert.That(RuleMatcher.Matches(rule, Class(tags: ["Online"])), Is.False);
        Assert.That(RuleMatcher.Matches(rule, Class()), Is.True);
    }

    [Test]
    public void A_tag_condition_needs_the_class_to_carry_the_tag()
    {
        var rule = Rule(null, Inc("tag", "weekend"));

        Assert.That(RuleMatcher.Matches(rule, Class(tags: ["weekend", "online"])), Is.True);
        Assert.That(RuleMatcher.Matches(rule, Class()), Is.False);
    }

    [Test]
    public void Several_rules_are_unioned_and_a_class_two_rules_reach_is_listed_once_per_rule()
    {
        var rules = new[] { Rule(null, Inc("city", "Pune")), Rule(null, Inc("country", "India")) };
        var classes = new[] { Class(1, city: "Pune"), Class(2, city: "Delhi"), Class(3, city: "Paris", country: "France") };

        var matched = RuleMatcher.Assigned(rules, classes);

        // Quirk: PHP's class_access view has one row per (rule, class), so class 1 (Pune, India) appears twice.
        Assert.That(matched.Select(c => c.Id), Is.EqualTo(Expect.List(1, 1, 2)));
    }
}
