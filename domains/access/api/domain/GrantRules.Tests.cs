using NUnit.Framework;

namespace Tsr.Access.Api.Domain;

/// <summary>What may be granted and why a grant is refused (PHP PermissionGrantsModel), no database.</summary>
public sealed class GrantRulesTests
{
    private static readonly PermissionInfo[] Catalog =
    [
        new("classes:read:all", "Read every class"),
        new("classes:read:gender", "Read own gender"),
        new("permissions:manage:all", "Manage permissions"),
        new("class-access:manage:all", "Manage class access"),
        new("members:enrol-by-token:all", "Enrol by token"),
        new("reports:read:all", "Reports"),
        new("profile:read:self", "Own profile"),
    ];

    [Test]
    public void Only_scope_all_is_grantable_and_the_three_excluded_names_never_are()
    {
        var grantable = GrantRules.Grantable(Catalog, []);

        Assert.That(grantable.Select(p => p.Name), Is.EqualTo(Expect.List("classes:read:all", "reports:read:all")));
    }

    [Test]
    public void A_held_permission_is_not_grantable_again()
    {
        var grantable = GrantRules.Grantable(Catalog, ["reports:read:all"]);

        Assert.That(grantable.Select(p => p.Name), Is.EqualTo(Expect.List("classes:read:all")));
    }

    [Test]
    public void The_reach_follows_the_scope_at_the_end_of_the_name()
    {
        Assert.That(GrantRules.ReachOf("classes:read:all"), Is.EqualTo("In every class and for every member"));
        Assert.That(GrantRules.ReachOf("profile:read:self"), Is.EqualTo("Their own data only"));
        Assert.That(GrantRules.ReachOf("odd:name:other"), Is.Empty);
    }

    [TestCase("classes:read:all", null)]
    [TestCase("reports:read:all", 409)]
    [TestCase("permissions:manage:all", 409)]
    [TestCase("members:enrol-by-token:all", 422)]
    [TestCase("no-such:permission:all", 422)]
    [TestCase("classes:read:gender", 422)]
    public void A_grant_is_refused_as_held_409_or_not_grantable_422(string permission, int? status)
    {
        var held = new[] { "reports:read:all", "permissions:manage:all" };
        var grantable = GrantRules.Grantable(Catalog, held);

        Assert.That(GrantRules.RefuseGrant(permission, grantable, held)?.Status, Is.EqualTo(status));
    }

    [TestCase("  needs it for the audit  ", true)]
    [TestCase("", false)]
    [TestCase("   ", false)]
    [TestCase("bad\0reason", false)]
    public void A_reason_is_trimmed_required_and_free_of_NUL(string reason, bool ok)
    {
        var outcome = GrantRules.CheckedReason(reason);

        Assert.That(outcome.Failed, Is.EqualTo(!ok));
        Assert.That(outcome.Refusal?.Status ?? 422, Is.EqualTo(422));
    }

    [Test]
    public void A_reason_may_be_300_characters_and_not_301()
    {
        Assert.That(GrantRules.CheckedReason(new string('a', 300)).Failed, Is.False);
        Assert.That(GrantRules.CheckedReason(new string('a', 301)).Failed, Is.True);
    }
}
