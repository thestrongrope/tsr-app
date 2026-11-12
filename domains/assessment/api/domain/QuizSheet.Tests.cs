using NUnit.Framework;

namespace Tsr.Assessment.Api.Domain;

[TestFixture]
internal sealed class QuizSheetTests
{
    private static string Page(string name = "Quiz", string? topic = "Topic", string question = "Q?", params string[] options) =>
        QuizSheet.Html(name, topic, "G1", "Class <b>", [new QuizSheet.Question(question, options)]);

    [Test]
    public void Every_value_is_encoded()
    {
        var html = Page("<script>alert(1)</script>", "a&b", "\"q\" <img src=x onerror=y>", "<i>x</i>", "it's");
        Assert.That(html, Does.Not.Contain("<script>"));
        Assert.That(html, Does.Not.Contain("<img"));
        Assert.That(html, Does.Not.Contain("<i>"));
        Assert.That(html, Does.Contain("&lt;script&gt;"));
        Assert.That(html, Does.Contain("a&amp;b"));
        Assert.That(html, Does.Contain("Class &lt;b&gt;"));
        Assert.That(html, Does.Contain("&#39;"));
    }

    [Test]
    public void Options_are_lettered_and_questions_numbered_with_no_answer_marked()
    {
        var html = Page(question: "Q?", options: ["first", "second"]);
        Assert.That(html, Does.Contain("<b>1.</b> Q?"));
        Assert.That(html, Does.Contain("a) first"));
        Assert.That(html, Does.Contain("b) second"));
    }

    [TestCase(null)]
    [TestCase("")]
    [TestCase("0")]
    public void An_empty_or_zero_topic_is_left_out(string? topic)
    {
        Assert.That(Page(topic: topic), Does.Not.Contain("&middot;"));
    }

    [Test]
    public void The_page_refers_to_nothing_outside_itself()
    {
        var html = Page();
        Assert.That(html, Does.Not.Contain("http"));
        Assert.That(html, Does.Not.Contain("src="));
        Assert.That(html, Does.Not.Contain("url("));
    }

    [TestCase("AB12CD34", "MCQ_AB12CD34")]
    [TestCase("a b/c..d", "MCQ_a_b_c_d")]
    [TestCase(null, "MCQ_")]
    public void The_file_name_collapses_runs_of_other_characters(string? code, string expected)
    {
        Assert.That(QuizSheet.FileNameBase(code), Is.EqualTo(expected));
    }
}
