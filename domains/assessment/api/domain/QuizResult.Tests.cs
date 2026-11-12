using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Assessment.Api.Domain;

[TestFixture]
internal sealed class QuizResultTests
{
    [TestCase(3, 4, "75.0")]
    [TestCase(4, 4, "100.0")]
    [TestCase(0, 4, "0.0")]
    [TestCase(1, 3, "33.33")]
    [TestCase(2, 3, "66.67")]
    [TestCase(1, 8, "12.5")]
    [TestCase(1, 16, "6.25")]
    [TestCase(1, 7, "14.29")]
    public void The_percent_is_a_float_rounded_to_two_places_over_the_question_count(int correct, int total, string json) =>
        Assert.That(JsonSerializer.Serialize(QuizResult.Percent(correct, total)), Is.EqualTo(json));

    [Test]
    public void A_quiz_with_no_questions_has_the_integer_percent_0() =>
        Assert.That(JsonSerializer.Serialize(QuizResult.Percent(0, 0)), Is.EqualTo("0"));

    [Test]
    public void The_envelope_counts_the_answers_given_and_the_correct_ones_and_keeps_unanswered_questions_against_the_score()
    {
        QuizResult.Detail[] details =
        [
            new(1, "q1", 0, "a", "a", 1),
            new(2, "q2", 0, "b", "a", 0),
        ];

        var body = QuizResult.Of(4, details);

        Assert.That((body.Total, body.Answered, body.Correct), Is.EqualTo((4, 2, 1)));
        Assert.That(JsonSerializer.Serialize(body.Percent), Is.EqualTo("25.0"));
    }

    [TestCase(null, null)]
    [TestCase("", null)]
    [TestCase("x", "x")]
    public void An_empty_text_is_null_on_the_wire(string? value, string? expected) =>
        Assert.That(QuizResult.TextOrNull(value), Is.EqualTo(expected));
}
