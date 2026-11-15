using NUnit.Framework;

namespace Tsr.Classes.Api.Features.ReportThisWeek;

/// <summary>The cases of PHP's own test of the rule (tsr-account <c>tests/web/PhoneNumberModelTest.php</c>), with invented numbers.</summary>
[TestFixture]
public sealed class DialableNumberTests
{
    [TestCase("3125550100", "United States", "+13125550100")]
    [TestCase("(312) 555-0100", "USA", "+13125550100")]
    [TestCase("9000000001", "India", "+919000000001")]
    public void A_local_number_takes_the_calling_code_of_the_member_s_country(string mobile, string country, string expected) =>
        Assert.That(DialableNumber.Of(mobile, country), Is.EqualTo(expected));

    [TestCase("0700000001", "Tanzania", "+255700000001")]
    [TestCase("0500000001", "UAE", "+971500000001")]
    [TestCase("09000000001", "India", "+919000000001")]
    public void A_leading_zero_is_dropped_before_the_calling_code(string mobile, string country, string expected) =>
        Assert.That(DialableNumber.Of(mobile, country), Is.EqualTo(expected));

    [TestCase("+65 9123 4567", "India", "+6591234567")]
    [TestCase("+1 312 555 0100", null, "+13125550100")]
    // More than ten digits is a number that already carries its code.
    [TestCase("919000000001", "United States", "+919000000001")]
    [TestCase("00971500000001", "UAE", "+971500000001")]
    public void A_number_saved_with_its_country_code_is_used_as_saved(string mobile, string? country, string expected) =>
        Assert.That(DialableNumber.Of(mobile, country), Is.EqualTo(expected));

    [TestCase("9000000001", " india ", "+919000000001")]
    [TestCase("9000000001", "India Mumbai", "+919000000001")]
    [TestCase("3125550100", "United States of America", "+13125550100")]
    [TestCase("500000001", "United Arab Emirates", "+971500000001")]
    public void The_country_is_read_as_members_type_it(string mobile, string country, string expected) =>
        Assert.That(DialableNumber.Of(mobile, country), Is.EqualTo(expected));

    [TestCase(null)]
    [TestCase("")]
    [TestCase("Atlantis")]
    // A short name matches whole, never as the start of another word.
    [TestCase("Ukraine")]
    [TestCase("Usakistan")]
    public void A_local_number_with_no_known_country_is_not_guessed(string? country) =>
        Assert.That(DialableNumber.Of("9000000001", country), Is.Empty);

    [TestCase("1234")]
    [TestCase("+91 1234")]
    [TestCase("n/a")]
    [TestCase(null)]
    // Only the digits 0 to 9 count, as in PHP: these seven are not.
    [TestCase("٩٠٠٠٠٠٠")]
    public void A_number_too_short_to_dial_is_empty(string? mobile) =>
        Assert.That(DialableNumber.Of(mobile, "India"), Is.Empty);
}
