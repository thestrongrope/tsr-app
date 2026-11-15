using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class MemberLookupTests
{
    [TestCase("900991", 900991)]
    [TestCase("1", 1)]
    [TestCase("0", 0)]
    [TestCase("007", 7)]
    [TestCase("900991\n", 900991)]
    public void A_path_of_plain_digits_is_the_token(string raw, int expected) =>
        Assert.That(MemberLookup.TokenOf(raw), Is.EqualTo(expected));

    [TestCase("")]
    [TestCase("abc")]
    [TestCase("5abc")]
    [TestCase("-5")]
    [TestCase(" 5")]
    [TestCase("5.0")]
    [TestCase("1234567890123456789")]
    [TestCase("٥٦")]
    [TestCase("3000000000")]
    public void Anything_else_is_the_guest_token_which_is_never_found(string raw) =>
        Assert.That(MemberLookup.TokenOf(raw), Is.EqualTo(0));
}
