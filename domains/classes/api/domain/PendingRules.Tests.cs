using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class PendingRulesTests
{
    private static PendingRules.ClassRow Row(int id, int teacher, string name, string level = "MIQDAD") => new(id, "C-" + id, level, teacher, name, string.Empty);

    private static readonly Dictionary<int, PendingRules.Mcq> NoMcq = [];

    private static readonly int[] OrderedTokens = [5, 3, 4, 2, 1];

    private static readonly string[] Names = ["First", ""];

    [Test]
    public void A_class_with_nothing_pending_is_left_out_and_a_teacher_without_classes_is_not_listed()
    {
        var teachers = PendingRules.Group([Row(1, 10, "Amir")], new Dictionary<int, int> { [1] = 0 }, new Dictionary<int, PendingRules.Mcq> { [1] = new(5, 5, 0) });

        Assert.That(teachers, Is.Empty);
    }

    [Test]
    public void Classes_are_grouped_under_their_teacher_with_the_totals_and_the_forms_never_below_zero()
    {
        var notFilled = new Dictionary<int, int> { [1] = 2, [2] = -1, [3] = 4 };
        var mcqs = new Dictionary<int, PendingRules.Mcq> { [2] = new(6, 2, 3) };

        var teachers = PendingRules.Group([Row(1, 10, "Amir"), Row(2, 10, "Amir"), Row(3, 20, "Bilal")], notFilled, mcqs);

        Assert.That(teachers.Select(t => (t.TeacherToken, t.Teacher, t.NotFilled, t.McqPending)), Is.EqualTo(new[] { (20, "Bilal", 4, 0), (10, "Amir", 2, 3) }));
        Assert.That(teachers[1].Classes.Select(c => (c.ClassId, c.NotFilled, c.McqPending, c.McqConducted, c.McqExpected)), Is.EqualTo(new[] { (1, 2, 0, 0, 0), (2, 0, 3, 2, 6) }));
    }

    [Test]
    public void Teachers_are_ordered_by_forms_then_mcqs_pending_then_lower_case_name_and_equal_ones_keep_their_first_seen_order()
    {
        var notFilled = new Dictionary<int, int> { [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 3 };
        var mcqs = new Dictionary<int, PendingRules.Mcq> { [1] = new(1, 0, 1), [2] = new(1, 0, 2), [3] = new(1, 0, 2), [4] = new(1, 0, 2) };

        var teachers = PendingRules.Group([Row(1, 1, "zed"), Row(2, 2, "Bob"), Row(3, 3, "amy"), Row(4, 4, "Amy"), Row(5, 5, "Last")], notFilled, mcqs);

        Assert.That(teachers.Select(t => t.TeacherToken), Is.EqualTo(OrderedTokens), "3 forms; then 2 mcqs: amy, amy (3 before 4, first seen), Bob; then 1 mcq: zed");
    }

    [Test]
    public void A_teacher_takes_the_name_of_their_first_class_and_a_missing_name_is_empty()
    {
        var teachers = PendingRules.Group([Row(1, 10, "First"), Row(2, 10, "Second"), Row(3, 20, "")], new Dictionary<int, int> { [1] = 1, [2] = 1, [3] = 1 }, NoMcq);

        Assert.That(teachers.Select(t => t.Teacher), Is.EqualTo(Names));
    }

    [Test]
    public void Narrowing_to_a_level_keeps_that_level_recounts_the_totals_drops_empty_teachers_and_keeps_the_order()
    {
        var notFilled = new Dictionary<int, int> { [1] = 5, [2] = 1, [3] = 2 };
        var mcqs = new Dictionary<int, PendingRules.Mcq> { [2] = new(4, 0, 4) };
        var teachers = PendingRules.Group([Row(1, 10, "Amir", "SALMAN"), Row(2, 10, "Amir", "MIQDAD"), Row(3, 20, "Bilal", "SALMAN")], notFilled, mcqs);

        var narrowed = PendingRules.InLevel(teachers, "MIQDAD");

        Assert.That(narrowed.Select(t => (t.TeacherToken, t.NotFilled, t.McqPending, t.Classes.Count)), Is.EqualTo(new[] { (10, 1, 4, 1) }));
        Assert.That(PendingRules.InLevel(teachers, "salman"), Is.Empty, "the level is compared exactly");
        Assert.That(PendingRules.InLevel(teachers, "SALMAN").Select(t => (t.TeacherToken, t.NotFilled)), Is.EqualTo(new[] { (10, 5), (20, 2) }));
    }
}
