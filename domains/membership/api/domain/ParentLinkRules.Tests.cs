using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>PHP's decision order for the staff parent-link operations (routes/children.php api_require_parent_link_create, GuardiansModel::addDirect).</summary>
public sealed class ParentLinkRulesTests
{
    [Test]
    public void A_token_of_zero_or_less_is_a_missing_student_before_any_permission_is_asked() =>
        Assert.That(ParentLinkRules.Decide(childToken: 0, callerToken: 0, holdsManage: true, staffMay: true, holdsAdd: true), Is.EqualTo(LinkGuard.StudentNotFound));

    [Test]
    public void A_student_creating_for_themselves_needs_parents_manage()
    {
        Assert.That(ParentLinkRules.Decide(5, 5, holdsManage: true, staffMay: false, holdsAdd: false), Is.EqualTo(LinkGuard.Allowed));
        Assert.That(ParentLinkRules.Decide(5, 5, holdsManage: false, staffMay: false, holdsAdd: false), Is.EqualTo(LinkGuard.Forbidden));
    }

    [Test]
    public void Staff_in_reach_are_allowed_without_asking_for_the_plain_permission() =>
        Assert.That(ParentLinkRules.Decide(5, 9, holdsManage: false, staffMay: true, holdsAdd: false), Is.EqualTo(LinkGuard.Allowed));

    [Test]
    public void Staff_out_of_reach_are_refused_when_they_lack_the_permission_and_told_not_found_when_they_have_it()
    {
        Assert.That(ParentLinkRules.Decide(5, 9, false, staffMay: false, holdsAdd: false), Is.EqualTo(LinkGuard.Forbidden));
        Assert.That(ParentLinkRules.Decide(5, 9, false, staffMay: false, holdsAdd: true), Is.EqualTo(LinkGuard.StudentNotFound));
    }

    [Test]
    public void A_direct_add_checks_self_link_then_staff_self_then_the_relationship()
    {
        Assert.That(ParentLinkRules.DirectRefusal(parentToken: 7, childToken: 7, callerToken: 7, relationship: "x"), Is.EqualTo(GuardianRules.InvalidLink));
        Assert.That(ParentLinkRules.DirectRefusal(7, 8, callerToken: 7, relationship: "father"), Is.EqualTo(GuardianRules.InvalidLink));
        Assert.That(ParentLinkRules.DirectRefusal(7, 8, 9, "  MOTHER "), Is.Null);
        Assert.That(ParentLinkRules.DirectRefusal(7, 8, 9, "uncle"), Is.EqualTo(GuardianRules.InvalidLink));
    }

    [Test]
    public void The_stored_relationship_is_trimmed_and_lower_case() =>
        Assert.That(ParentLinkRules.DirectRelationship("  MOTHER "), Is.EqualTo("mother"));
}
