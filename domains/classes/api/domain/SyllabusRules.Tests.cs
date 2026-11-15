using System.Text.Json;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class SyllabusRulesTests
{
    private static JsonBody Body(string json) => JsonBody.Parse(System.Text.Encoding.UTF8.GetBytes(json)).Value!;

    [TestCase("true", true)]
    [TestCase(" ON ", true)]
    [TestCase("Yes", true)]
    [TestCase("1", true)]
    [TestCase("false", false)]
    [TestCase("0", false)]
    [TestCase("NO", false)]
    [TestCase("off", false)]
    [TestCase("", false)]
    [TestCase(null, false)]
    public void include_inactive_reads_the_spellings_FastAPI_reads(string? raw, bool expected)
    {
        var parsed = SyllabusRules.IncludeInactive(raw);
        Assert.That(parsed.IsSuccess, Is.True);
        Assert.That(parsed.Value, Is.EqualTo(expected));
    }

    [TestCase("maybe")]
    [TestCase("2")]
    [TestCase("tru")]
    public void include_inactive_refuses_anything_else(string raw) =>
        Assert.That(SyllabusRules.IncludeInactive(raw).Error, Is.EqualTo("Invalid include_inactive"));

    [TestCase("{}", "level_id is required")]
    [TestCase("""{"level_id": "abc", "subject_name": "x", "url": "x"}""", "level_id is required")]
    [TestCase("""{"level_id": null, "subject_name": "x", "url": "x"}""", "level_id is required")]
    [TestCase("""{"level_id": 2, "subject_name": "  ", "url": "x"}""", "subject_name is required")]
    [TestCase("""{"level_id": 2, "subject_name": 5, "url": "x"}""", "subject_name is required")]
    [TestCase("""{"level_id": 2, "subject_name": "x"}""", "url is required")]
    [TestCase("""{"level_id": 2, "subject_name": "x", "url": "x", "link_type": "doc"}""", "link_type must be 'pdf' or 'external'")]
    [TestCase("""{"level_id": 2, "subject_name": "x", "url": "x", "sort_order": "high"}""", "sort_order must be an integer")]
    [TestCase("""{"level_id": 2, "subject_name": "x", "url": "x", "sort_order": true}""", "sort_order must be an integer")]
    [TestCase("""{"level_id": 2, "subject_name": "x", "url": "x", "description": 5}""", "description must be a string")]
    public void A_new_item_is_refused_with_the_first_failing_check_in_PHPs_order(string json, string expected) =>
        Assert.That(SyllabusRules.NewItem(Body(json)).Error, Is.EqualTo(expected));

    [Test]
    public void A_new_item_keeps_the_text_untrimmed_and_casts_the_numbers_as_PHP_does()
    {
        var parsed = SyllabusRules.NewItem(Body("""{"level_id": "2", "subject_name": " A ", "url": " u ", "sort_order": 2.9, "description": null}"""));
        Assert.That(parsed.IsSuccess, Is.True);
        Assert.That(parsed.Value, Is.EqualTo(new SyllabusRules.NewItemInput(2, " A ", " u ", "pdf", 2, null)));
    }

    [Test]
    public void A_null_link_type_or_sort_order_means_the_default_as_PHP_null_coalescing_reads_it()
    {
        var parsed = SyllabusRules.NewItem(Body("""{"level_id": 2, "subject_name": "x", "url": "x", "link_type": null, "sort_order": null}"""));
        Assert.That(parsed.Value, Is.EqualTo(new SyllabusRules.NewItemInput(2, "x", "x", "pdf", 0, null)));
    }

    [Test]
    public void A_sort_order_beyond_the_column_is_refused_rather_than_clamped() =>
        Assert.That(SyllabusRules.NewItem(Body("""{"level_id": 2, "subject_name": "x", "url": "x", "sort_order": 99999999999}""")).Error, Is.EqualTo("sort_order must be an integer"));

    [Test]
    public void A_text_over_its_column_is_refused()
    {
        var long151 = new string('a', 151);
        Assert.That(SyllabusRules.NewItem(Body($$"""{"level_id": 2, "subject_name": "{{long151}}", "url": "x"}""")).Error, Is.EqualTo("subject_name must be at most 150 characters"));
    }

    [Test]
    public void An_update_counts_a_field_as_given_when_it_is_present_and_not_null()
    {
        var parsed = SyllabusRules.Changes(Body("""{"sort_order": 0, "is_active": false, "description": "", "subject_name": null, "level_id": 3}"""));
        Assert.That(parsed.IsSuccess, Is.True);
        Assert.That(parsed.Value!.SortOrder, Is.EqualTo(0));
        Assert.That(parsed.Value.IsActive, Is.EqualTo(0));
        Assert.That(parsed.Value.Description, Is.EqualTo(string.Empty));
        Assert.That(parsed.Value.SubjectName, Is.Null);
        Assert.That(parsed.Value.IsEmpty, Is.False);
    }

    [Test]
    public void An_update_with_nothing_given_is_empty() =>
        Assert.That(SyllabusRules.Changes(Body("""{"subject_name": null, "level_id": 3}""")).Value!.IsEmpty, Is.True);

    [TestCase("""{"subject_name": 5}""", "subject_name must be a string")]
    [TestCase("""{"description": 5}""", "description must be a string")]
    [TestCase("""{"link_type": "doc"}""", "link_type must be 'pdf' or 'external'")]
    [TestCase("""{"url": []}""", "url must be a string")]
    [TestCase("""{"sort_order": "x"}""", "sort_order must be an integer")]
    [TestCase("""{"subject_name": 5, "url": 5}""", "subject_name must be a string")]
    public void An_update_is_refused_with_the_first_failing_field(string json, string expected) =>
        Assert.That(SyllabusRules.Changes(Body(json)).Error, Is.EqualTo(expected));

    [TestCase("false", 0)]
    [TestCase("\"false\"", 1)]
    [TestCase("\"0\"", 0)]
    [TestCase("\"\"", 0)]
    [TestCase("0", 0)]
    [TestCase("0.0", 0)]
    [TestCase("[]", 0)]
    [TestCase("{}", 0)]
    [TestCase("[0]", 1)]
    [TestCase("true", 1)]
    [TestCase("2", 1)]
    [TestCase("\"a\"", 1)]
    public void is_active_is_stored_by_PHP_truthiness(string json, int expected) =>
        Assert.That(SyllabusRules.Changes(Body($$"""{"is_active": {{json}}}""")).Value!.IsActive, Is.EqualTo(expected));
}
