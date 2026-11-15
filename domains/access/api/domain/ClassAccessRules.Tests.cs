using NUnit.Framework;

namespace Tsr.Access.Api.Domain;

/// <summary>The class access rules that need no database (PHP ClassAccessModel): validation, identity and note of a rule, version, preview hash, what an operator is offered.</summary>
public sealed class ClassAccessRulesTests
{
    private static RawCondition Text(string field, string value) => new(field, false, value, null);

    private static RawCondition Level(long id) => new("level", false, null, id);

    private static ClassFacts Class(int id, int gender, string? city = null, string? country = null, int? level = null, params string[] tags) =>
        new(id, gender, city, country, level, tags, "C" + id, "Class " + id);

    private static string DetailOf<T>(Outcome<T> outcome) => outcome.Refusal!.Detail;

    [Test]
    public void No_conditions_is_refused()
    {
        Assert.That(DetailOf(ClassAccessRules.CheckedConditions([])), Is.EqualTo("Choose at least one condition"));
    }

    [Test]
    public void A_negated_condition_is_refused_because_only_inclusion_can_be_added()
    {
        var outcome = ClassAccessRules.CheckedConditions([new RawCondition("city", true, "Pune", null)]);

        Assert.That(DetailOf(outcome), Is.EqualTo("Only conditions that include classes can be added"));
    }

    [TestCase("City")]
    [TestCase("gender")]
    public void A_field_is_one_of_the_four_in_lower_case(string field)
    {
        Assert.That(DetailOf(ClassAccessRules.CheckedConditions([Text(field, "x")])), Is.EqualTo("Unknown condition field"));
    }

    [TestCase(0L)]
    [TestCase(-3L)]
    public void A_level_is_a_positive_id(long id)
    {
        Assert.That(DetailOf(ClassAccessRules.CheckedConditions([Level(id)])), Is.EqualTo("A level is a level id"));
    }

    [Test]
    public void A_level_given_as_text_is_refused()
    {
        Assert.That(DetailOf(ClassAccessRules.CheckedConditions([new RawCondition("level", false, "3", null)])), Is.EqualTo("A level is a level id"));
    }

    [Test]
    public void A_text_value_has_its_white_space_collapsed_and_is_required()
    {
        var ok = ClassAccessRules.CheckedConditions([Text("city", "  New \t  York ")]);

        Assert.That(ok.Value!.Single().Value, Is.EqualTo("New York"));
        Assert.That(DetailOf(ClassAccessRules.CheckedConditions([Text("city", "  ")])), Is.EqualTo("A condition needs a value"));
        Assert.That(DetailOf(ClassAccessRules.CheckedConditions([Text("city", new string('a', 301))])), Is.EqualTo("A condition value must be 300 characters or fewer"));
    }

    [Test]
    public void Repeats_are_dropped_ignoring_case_and_the_order_is_natural()
    {
        var outcome = ClassAccessRules.CheckedConditions([Level(10), Level(9), Text("city", "Pune"), Text("city", "PUNE"), Level(2)]);

        Assert.That(outcome.Value!.Select(c => c.LevelId ?? 0), Is.EqualTo(Expect.List(0, 2, 9, 10)));
        Assert.That(outcome.Value!.Count(c => c.Field == "city"), Is.EqualTo(1));
    }

    [Test]
    public void More_than_fifty_values_for_one_field_is_refused()
    {
        var many = Enumerable.Range(1, 51).Select(i => Text("city", "City" + i)).ToList();

        Assert.That(DetailOf(ClassAccessRules.CheckedConditions(many)), Is.EqualTo("Too many values for one condition (at most 50)"));
    }

    [TestCase(null, true)]
    [TestCase(1, true)]
    [TestCase(2, true)]
    [TestCase(0, false)]
    [TestCase(3, false)]
    public void A_gender_is_one_or_two_or_left_out(int? gender, bool ok)
    {
        Assert.That(ClassAccessRules.CheckedGender(gender) is null, Is.EqualTo(ok));
    }

    [Test]
    public void The_same_gender_and_set_of_conditions_give_the_same_access_key_and_a_subset_does_not()
    {
        var a = new[] { new RuleCondition("city", false, "Pune", null), new RuleCondition("level", false, null, 3) };
        var reversed = new[] { a[1], new RuleCondition("city", false, "PUNE", null) };

        Assert.That(ClassAccessRules.AccessKey(1, a), Is.EqualTo(ClassAccessRules.AccessKey(1, reversed)));
        Assert.That(ClassAccessRules.AccessKey(1, a), Is.Not.EqualTo(ClassAccessRules.AccessKey(2, a)));
        Assert.That(ClassAccessRules.AccessKey(1, a), Is.Not.EqualTo(ClassAccessRules.AccessKey(1, a.Take(1))));
        Assert.That(ClassAccessRules.AccessKey(null, a), Does.StartWith("any/"));
    }

    [Test]
    public void The_note_names_the_gender_then_levels_cities_countries_and_tags()
    {
        var conditions = ClassAccessRules.Ordered(
        [
            new RuleCondition("tag", false, "Quran", null),
            new RuleCondition("level", false, null, 3),
            new RuleCondition("level", false, null, 4),
            new RuleCondition("level", false, null, 5),
            new RuleCondition("city", false, "Pune", null),
        ]);

        Assert.That(ClassAccessRules.NoteFor(1, conditions), Is.EqualTo("Gents, levels 3-5, Pune, Quran"));
        Assert.That(ClassAccessRules.NoteFor(null, [new RuleCondition("level", false, null, 2)]), Is.EqualTo("Any gender, level 2"));
    }

    [Test]
    public void Runs_of_ids_are_written_as_ranges()
    {
        Assert.That(ClassAccessRules.Ranges([5, 2, 4]), Is.EqualTo("2, 4-5"));
    }

    [Test]
    public void The_preview_hash_is_sixteen_hex_characters_of_the_sorted_ids_and_ignores_their_order()
    {
        var hash = ClassAccessRules.PreviewHash([3, 1, 2]);

        Assert.That(hash, Does.Match("^[0-9a-f]{16}$"));
        Assert.That(hash, Is.EqualTo(ClassAccessRules.PreviewHash([1, 2, 3])));
        Assert.That(hash, Is.Not.EqualTo(ClassAccessRules.PreviewHash([1, 2])));
        Assert.That(ClassAccessRules.SameHash(hash, hash), Is.True);
        Assert.That(ClassAccessRules.SameHash(hash, "short"), Is.False);
    }

    [Test]
    public void The_version_is_the_role_id_and_a_fingerprint_of_the_live_rule_ids()
    {
        Assert.That(ClassAccessRules.VersionOf(5, [7, 4]), Is.EqualTo("5:" + ClassAccessRules.PreviewHash([4, 7])));
        Assert.That(ClassAccessRules.VersionOf(0, [4]), Is.Not.EqualTo(ClassAccessRules.VersionOf(5, [4])));
    }

    [Test]
    public void A_gender_admin_is_offered_only_the_values_of_classes_of_their_gender()
    {
        var classes = new[]
        {
            Class(1, 1, "Pune", "India", 1, "Quran"),
            Class(2, 2, "Mumbai", "India", 2, "Hifz"),
            Class(3, 1, "pune", null, 1),
        };

        Assert.That(ClassAccessRules.Cities(classes, [1]), Is.EqualTo(Expect.List("Pune")));
        Assert.That(ClassAccessRules.Cities(classes, [1, 2]), Is.EqualTo(Expect.List("Mumbai", "Pune")));
        Assert.That(ClassAccessRules.Tags(classes, [1]), Is.EqualTo(Expect.List("Quran")));
        Assert.That(ClassAccessRules.Countries(classes, [2]), Is.EqualTo(Expect.List("India")));
    }

    [Test]
    public void A_value_the_operator_is_not_offered_is_refused_and_an_offered_one_takes_the_offered_spelling()
    {
        var conditions = new[] { new RuleCondition("city", false, "pune", null) };

        var accepted = ClassAccessRules.OfferedValues(conditions, ["Pune"], [], []);
        var refused = ClassAccessRules.OfferedValues(conditions, ["Mumbai"], [], []);

        Assert.That(accepted.Value!.Single().Value, Is.EqualTo("Pune"));
        Assert.That(DetailOf(refused), Is.EqualTo("Choose a city from the list"));
    }

    [Test]
    public void A_rule_reaches_the_classes_the_engine_matcher_says_in_the_order_given()
    {
        var classes = new[] { Class(1, 1, "Pune", null, 3), Class(2, 2, "Pune", null, 3), Class(3, 1, "Delhi", null, 3), Class(4, 1, "Pune", null, 4) };

        var reached = ClassAccessRules.Reach(1, [new RuleCondition("city", false, "pune", null), new RuleCondition("level", false, null, 3)], classes);

        Assert.That(reached.Select(c => c.Id), Is.EqualTo(Expect.List(1)));
        Assert.That(ClassAccessRules.Reach(null, [new RuleCondition("city", false, "Pune", null)], classes).Select(c => c.Id), Is.EqualTo(Expect.List(1, 2, 4)));
    }
}
