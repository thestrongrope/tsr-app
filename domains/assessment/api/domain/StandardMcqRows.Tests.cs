using NUnit.Framework;

namespace Tsr.Assessment.Api.Domain;

[TestFixture]
internal sealed class StandardMcqRowsTests
{
    private static string[] Row(string code, string topic, string question) =>
        [code, topic, "Fiqh", "3", "Quiz A", question, "B", "x", "y", "z", "rx", "ry", "rz"];

    [Test]
    public void Rows_with_the_same_topic_subject_lesson_and_name_are_one_quiz_in_first_seen_order()
    {
        var quizzes = StandardMcqRows.Group([Row("c1", "T1", "q1"), Row("c2", "T2", "q2"), Row("c1", "T1", "q3")]);

        Assert.That(quizzes.Select(q => q.Topic), Is.EqualTo(new List<string> { "T1", "T2" }));
        Assert.That(quizzes[0].Questions.Select(q => q.Text), Is.EqualTo(new List<string> { "q1", "q3" }));
    }

    [Test]
    public void A_row_with_an_empty_or_zero_topic_is_skipped()
    {
        Assert.That(StandardMcqRows.Group([Row("c", string.Empty, "q"), Row("c", "0", "q")]), Is.Empty);
    }

    [Test]
    public void The_code_of_the_last_row_of_a_quiz_wins()
    {
        var quizzes = StandardMcqRows.Group([Row("old", "T", "q1"), Row("new", "T", "q2")]);

        Assert.That(quizzes.Single().Code, Is.EqualTo("new"));
    }

    [Test]
    public void A_short_row_reads_null_for_the_missing_cells()
    {
        var quizzes = StandardMcqRows.Group([["c", "T", "S", "1", "N", "question", "A"]]);

        var question = quizzes.Single().Questions.Single();
        Assert.That(question.Answer, Is.EqualTo("A"));
        Assert.That(question.Option1, Is.Null);
        Assert.That(question.Reason3, Is.Null);
    }
}
