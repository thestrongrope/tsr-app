using System.Text;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

[TestFixture]
internal sealed class QuizEditTests
{
    private static readonly string[] JustQ = ["Q"];

    private static Result<QuizEdit.Edit> Parse(string json) => QuizEdit.Parse(JsonBody.Parse(Encoding.UTF8.GetBytes(json)).Value!);

    private static string Error(string json) => Parse(json).Error ?? "no error";

    [TestCase("""{"topic": "T"}""", "name is required")]
    [TestCase("""{"name": "  ", "topic": "T"}""", "name is required")]
    [TestCase("""{"name": "N"}""", "topic is required")]
    [TestCase("""{"name": "N", "topic": " \t\u0000 "}""", "topic is required")]
    [TestCase("""{"topic": ""}""", "name is required")]
    public void A_name_and_a_topic_are_required_after_the_PHP_trim_and_the_name_is_checked_first(string json, string message) => Assert.That(Error(json), Is.EqualTo(message));

    [Test]
    public void Name_and_topic_are_trimmed_and_taken_as_PHPs_string_of_the_value()
    {
        var edit = Parse("""{"name": "  Quiz one ", "topic": 5}""").Value!;

        Assert.That((edit.Name, edit.Topic), Is.EqualTo(("Quiz one", "5")));
        Assert.That(Parse("""{"name": ["x"], "topic": "T"}""").Value!.Name, Is.EqualTo("Array"));
    }

    [Test]
    public void Questions_missing_null_or_not_an_array_mean_no_questions()
    {
        foreach (var json in new[] { """{"name": "N", "topic": "T"}""", """{"name": "N", "topic": "T", "questions": null}""", """{"name": "N", "topic": "T", "questions": "abc"}""", """{"name": "N", "topic": "T", "questions": 3}""" })
        {
            var edit = Parse(json).Value!;
            Assert.That((edit.Insert.Count, edit.QuestionCount), Is.EqualTo((0, 0)), json);
        }
    }

    [Test]
    public void A_row_that_is_not_an_object_or_has_neither_question_nor_answer_is_skipped_and_not_counted()
    {
        var edit = Parse("""{"name": "N", "topic": "T", "questions": [5, "str", {"question": " ", "answer": ""}, {}, ["a", "b"], {"question": "Q", "answer": "A"}]}""").Value!;

        Assert.That(edit.QuestionCount, Is.EqualTo(1));
        Assert.That(edit.Insert.Select(q => q.Text), Is.EqualTo(JustQ));
    }

    [TestCase("""{"question": "Q"}""", 3)]
    [TestCase("""{"answer": "A"}""", 3)]
    [TestCase("""{"question": "Q", "answer": " "}""", 3)]
    public void A_row_with_only_one_of_question_and_answer_is_refused_by_its_one_based_position(string row, int position)
    {
        var json = "{\"name\": \"N\", \"topic\": \"T\", \"questions\": [{\"question\": \"a\", \"answer\": \"b\"}, {}, " + row + "]}";

        Assert.That(Error(json), Is.EqualTo($"Question {position} needs both a question and an answer"));
    }

    [Test]
    public void The_position_of_a_row_under_an_object_is_PHPs_int_of_its_key_plus_one()
    {
        Assert.That(Error("""{"name": "N", "topic": "T", "questions": {"7": {"question": "Q"}}}"""), Is.EqualTo("Question 8 needs both a question and an answer"));
        Assert.That(Error("""{"name": "N", "topic": "T", "questions": {"abc": {"question": "Q"}}}"""), Is.EqualTo("Question 1 needs both a question and an answer"));
    }

    [Test]
    public void The_answer_is_option1_and_missing_options_are_empty_not_null_and_the_text_null_means_a_database_null()
    {
        var edit = Parse("""{"name": "N", "topic": "T", "questions": [{"question": " Q ", "answer": "null", "option2": "null", "option3": " o3 ", "option5": "null"}, {"question": "R", "answer": " A "}]}""").Value!;

        Assert.That(edit.Insert[0], Is.EqualTo(new QuizEdit.Question("Q", null, null, "o3", string.Empty, null)));
        Assert.That(edit.Insert[1], Is.EqualTo(new QuizEdit.Question("R", "A", string.Empty, string.Empty, string.Empty, string.Empty)));
    }

    [Test]
    public void A_question_whose_text_is_the_PHP_falsy_zero_is_counted_but_not_inserted()
    {
        var edit = Parse("""{"name": "N", "topic": "T", "questions": [{"question": "0", "answer": "x"}, {"question": "Q", "answer": "A"}]}""").Value!;

        Assert.That(edit.QuestionCount, Is.EqualTo(2));
        Assert.That(edit.Insert.Select(q => q.Text), Is.EqualTo(JustQ));
    }

    [TestCase("""{"name": "N", "topic": "T"}""", null)]
    [TestCase("""{"name": "N", "topic": "T", "restrictToClass": null}""", null)]
    [TestCase("""{"name": "N", "topic": "T", "restrictToClass": 0}""", 0)]
    [TestCase("""{"name": "N", "topic": "T", "restrictToClass": "0"}""", 0)]
    [TestCase("""{"name": "N", "topic": "T", "restrictToClass": false}""", 0)]
    [TestCase("""{"name": "N", "topic": "T", "restrictToClass": "abc"}""", 0)]
    [TestCase("""{"name": "N", "topic": "T", "restrictToClass": 1}""", 1)]
    [TestCase("""{"name": "N", "topic": "T", "restrictToClass": 7}""", 1)]
    [TestCase("""{"name": "N", "topic": "T", "restrictToClass": true}""", 1)]
    public void The_restriction_is_left_alone_when_absent_and_is_zero_only_when_PHPs_int_of_it_is_zero(string json, int? expected) =>
        Assert.That(Parse(json).Value!.RestrictToClass, Is.EqualTo(expected));

    [Test]
    public void Too_long_or_NUL_text_is_refused_with_its_name_after_PHPs_own_rules()
    {
        var longName = new string('n', 301);
        var longText = new string('q', 1001);

        Assert.That(Error($$"""{"name": "{{longName}}", "topic": "T"}"""), Is.EqualTo("name is too long (at most 300 characters)"));
        Assert.That(Error($$"""{"name": "N", "topic": "{{longName}}"}"""), Is.EqualTo("topic is too long (at most 300 characters)"));
        Assert.That(Error($$"""{"name": "N", "topic": "T", "questions": [{"question": "{{longText}}", "answer": "A"}]}"""), Is.EqualTo("Question 1 is too long (the question and each option are at most 1000 characters)"));
        Assert.That(Error($$"""{"name": "N", "topic": "T", "questions": [{"question": "Q", "answer": "A", "option4": "{{longText}}"}]}"""), Is.EqualTo("Question 1 is too long (the question and each option are at most 1000 characters)"));
        Assert.That(Parse($$"""{"name": "{{new string('n', 300)}}", "topic": "T", "questions": [{"question": "{{new string('q', 1000)}}", "answer": "A"}]}""").IsSuccess, Is.True, "the limits themselves are accepted");
        Assert.That(Error("""{"name": "a\u0000b", "topic": "T"}"""), Is.EqualTo("name contains an invalid character"));
        Assert.That(Error("""{"name": "N", "topic": "T", "questions": [{"question": "Q", "answer": "A", "option2": "x\u0000y"}]}"""), Is.EqualTo("Question 1 contains an invalid character"));
        Assert.That(Error("""{"name": "N", "topic": "T", "questions": [{"question": "Q"}, {"question": "", "answer": "A"}]}"""), Is.EqualTo("Question 1 needs both a question and an answer"), "PHP's rule comes before a length rule");
    }

    [Test]
    public void More_than_500_rows_are_refused_before_any_row_is_read()
    {
        var rows = string.Join(",", Enumerable.Repeat("5", 501));

        Assert.That(Error($$"""{"name": "N", "topic": "T", "questions": [{{rows}}]}"""), Is.EqualTo("A quiz holds at most 500 questions"));
        Assert.That(Parse($$"""{"name": "N", "topic": "T", "questions": [{{string.Join(",", Enumerable.Repeat("5", 500))}}]}""").IsSuccess, Is.True);
    }
}
