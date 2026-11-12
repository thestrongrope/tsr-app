using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

public sealed class McqAdherenceTests
{
    [TestCase(1, 3, 33.3)]
    [TestCase(2, 3, 66.7)]
    [TestCase(0, 5, 0.0)]
    [TestCase(4, 4, 100.0)]
    [TestCase(0, 0, 0.0)]
    public void Adherence_is_rounded_to_one_decimal(int conducted, int expected, double percent) =>
        Assert.That(McqAdherence.Percent(conducted, expected).Value, Is.EqualTo(percent));

    [TestCase(1, 8, 8, 13)]
    [TestCase(3, 0, 12, null)]
    [TestCase(5, 3, 0, null)]
    public void A_student_percent_is_of_the_class_maximum(int correct, int attempted, int max, int? percent)
    {
        var student = new McqSummaryReport.Student("A", attempted, 0, correct, new Dictionary<string, McqSummaryReport.TopicFigure>());
        Assert.That(McqSummaryReport.Percent(student, max), Is.EqualTo(percent));
    }
}
