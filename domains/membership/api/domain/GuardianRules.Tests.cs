using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>Invite state, the relationship word and PHP's messages for the guardian operations.</summary>
public sealed class GuardianRulesTests
{
    private static readonly DateTimeOffset Now = new(2026, 6, 1, 12, 0, 0, TimeSpan.Zero);

    [Test]
    public void An_invited_link_with_no_expiry_or_a_future_one_is_usable()
    {
        Assert.That(GuardianRules.IsUsable("invited", null, Now), Is.True);
        Assert.That(GuardianRules.IsUsable("invited", Now.AddSeconds(1), Now), Is.True);
    }

    [Test]
    public void A_link_that_expires_now_or_earlier_is_not_usable()
    {
        Assert.That(GuardianRules.IsUsable("invited", Now, Now), Is.False, "strtotime(expires_at) <= time() is expired");
        Assert.That(GuardianRules.IsUsable("invited", Now.AddSeconds(-1), Now), Is.False);
    }

    [TestCase("active")]
    [TestCase("revoked")]
    public void A_link_that_is_not_invited_is_not_usable(string status) =>
        Assert.That(GuardianRules.IsUsable(status, null, Now), Is.False);

    [TestCase("father", "father")]
    [TestCase("  Mother ", "mother")]
    [TestCase("GUARDIAN", "guardian")]
    [TestCase("\tFather\n", "father")]
    public void A_relationship_is_trimmed_and_lower_cased(string typed, string expected) =>
        Assert.That(GuardianRules.Relationship(typed), Is.EqualTo(expected));

    [TestCase("")]
    [TestCase("uncle")]
    [TestCase("fathers")]
    [TestCase("father ")]
    public void Any_other_relationship_is_refused(string typed) => Assert.That(GuardianRules.Relationship(typed), Is.Null);

    [Test]
    public void The_Kelvin_sign_is_not_a_k_for_the_relationship() =>
        Assert.That(GuardianRules.Relationship("K"), Is.Null);

    [Test]
    public void No_row_is_not_found()
    {
        Assert.That(GuardianRules.InspectState(null, null, Now), Is.EqualTo("not_found"));
    }

    [Test]
    public void A_used_cancelled_or_past_invite_is_expired_and_a_live_one_valid()
    {
        Assert.That(GuardianRules.InspectState("active", null, Now), Is.EqualTo("expired"));
        Assert.That(GuardianRules.InspectState("revoked", null, Now), Is.EqualTo("expired"));
        Assert.That(GuardianRules.InspectState("invited", Now.AddDays(-1), Now), Is.EqualTo("expired"));
        Assert.That(GuardianRules.InspectState("invited", Now, Now), Is.EqualTo("expired"));
        Assert.That(GuardianRules.InspectState("invited", Now.AddDays(1), Now), Is.EqualTo("valid"));
        Assert.That(GuardianRules.InspectState("invited", null, Now), Is.EqualTo("valid"));
    }
}
