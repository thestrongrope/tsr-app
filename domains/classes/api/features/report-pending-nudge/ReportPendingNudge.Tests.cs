using NUnit.Framework;
using Tsr.Classes.Api.Domain;

namespace Tsr.Classes.Api.Features.ReportPendingNudge;

[TestFixture]
public sealed class ReportPendingNudgeTests
{
    private static PendingRules.PendingTeacher Teacher(params PendingRules.PendingClass[] classes) => new(5, "T", 0, 0, classes);

    private static PendingRules.PendingClass Class(int id, string code, int forms, int mcqs) => new(id, "L", code, forms, mcqs, 0, 0);

    [Test]
    public void Each_class_is_a_block_with_its_number_and_what_is_pending()
    {
        var (title, body) = ReportPendingNudgeSlice.Message(Teacher(Class(1, "A1", 3, 2), Class(2, "B1", 1, 0), Class(3, "C1", 0, 1)));

        Assert.That(title, Is.EqualTo("Pending C Form Reminder"));
        Assert.That(body, Is.EqualTo(
            "Salaamun Alaikum\n\n"
            + "Class Number: A1\nPending C Form(s): 3\nPending MCQ(s): 2\n\n"
            + "Class Number: B1\nPending C Form(s): 1\n\n"
            + "Class Number: C1\nPending MCQ(s): 1\n\n"
            + "TSR CC Team"));
    }

    [Test]
    public void The_message_does_not_name_the_teacher()
    {
        var (title, body) = ReportPendingNudgeSlice.Message(new PendingRules.PendingTeacher(5, "Teacher A", 0, 0, [Class(1, "CLASS1", 1, 0)]));

        Assert.That(title + body, Does.Not.Contain("Teacher A"));
    }

    [Test]
    public void A_long_list_is_cut_to_500_characters_with_the_count_of_the_rest()
    {
        var classes = Enumerable.Range(1, 40).Select(i => Class(i, "CLASS-" + i, 4, 4)).ToArray();

        var (_, body) = ReportPendingNudgeSlice.Message(Teacher(classes));

        Assert.That(body.EnumerateRunes().Count(), Is.LessThanOrEqualTo(500));
        Assert.That(body, Does.Contain("\n\n…and ").And.EndWith(" more classes\n\nTSR CC Team"));
    }

    [Test]
    public void One_class_left_over_is_counted_in_the_singular()
    {
        // Each block is 73 characters: six fit in 500 with room for the line of the rest, the seventh does not.
        var classes = Enumerable.Range(1, 7).Select(i => Class(i, "CLASS-NUMBER-" + i, 1000, 1000)).ToArray();

        var (_, body) = ReportPendingNudgeSlice.Message(Teacher(classes));

        Assert.That(body, Does.EndWith("Class Number: CLASS-NUMBER-6\nPending C Form(s): 1000\nPending MCQ(s): 1000\n\n…and 1 more class\n\nTSR CC Team"));
    }
}
