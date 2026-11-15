using NUnit.Framework;

namespace Tsr.Membership.Api.Domain;

[TestFixture]
internal sealed class AllocatedRegistrationsTests
{
    // PHP: $genders = ['Not mentioned', 'Male', 'Female']; $genders[(int) $stored] ?? null.
    [TestCase("1", "Male")]
    [TestCase("2", "Female")]
    [TestCase("0", "Not mentioned")]
    [TestCase("", "Not mentioned")]
    [TestCase("Male", "Not mentioned")]
    [TestCase(null, "Not mentioned")]
    [TestCase("2abc", "Female")]
    [TestCase(" 1", "Male")]
    [TestCase("3", null)]
    [TestCase("-1", null)]
    [TestCase("99999999999999999999", null)]
    public void The_gender_label_is_PHP_indexing_a_list_by_the_integer_value_of_the_text(string? stored, string? expected) =>
        Assert.That(AllocatedRegistrations.GenderLabel(stored), Is.EqualTo(expected));

    [TestCase("0", "Not mentioned")]
    [TestCase("1", "Less than 15")]
    [TestCase("2", "15 to 25")]
    [TestCase("3", "26 to 40")]
    [TestCase("4", "Above 40")]
    [TestCase("5", null)]
    [TestCase(null, "Not mentioned")]
    public void The_age_range_label_is_PHP_indexing_a_list_by_the_integer_value_of_the_text(string? stored, string? expected) =>
        Assert.That(AllocatedRegistrations.AgeRangeLabel(stored), Is.EqualTo(expected));

    [TestCase(null, null, "")]
    [TestCase("Quran", null, "Quran")]
    [TestCase("Quran", "", "Quran")]
    [TestCase("Quran", "0", "Quran")]
    [TestCase("Quran", "History", "Quran,History")]
    [TestCase("Quran", "Fiqh ,Tafsir ,x", "Quran,Fiqh,Tafsir,x")]
    [TestCase(null, "History", ",History")]
    public void The_interests_are_the_list_then_a_comma_and_the_other_interests_with_a_space_before_a_comma_removed(string? interests, string? other, string expected) =>
        Assert.That(AllocatedRegistrations.Interests(interests, other), Is.EqualTo(expected));

    [TestCase(null, 0)]
    [TestCase("", 0)]
    [TestCase("  \n ", 0)]
    [TestCase("one", 1)]
    [TestCase("one\ntwo", 2)]
    [TestCase("one\ntwo\n", 3)]
    [TestCase("\none", 2)]
    public void The_extra_students_are_the_lines_of_the_text_and_none_when_it_is_blank(string? extra, int expected) =>
        Assert.That(AllocatedRegistrations.ExtraStudents(extra), Is.EqualTo(expected));
}
