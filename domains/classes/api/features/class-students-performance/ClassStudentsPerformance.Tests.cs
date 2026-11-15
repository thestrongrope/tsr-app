using NUnit.Framework;

namespace Tsr.Classes.Api.Features.ClassStudentsPerformance;

[TestFixture]
internal sealed class ClassStudentsPerformanceTests
{
    [TestCase("2025-9-1", "2025-12-31", "from and to must be dates as YYYY-MM-DD")]
    [TestCase("2025-02-30", "2025-12-31", "from and to must be dates as YYYY-MM-DD")]
    [TestCase("2025-01-01", "today", "from and to must be dates as YYYY-MM-DD")]
    [TestCase("٢٠٢٥-٠١-٠١", "2025-12-31", "from and to must be dates as YYYY-MM-DD", Description = "digits of another script are not a date, and never an exception")]
    [TestCase("2025-12-31", "2025-01-01", "from must not be after to")]
    [TestCase("2024-01-01", "2025-01-02", "The range can cover at most a year")]
    public void A_bad_range_is_refused_with_PHPs_message(string from, string to, string message) =>
        Assert.That(ClassStudentsPerformanceSlice.RangeError(from, to), Is.EqualTo(message));

    [TestCase("2025-01-01", "2025-12-31")]
    [TestCase("2024-01-01", "2024-12-31")]
    [TestCase("2025-05-05", "2025-05-05")]
    public void A_range_of_up_to_366_days_is_allowed(string from, string to) =>
        Assert.That(ClassStudentsPerformanceSlice.RangeError(from, to), Is.Null);

    [Test]
    public void A_topic_matches_its_figures_whatever_the_letter_case()
    {
        // The topic column is citext: the two queries may return different spellings of one topic.
        List<ClassStudentsPerformanceSlice.QuizFigure> figures = [new(900401, "quran", 2, 3, 3), new(900401, "Ahkam", 1, 3, 3)];
        Assert.That(ClassStudentsPerformanceSlice.TopicCorrect(figures, "Quran"), Is.EqualTo(2));
    }
}
