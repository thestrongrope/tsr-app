using NUnit.Framework;
using Tsr.Classes.Api.Domain;

namespace Tsr.Classes.Api.Features.ReportPendingNudge;

[TestFixture]
public sealed class ReportPendingNudgeTests
{
    private static PendingRules.PendingTeacher Teacher(params PendingRules.PendingClass[] classes) => new(5, "T", 0, 0, classes);

    private static PendingRules.PendingClass Class(int id, string code, int forms, int mcqs) => new(id, "L", code, forms, mcqs, 0, 0);

    [Test]
    public void One_class_names_forms_and_MCQs_with_the_right_plurals()
    {
        var (title, body) = ReportPendingNudgeSlice.Message(Teacher(Class(1, "A1", 1, 2), Class(2, "B2", 3, 0)));

        Assert.That(title, Is.EqualTo("Reminder from the class coordination team"));
        Assert.That(body, Is.EqualTo("Assalamu Alaikum. Please complete the following for your classes:\n• A1: 1 class form, 2 MCQs to conduct\n• B2: 3 class forms\nJazakallah khair."));
    }

    [Test]
    public void A_long_list_is_cut_to_500_characters_with_the_count_of_the_rest()
    {
        var classes = Enumerable.Range(1, 40).Select(i => Class(i, "CLASS-" + i, 4, 4)).ToArray();

        var (_, body) = ReportPendingNudgeSlice.Message(Teacher(classes));

        Assert.That(body.EnumerateRunes().Count(), Is.LessThanOrEqualTo(500));
        Assert.That(body, Does.Contain("\n…and ").And.Contain(" more classes\nJazakallah khair."));
    }
}
