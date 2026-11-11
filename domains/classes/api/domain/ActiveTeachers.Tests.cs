using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class ActiveTeachersTests
{
    private static ActiveTeachers.ClassRow Class(int teacher, string name, int id, string code, int levelId, int sort, string level) =>
        new(teacher, name, id, code, levelId, sort, level);

    private static ActiveTeachers.AttendRow Attend(int token, int id, string code, int sort, string? teacherName) => new(token, id, code, sort, teacherName);

    [Test]
    public void A_teacher_has_the_level_of_the_lowest_level_id_the_class_count_and_the_codes_in_level_then_id_order()
    {
        var items = ActiveTeachers.Build(
            [Class(7, "T", 30, "B", 3, 3, "MIQDAD"), Class(7, "T", 20, "A", 2, 2, "ABUZAR"), Class(7, "T", 10, "C", 3, 3, "MIQDAD")], []);
        Assert.That(items, Has.Count.EqualTo(1));
        Assert.That(items[0].MaxLevel, Is.EqualTo("ABUZAR"));
        Assert.That(items[0].TotalClasses, Is.EqualTo(3));
        Assert.That(items[0].ConductingClasses, Is.EqualTo("A, C, B"));
        Assert.That(items[0].AttendingClass, Is.Null);
        Assert.That(items[0].SelfTeacher, Is.Null);
    }

    [Test]
    public void A_code_shared_by_two_classes_is_listed_once_but_both_classes_count()
    {
        var items = ActiveTeachers.Build([Class(7, "T", 1, "X", 1, 1, "SALMAN"), Class(7, "T", 2, "X", 1, 1, "SALMAN")], []);
        Assert.That(items[0].TotalClasses, Is.EqualTo(2));
        Assert.That(items[0].ConductingClasses, Is.EqualTo("X"));
    }

    [Test]
    public void The_classes_a_teacher_attends_are_listed_with_their_teachers_and_a_missing_name_is_skipped_like_GROUP_CONCAT()
    {
        var items = ActiveTeachers.Build(
            [Class(7, "T", 1, "X", 1, 1, "SALMAN")],
            [Attend(7, 12, "P2", 2, "Two"), Attend(7, 11, "P1", 2, null), Attend(7, 13, "P0", 1, "Zero"), Attend(8, 14, "OTHER", 1, "Other")]);
        Assert.That(items[0].AttendingClass, Is.EqualTo("P0, P1, P2"));
        Assert.That(items[0].SelfTeacher, Is.EqualTo("Zero, Two"));
    }

    [Test]
    public void Attending_classes_whose_teachers_have_no_name_leave_the_self_teacher_null()
    {
        var items = ActiveTeachers.Build([Class(7, "T", 1, "X", 1, 1, "SALMAN")], [Attend(7, 11, "P1", 1, null)]);
        Assert.That(items[0].AttendingClass, Is.EqualTo("P1"));
        Assert.That(items[0].SelfTeacher, Is.Null);
    }

    [Test]
    public void Teachers_are_sorted_by_lower_case_ASCII_name_then_token()
    {
        var items = ActiveTeachers.Build(
            [Class(9, "bob", 1, "A", 1, 1, "L"), Class(5, "Bob", 2, "B", 1, 1, "L"), Class(4, "alice", 3, "C", 1, 1, "L"), Class(3, "Zed", 4, "D", 1, 1, "L")], []);
        Assert.That(items.Select(i => i.Token).ToArray(), Is.EqualTo((int[])[4, 5, 9, 3]));
    }
}
