using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class EnrolmentRulesTests
{
    [TestCase("1", 1)]
    [TestCase("Male", 1)]
    [TestCase("2", 2)]
    [TestCase("Female", 2)]
    [TestCase("male", null)]
    [TestCase("01", null)]
    [TestCase("3", null)]
    [TestCase("", null)]
    [TestCase(null, null)]
    public void A_stored_gender_is_one_two_or_unknown_as_PHP_genderOf_reads_it(string? stored, int? expected) =>
        Assert.That(EnrolmentRules.GenderOf(stored), Is.EqualTo(expected));

    [TestCase("1", 1, true)]
    [TestCase("Female", 2, true)]
    [TestCase("1", 2, false)]
    [TestCase("Male", 2, false)]
    [TestCase("", 1, true)]
    [TestCase(null, 2, true)]
    [TestCase("1", null, false)]
    [TestCase(null, null, true)]
    public void A_member_of_unknown_gender_may_join_any_class_and_a_known_gender_must_match(string? member, int? classGender, bool allowed) =>
        Assert.That(EnrolmentRules.GenderAllows(member, classGender), Is.EqualTo(allowed));

    [TestCase("transfer", "", 5, "Transfer to class #5")]
    [TestCase("promotion", "moved up", 7, "Promotion to class #7: moved up")]
    [TestCase("demotion", "0", 7, "Demotion to class #7")]
    public void The_removal_reason_of_a_transfer_names_the_destination_and_a_truthy_reason(string type, string reason, int toClass, string expected) =>
        Assert.That(EnrolmentRules.TransferReason(type, reason, toClass), Is.EqualTo(expected));
}
