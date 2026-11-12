using System.Text;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

[TestFixture]
internal sealed class AnswerBodyTests
{
    private static IReadOnlyList<AnswerBody.Answer>? Parse(string json) => AnswerBody.Parse(JsonBody.Parse(Encoding.UTF8.GetBytes(json)).Value!);

    [TestCase("")]
    [TestCase("{}")]
    [TestCase("[]")]
    [TestCase("""{"responses": null}""")]
    [TestCase("""{"responses": "x"}""")]
    [TestCase("""{"responses": []}""")]
    [TestCase("""{"responses": {}}""")]
    public void No_responses_array_is_null(string json) => Assert.That(Parse(json), Is.Null);

    [Test]
    public void An_item_counts_only_as_an_object_with_a_questionId_that_is_not_null()
    {
        var answers = Parse("""{"responses": [1, "a", [5], {"selectedText": "x"}, {"questionId": null}, {"questionId": "7", "selectedText": "x"}]}""");

        Assert.That(answers!.Select(a => a.QuestionId), Is.EqualTo(new long[] { 7 }));
    }

    [Test]
    public void A_repeated_id_keeps_its_first_position_and_its_last_item_and_ids_are_cast_with_int()
    {
        var answers = Parse("""{"responses": [{"questionId": 9, "selectedText": "a"}, {"questionId": "abc"}, {"questionId": 9.9, "selectedText": "b"}]}""");

        Assert.That(answers!.Select(a => (a.QuestionId, a.SelectedText)), Is.EqualTo(new (long, string?)[] { (9, "b"), (0, null) }));
    }

    [Test]
    public void The_selected_text_is_PHPs_string_of_it_without_NUL_and_the_option_is_an_int_only_when_numeric()
    {
        var answers = Parse("""{"responses": [{"questionId": 1, "selectedText": 123, "option": "x"}, {"questionId": 2, "selectedText": true, "option": "3"}, {"questionId": 3, "selectedText": "a\u0000b", "option": 2.7}, {"questionId": 4, "selectedText": ["a"]}]}""");

        Assert.That(answers!.Select(a => (a.SelectedText, a.Selected)), Is.EqualTo(new (string?, int)[] { ("123", 0), ("1", 3), ("ab", 2), ("Array", 0) }));
    }
}
