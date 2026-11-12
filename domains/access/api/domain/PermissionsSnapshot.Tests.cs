using NUnit.Framework;

namespace Tsr.Access.Api.Domain;

/// <summary>
/// What GET /me/permissions adds to the resolved state, with no database: PHP's PermissionsModel::navigation and
/// ::revision. The two revision values were computed by PHP's own code (json_encode, sha256, 16 hex) for the same input.
/// </summary>
public sealed class PermissionsSnapshotTests
{
    private static readonly AccessScopes NoScopes = new(null, [], [], [], [], []);

    private static UserAccess Access(string[] permissions, AccessScopes? scopes = null) => new(permissions, scopes ?? NoScopes);

    private static string RevisionOf(UserAccess access) =>
        PermissionsSnapshot.RevisionOf(PermissionsSnapshot.PayloadVersion, access, PermissionsSnapshot.NavigationOf(access));

    // --- navigation ---

    [Test]
    public void A_member_with_no_class_and_no_admin_module_has_neither_tab()
    {
        var navigation = PermissionsSnapshot.NavigationOf(Access(["classes:read:enrolled", "profile:read:self"]));

        Assert.That(navigation, Is.EqualTo(new Navigation(false, false)));
    }

    [TestCase("enrolled")]
    [TestCase("taught")]
    [TestCase("own")]
    [TestCase("assigned")]
    public void Any_class_in_a_scope_gives_the_classes_tab(string scope)
    {
        int[] one = [7];
        var scopes = new AccessScopes(
            null,
            scope == "assigned" ? one : [],
            [],
            scope == "own" ? one : [],
            scope == "taught" ? one : [],
            scope == "enrolled" ? one : []);

        Assert.That(PermissionsSnapshot.NavigationOf(Access(["classes:read:enrolled"], scopes)).Classes, Is.True);
    }

    [TestCase("classes:read:gender", true)]
    [TestCase("classes:read:all", true)]
    [TestCase("classes:read:assigned", false)]
    [TestCase("classes:read:enrolled", false)]
    public void Reading_classes_gives_the_classes_tab_only_for_a_gender_or_every_class(string held, bool expected)
    {
        Assert.That(PermissionsSnapshot.NavigationOf(Access([held])).Classes, Is.EqualTo(expected));
    }

    [TestCase("donors:read:all", true)]
    [TestCase("reports:read:assigned", true)]
    [TestCase("teachers:read:gender", true)]
    [TestCase("quiz:admin:all", true)]
    [TestCase("notifications:send:all", true)]
    [TestCase("notifications:send:own", false)]
    [TestCase("notifications:send:gender", false)]
    [TestCase("notifications:broadcast:all", true)]
    [TestCase("syllabus:update:all", true)]
    [TestCase("syllabus:read:all", false)]
    [TestCase("feedback:review:all", false)]
    public void An_admin_module_permission_gives_the_manage_tab_and_three_of_them_only_at_scope_all(string held, bool expected)
    {
        Assert.That(PermissionsSnapshot.NavigationOf(Access([held])).Manage, Is.EqualTo(expected));
    }

    [Test]
    public void There_are_PHPs_18_admin_module_permissions()
    {
        Assert.That(PermissionsSnapshot.AdminModulePermissions, Has.Count.EqualTo(18));
    }

    // --- revision ---

    [Test]
    public void The_revision_of_nothing_held_equals_PHPs()
    {
        Assert.That(RevisionOf(UserAccess.None), Is.EqualTo("0045e40320b84ca0"));
    }

    [Test]
    public void The_revision_of_a_full_answer_equals_PHPs()
    {
        var access = Access(
            ["classes:read:enrolled", "classes:read:gender", "reports:read:gender"],
            new AccessScopes(1, [7, 7, 9], [1, 2], [3], [3], [4, 5]));

        Assert.That(PermissionsSnapshot.NavigationOf(access), Is.EqualTo(new Navigation(true, true)));
        Assert.That(RevisionOf(access), Is.EqualTo("c50f91075e95c4f5"));
    }

    [Test]
    public void Equal_state_gives_an_equal_revision()
    {
        var first = Access(["profile:read:self"], new AccessScopes(2, [], [], [], [], [5]));
        var second = Access(["profile:read:self"], new AccessScopes(2, [], [], [], [], [5]));

        Assert.That(RevisionOf(second), Is.EqualTo(RevisionOf(first)));
    }

    [Test]
    public void Every_part_of_the_answer_changes_the_revision()
    {
        var revisions = new[]
        {
            RevisionOf(Access(["profile:read:self"])),
            RevisionOf(Access(["profile:read:self", "donors:read:all"])),
            RevisionOf(Access(["profile:read:self"], new AccessScopes(1, [], [], [], [], []))),
            RevisionOf(Access(["profile:read:self"], new AccessScopes(null, [5], [], [], [], []))),
            RevisionOf(Access(["profile:read:self"], new AccessScopes(null, [], [1], [], [], []))),
            RevisionOf(Access(["profile:read:self"], new AccessScopes(null, [], [], [5], [], []))),
            RevisionOf(Access(["profile:read:self"], new AccessScopes(null, [], [], [], [5], []))),
            RevisionOf(Access(["profile:read:self"], new AccessScopes(null, [], [], [], [], [5]))),
            PermissionsSnapshot.RevisionOf(PermissionsSnapshot.PayloadVersion + 1, Access(["profile:read:self"]), new Navigation(false, false)),
            PermissionsSnapshot.RevisionOf(PermissionsSnapshot.PayloadVersion, Access(["profile:read:self"]), new Navigation(true, false)),
        };

        Assert.That(revisions, Is.Unique);
        Assert.That(revisions, Has.All.Match("^[0-9a-f]{16}$"));
    }
}
