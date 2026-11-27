using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>The pieces of the database fallback of article search (SRCH-R6) that need no database: the words, the LIKE patterns and the highlights.</summary>
[TestFixture]
internal sealed class ArticleFallbackTests
{
    [TestCase("50%", "%50\\%%")]
    [TestCase("snake_case", "%snake\\_case%")]
    [TestCase("a\\b", "%a\\\\b%")]
    [TestCase("plain", "%plain%")]
    public void A_word_becomes_a_pattern_that_matches_itself_only(string word, string pattern) =>
        Assert.That(ArticleFallback.Pattern(word), Is.EqualTo(pattern));

    [Test]
    public void Words_are_the_white_space_separated_parts_of_two_characters_or_more_once_each_and_at_most_ten()
    {
        Assert.That(ArticleFallback.Words("  Zorvath a  zorvath\tMethod\n"), Is.EqualTo((string[])["Zorvath", "Method"]));
        Assert.That(ArticleFallback.Words("a b c"), Is.Empty);
        Assert.That(ArticleFallback.Words(string.Join(' ', Enumerable.Range(10, 30))), Has.Count.EqualTo(ArticleFallback.MaxWords));
    }

    [Test]
    public void A_match_in_the_title_is_wrapped_in_em()
    {
        var json = ArticleHighlights.Build(["patience"], "Patience in hardship", null, "no match here");

        Assert.That(json, Is.EqualTo("""{"title":["<em>Patience</em> in hardship"]}"""));
    }

    [Test]
    public void A_snippet_has_thirty_characters_of_context_and_dots_where_it_is_cut()
    {
        var body = new string('a', 40) + " karbala " + new string('b', 40);

        var json = ArticleHighlights.Build(["karbala"], "x", null, body);

        Assert.That(json, Is.EqualTo("{\"content\":[\"..." + new string('a', 29) + " <em>karbala</em> " + new string('b', 28) + "...\"]}"));
    }

    [Test]
    public void At_most_three_matches_a_field_and_none_when_nothing_matched()
    {
        var json = ArticleHighlights.Build(["go"], "x", null, "go go go go go");

        Assert.That(System.Text.Json.JsonElement.Parse(json!).GetProperty("content").GetArrayLength(), Is.EqualTo(3));
        Assert.That(ArticleHighlights.Build(["zzz"], "x", "y", "z"), Is.Null);
    }

    [Test]
    public void Text_that_json_must_escape_is_escaped()
    {
        var json = ArticleHighlights.Build(["say"], "He said \"hi\" and say", null, "");

        Assert.That(System.Text.Json.JsonElement.Parse(json!).GetProperty("title")[0].GetString(), Is.EqualTo("He said \"hi\" and <em>say</em>"));
    }
}
