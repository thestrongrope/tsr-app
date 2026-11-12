using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class GuideSlugsTests
{
    [TestCase("abuzar", 2)]
    [TestCase("miqdad", 3)]
    [TestCase("ammar", 4)]
    [TestCase("bilal", 5)]
    [TestCase("salman", null)]
    [TestCase("Miqdad", null)]
    [TestCase("MIQDAD", null)]
    [TestCase("miqdad ", null)]
    [TestCase(" miqdad", null)]
    [TestCase("miqdad.php", null)]
    [TestCase("3", null)]
    [TestCase("", null)]
    public void A_slug_names_its_level_only_when_it_is_exactly_PHPs_slug(string slug, int? expected) =>
        Assert.That(GuideSlugs.LevelFor(slug), Is.EqualTo(expected));

    [TestCase(2)]
    [TestCase(3)]
    [TestCase(4)]
    [TestCase(5)]
    public void A_level_with_a_slug_is_found_again_by_that_slug(int levelId) =>
        Assert.That(GuideSlugs.LevelFor(GuideSlugs.ForLevel(levelId)!), Is.EqualTo(levelId));
}
