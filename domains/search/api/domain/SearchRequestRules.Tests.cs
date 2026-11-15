using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

[TestFixture]
internal sealed class SearchRequestRulesTests
{
    [TestCase(null)]
    [TestCase("")]
    [TestCase(" a ")]
    [TestCase("\0a\0")]
    [TestCase("a")]
    public void A_text_under_two_characters_after_trimming_is_refused(string? q) =>
        Assert.That(SearchRequestRules.Parse(q, null).Error, Is.EqualTo("q must be at least 2 characters"));

    [Test]
    public void A_text_over_a_hundred_characters_is_refused() =>
        Assert.That(SearchRequestRules.Parse(new string('a', 101), null).Error, Is.EqualTo("q must be at most 100 characters"));

    [Test]
    public void A_hundred_characters_are_accepted_and_counted_by_code_point() =>
        Assert.That(SearchRequestRules.Parse(string.Concat(Enumerable.Repeat("\U0001F600", 100)), null).IsSuccess, Is.True);

    [Test]
    public void A_NUL_inside_the_text_is_refused() =>
        Assert.That(SearchRequestRules.Parse("ab\0cd", null).Error, Is.EqualTo("q must not contain NUL characters"));

    [Test]
    public void Quotes_wildcards_and_query_syntax_are_kept_as_a_plain_value()
    {
        var parsed = SearchRequestRules.Parse("  name:* OR \"x\" ", null).Value!;
        Assert.That(parsed.Text, Is.EqualTo("name:* OR \"x\""));
    }

    [TestCase(null)]
    [TestCase("")]
    [TestCase("  ")]
    public void No_kinds_means_all_in_the_standard_order(string? kinds) =>
        Assert.That(SearchRequestRules.Parse("ab", kinds).Value!.Kinds, Is.EqualTo(new List<string> { "class", "teacher", "guide", "student", "subscriber" }));

    [Test]
    public void Kinds_keep_the_order_given_once_each_and_drop_empty_items_and_zero() =>
        Assert.That(SearchRequestRules.Parse("ab", "student, class,,0,student").Value!.Kinds, Is.EqualTo(new List<string> { "student", "class" }));

    [TestCase("member")]
    [TestCase("class,Class")]
    public void An_unknown_kind_is_refused(string kinds) =>
        Assert.That(SearchRequestRules.Parse("ab", kinds).Error, Is.EqualTo("kinds must be a list of class, teacher, guide, student, subscriber"));
}
