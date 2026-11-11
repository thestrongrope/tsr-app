using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class StudentEditRulesTests
{
    private const string OtherToken = "Email can only be 5@thestrongrope.com (your token) or a real email address. Cannot use other token emails.";
    private const string Invalid = "Please provide a valid email address";

    [TestCase("", null)]
    [TestCase("5@thestrongrope.com", null)]
    [TestCase("5@THESTRONGROPE.COM", null)]
    [TestCase("6@thestrongrope.com", OtherToken)]
    [TestCase("06@thestrongrope.com", OtherToken)]
    [TestCase("05@thestrongrope.com", null)]
    [TestCase("a.b@example.com", null)]
    [TestCase("a+b_c@sub.example.co.uk", null)]
    [TestCase("not an email", Invalid)]
    [TestCase("a@", Invalid)]
    [TestCase("@example.com", Invalid)]
    [TestCase("a@@example.com", Invalid)]
    [TestCase("a..b@example.com", Invalid)]
    [TestCase(".a@example.com", Invalid)]
    [TestCase("a@example", Invalid)]
    [TestCase("a@-example.com", Invalid)]
    [TestCase("a b@example.com", Invalid)]
    [TestCase("name@thestrongrope.com", null)]
    public void An_email_is_accepted_as_PHPs_studentEmailError_does(string email, string? expected) =>
        Assert.That(StudentEditRules.EmailError(5, email), Is.EqualTo(expected));

    [Test]
    public void A_local_part_over_64_characters_is_not_an_email() =>
        Assert.That(StudentEditRules.EmailError(5, new string('a', 65) + "@example.com"), Is.EqualTo(Invalid));

    [TestCase("", null)]
    [TestCase("0", null)]
    [TestCase("Ali", "Ali")]
    public void A_name_is_written_only_when_PHPs_empty_would_say_it_is_not_empty(string name, string? expected) =>
        Assert.That(StudentEditRules.NameToWrite(name), Is.EqualTo(expected));

    [Test]
    public void An_email_longer_than_254_characters_is_refused_as_PHPs_filter_refuses_it()
    {
        var label = new string('b', 60);
        var email = "x@" + string.Join('.', label, label, label, label, label) + ".example";
        Assert.That(email.Length, Is.GreaterThan(254));
        Assert.That(StudentEditRules.EmailError(5, email), Is.EqualTo(Invalid));
    }
}
