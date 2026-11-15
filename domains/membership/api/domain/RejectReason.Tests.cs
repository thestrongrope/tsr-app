using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>The reason of POST /registrations/{id}/reject: trimmed, required, at most 500 characters (routes/registrations.php).</summary>
public sealed class RejectReasonTests
{
    [Test]
    public void A_reason_is_trimmed() => Assert.That(RejectReason.Parse("  too far \n"), Is.EqualTo("too far"));

    [TestCase(null)]
    [TestCase("")]
    [TestCase("   ")]
    [TestCase("\0 \t")]
    public void A_missing_or_blank_reason_is_refused(string? typed) => Assert.That(RejectReason.Parse(typed), Is.Null);

    [Test]
    public void Five_hundred_characters_are_allowed_and_five_hundred_and_one_are_not()
    {
        Assert.That(RejectReason.Parse(new string('a', 500)), Is.Not.Null);
        Assert.That(RejectReason.Parse(new string('a', 501)), Is.Null);
    }

    [Test]
    public void The_limit_counts_code_points_not_utf16_units() =>
        Assert.That(RejectReason.Parse(string.Concat(Enumerable.Repeat("\U0001F600", 500))), Is.Not.Null);

    [Test]
    public void A_NUL_inside_the_text_is_refused_because_the_database_cannot_hold_it() =>
        Assert.That(RejectReason.Parse("a\0b"), Is.Null);
}
