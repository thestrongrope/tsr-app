using NUnit.Framework;

namespace Tsr.Membership.Api.Domain;

/// <summary>PHP EntityAccessModel::genderOf: 1 and 2, or the words Male and Female, else not recorded (the card differs from the children list's (int) cast).</summary>
[TestFixture]
internal sealed class CardRulesTests
{
    [TestCase("1", 1)]
    [TestCase("Male", 1)]
    [TestCase("2", 2)]
    [TestCase("Female", 2)]
    [TestCase("male", null)]
    [TestCase("", null)]
    [TestCase(null, null)]
    [TestCase("3", null)]
    public void The_stored_gender_text_becomes_one_two_or_nothing(string? stored, int? expected) =>
        Assert.That(CardRules.GenderOf(stored), Is.EqualTo(expected));

    [Test]
    public void A_reach_of_every_class_covers_any_class() => Assert.That(CardRules.Reaches(true, null, [], 5, 2), Is.True);

    [Test]
    public void A_gender_reach_covers_the_classes_of_that_gender_only()
    {
        Assert.That(CardRules.Reaches(false, 1, [], 5, 1), Is.True);
        Assert.That(CardRules.Reaches(false, 1, [], 5, 2), Is.False);
        Assert.That(CardRules.Reaches(false, 1, [], 5, null), Is.False);
    }

    [Test]
    public void An_assigned_class_is_covered_whatever_its_gender()
    {
        Assert.That(CardRules.Reaches(false, null, [4, 5], 5, 2), Is.True);
        Assert.That(CardRules.Reaches(false, null, [4, 5], 6, 1), Is.False);
        Assert.That(CardRules.Reaches(false, 1, [5], 5, 2), Is.True);
    }
}
