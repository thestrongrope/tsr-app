using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class NaturalCompareTests
{
    [TestCase("img2.png", "img10.png", -1)]
    [TestCase("img10.png", "img2.png", 1)]
    [TestCase("img12.png", "img10.png", 1)]
    [TestCase("abc", "abc", 0)]
    [TestCase("a", "b", -1)]
    [TestCase("RC-G-9", "RC-G-10", -1)]
    [TestCase("RC-G-564", "RC-G-565", -1)]
    [TestCase("", "a", -1)]
    [TestCase("a", "", 1)]
    [TestCase("", "", 0)]
    [TestCase("A1", "a1", -1)]
    [TestCase("a1b", "a1", 1)]
    [TestCase("1.001", "1.002", -1)]
    public void Digit_runs_compare_as_numbers_and_the_rest_by_byte(string a, string b, int expected) =>
        Assert.That(Math.Sign(NaturalCompare.Compare(a, b)), Is.EqualTo(expected));
}
