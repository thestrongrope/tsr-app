using NUnit.Framework;

namespace Tsr.Access.Api.Domain;

/// <summary>
/// The decision rules, with no database: PHP's PermissionsModel (resolve, check, managedReach) copied as it behaves.
/// Tests named "Quirk" pin behaviour that looks wrong and is kept on purpose (phase-2-design.md, "Quirks").
/// </summary>
public sealed class AccessEngineTests
{
    private static readonly string[] Catalog = new[]
    {
        "classes:read:all", "classes:read:assigned", "classes:read:enrolled", "classes:read:gender", "classes:read:own",
        "registrations:read:all", "registrations:read:assigned", "registrations:read:gender",
        "teachers:read:all", "teachers:read:assigned", "teachers:read:gender",
        "profile:read:self", "sessions:create:own", "mcqs:manage:own", "class-students:update:taught",
        "donors:read:all", "quiz:admin:all", "feedback:create:self",
    }.Order(StringComparer.Ordinal).ToArray();

    private static readonly ClassMemberships NoMemberships = new([], [], []);

    private static UserAccess Resolve(
        int roleId = 0,
        string[]? stored = null,
        ClassMemberships? memberships = null,
        ClassFacts[]? assigned = null) =>
        AccessEngine.Resolve(new AccessInputs(Catalog, roleId, stored ?? [], memberships ?? NoMemberships, assigned ?? []));

    private static ClassFacts Class(int id, int gender) => new(id, gender, null, null, null, []);

    // --- what a user holds ---

    [Test]
    public void A_member_holds_the_member_set_and_nothing_else()
    {
        var access = Resolve();

        Assert.That(access.Permissions, Is.EqualTo(Expect.List("classes:read:enrolled", "feedback:create:self", "profile:read:self")));
    }

    [Test]
    public void Names_the_catalog_does_not_list_are_dropped()
    {
        var access = AccessEngine.Resolve(new AccessInputs(["profile:read:self"], 0, ["made-up:read:all"], NoMemberships, []));

        Assert.That(access.Permissions, Is.EqualTo(Expect.List("profile:read:self")));
    }

    [Test]
    public void Permissions_come_back_in_catalog_order_each_once()
    {
        var access = Resolve(stored: ["teachers:read:all", "classes:read:all", "classes:read:all", "profile:read:self"]);

        Assert.That(access.Permissions, Is.Ordered.Using<string>(StringComparer.Ordinal));
        Assert.That(access.Permissions, Is.Unique);
        Assert.That(access.Permissions, Does.Contain("teachers:read:all").And.Contain("classes:read:all"));
    }

    [Test]
    public void The_own_set_is_held_while_the_user_teaches_or_holds_an_mcq_flag()
    {
        var teaches = Resolve(memberships: new([3], [], []));
        var flagged = Resolve(memberships: new([], [4], []));

        Assert.That(teaches.Permissions, Does.Contain("sessions:create:own").And.Contain("classes:read:own"));
        Assert.That(flagged.Permissions, Does.Contain("sessions:create:own").And.Contain("mcqs:manage:own"));
        Assert.That(teaches.Scopes.Own, Is.EqualTo(Expect.List(3)));
        Assert.That(flagged.Scopes.Own, Is.EqualTo(Expect.List(4)));
    }

    [Test]
    public void The_taught_set_is_held_only_while_teaching_not_for_an_mcq_flag()
    {
        var teaches = Resolve(memberships: new([3], [], []));
        var flagged = Resolve(memberships: new([], [4], []));

        Assert.That(teaches.Permissions, Does.Contain("class-students:update:taught"));
        Assert.That(flagged.Permissions, Does.Not.Contain("class-students:update:taught"));
    }

    [Test]
    public void Own_is_the_taught_and_flagged_classes_once_in_class_order()
    {
        var access = Resolve(memberships: new([9, 3], [3, 5], [7, 2]));

        Assert.That(access.Scopes.Taught, Is.EqualTo(Expect.List(3, 9)));
        Assert.That(access.Scopes.Own, Is.EqualTo(Expect.List(3, 5, 9)));
        Assert.That(access.Scopes.Enrolled, Is.EqualTo(Expect.List(2, 7)));
    }

    [TestCase(3, 1)]
    [TestCase(4, 2)]
    public void A_gender_admin_role_gives_the_gender_scope(int role, int gender) =>
        Assert.That(Resolve(roleId: role).Scopes.Gender, Is.EqualTo(gender));

    [TestCase(0)]
    [TestCase(1)]
    [TestCase(5)]
    [TestCase(6)]
    [TestCase(7)]
    public void Other_roles_have_no_gender_scope(int role) =>
        Assert.That(Resolve(roleId: role).Scopes.Gender, Is.Null);

    [Test]
    public void Assigned_lists_the_rule_classes_and_their_genders_sorted()
    {
        var access = Resolve(assigned: [Class(8, 2), Class(2, 1), Class(5, 2)]);

        Assert.That(access.Scopes.Assigned, Is.EqualTo(Expect.List(2, 5, 8)));
        Assert.That(access.Scopes.AssignedGenders, Is.EqualTo(Expect.List(1, 2)));
    }

    [Test]
    public void The_gender_scope_comes_from_the_role_not_the_profile_gender()
    {
        // Quirk context: users.gender holds '1' and 'Male' for the same thing (PHP reads 'Male' as 0 in places).
        // access never reads it: PermissionsModel derives the scope from roleid, so the mix cannot matter here.
        var gentsAdmin = Resolve(roleId: 3);

        Assert.That(gentsAdmin.Scopes.Gender, Is.EqualTo(1));
    }

    [Test]
    public void A_guest_holds_nothing()
    {
        Assert.That(UserAccess.None.Permissions, Is.Empty);
        Assert.That(UserAccess.None.Scopes.Gender, Is.Null);
        Assert.That(UserAccess.None.Scopes.Assigned, Is.Empty);
        Assert.That(AccessEngine.Check(UserAccess.None, "profile:read", AccessTarget.None, null), Is.False);
    }

    // --- the check ---

    [Test]
    public void An_action_is_known_when_some_catalog_name_has_it_without_the_scope()
    {
        Assert.That(AccessEngine.IsKnown(Catalog, "classes:read"), Is.True);
        Assert.That(AccessEngine.IsKnown(Catalog, "classes"), Is.False);
        Assert.That(AccessEngine.IsKnown(Catalog, "nope:read"), Is.False);
        Assert.That(AccessEngine.IsKnown(Catalog, "classes:read:all"), Is.False, "an action has no scope");
    }

    [Test]
    public void No_held_scope_denies()
    {
        Assert.That(AccessEngine.Check(Resolve(), "teachers:read", AccessTarget.None, null), Is.False);
    }

    [Test]
    public void No_target_allows_when_the_action_is_held_at_any_scope()
    {
        Assert.That(AccessEngine.Check(Resolve(), "profile:read", AccessTarget.None, null), Is.True);
        Assert.That(AccessEngine.Check(Resolve(stored: ["teachers:read:assigned"]), "teachers:read", AccessTarget.None, null), Is.True);
    }

    [Test]
    public void A_class_target_with_scope_all_allows_an_active_class()
    {
        var access = Resolve(stored: ["classes:read:all"]);

        Assert.That(AccessEngine.Check(access, "classes:read", AccessTarget.ForClass(10), Class(10, 2)), Is.True);
    }

    [Test]
    public void Quirk_an_inactive_class_is_refused_even_with_scope_all()
    {
        var access = Resolve(stored: ["classes:read:all"]);

        // The loader passes null for a class that is missing or not active.
        Assert.That(AccessEngine.Check(access, "classes:read", AccessTarget.ForClass(10), null), Is.False);
    }

    [Test]
    public void A_class_target_with_the_gender_scope_needs_the_same_class_gender()
    {
        var gents = Resolve(roleId: 3, stored: ["classes:read:gender"]);

        Assert.That(AccessEngine.Check(gents, "classes:read", AccessTarget.ForClass(1), Class(1, 1)), Is.True);
        Assert.That(AccessEngine.Check(gents, "classes:read", AccessTarget.ForClass(2), Class(2, 2)), Is.False);
    }

    [Test]
    public void A_class_target_with_a_member_scope_needs_the_class_in_that_list()
    {
        var member = Resolve(memberships: new([], [], [5]));

        Assert.That(AccessEngine.Check(member, "classes:read", AccessTarget.ForClass(5), Class(5, 1)), Is.True);
        Assert.That(AccessEngine.Check(member, "classes:read", AccessTarget.ForClass(6), Class(6, 1)), Is.False);
    }

    [Test]
    public void The_self_scope_never_matches_a_class_or_a_gender()
    {
        var member = Resolve();

        Assert.That(AccessEngine.Check(member, "profile:read", AccessTarget.ForClass(1), Class(1, 1)), Is.False);
        Assert.That(AccessEngine.Check(member, "profile:read", AccessTarget.ForGender(1), null), Is.False);
    }

    [Test]
    public void A_gender_target_with_scope_all_allows_both_genders()
    {
        var access = Resolve(stored: ["registrations:read:all"]);

        Assert.That(AccessEngine.Check(access, "registrations:read", AccessTarget.ForGender(1), null), Is.True);
        Assert.That(AccessEngine.Check(access, "registrations:read", AccessTarget.ForGender(2), null), Is.True);
    }

    [Test]
    public void A_gender_target_with_the_gender_scope_allows_only_the_admins_gender()
    {
        var ladies = Resolve(roleId: 4, stored: ["registrations:read:gender"]);

        Assert.That(AccessEngine.Check(ladies, "registrations:read", AccessTarget.ForGender(2), null), Is.True);
        Assert.That(AccessEngine.Check(ladies, "registrations:read", AccessTarget.ForGender(1), null), Is.False);
    }

    [Test]
    public void A_gender_target_with_a_gender_scope_but_no_role_gender_denies()
    {
        var access = Resolve(roleId: 0, stored: ["registrations:read:gender"]);

        Assert.That(AccessEngine.Check(access, "registrations:read", AccessTarget.ForGender(1), null), Is.False);
    }

    [Test]
    public void Quirk_assigned_scope_passes_a_gender_check_for_every_gender_the_user_has_an_assigned_class_in()
    {
        // The check does not ask whether the person concerned is in one of those classes: any assigned gender passes.
        var coordinator = Resolve(roleId: 5, stored: ["registrations:read:assigned"], assigned: [Class(1, 1), Class(2, 2)]);
        var gentsOnly = Resolve(roleId: 5, stored: ["registrations:read:assigned"], assigned: [Class(1, 1)]);

        Assert.That(AccessEngine.Check(coordinator, "registrations:read", AccessTarget.ForGender(2), null), Is.True);
        Assert.That(AccessEngine.Check(gentsOnly, "registrations:read", AccessTarget.ForGender(2), null), Is.False);
    }

    [Test]
    public void The_own_taught_and_enrolled_scopes_never_pass_a_gender_target()
    {
        var teacher = Resolve(memberships: new([3], [], [3]));

        Assert.That(AccessEngine.Check(teacher, "classes:read", AccessTarget.ForGender(1), null), Is.False);
    }

    [Test]
    public void The_teacher_gender_rule_widens_the_set()
    {
        // Gents may teach ladies, not the reverse: managing any ladies class makes both genders eligible.
        var ladiesAdmin = Resolve(roleId: 4, stored: ["teachers:read:gender"]);
        var gentsAdmin = Resolve(roleId: 3, stored: ["teachers:read:gender"]);

        Assert.That(AccessEngine.Check(ladiesAdmin, "teachers:read", AccessTarget.ForTeacherGender(1), null), Is.True);
        Assert.That(AccessEngine.Check(ladiesAdmin, "teachers:read", AccessTarget.ForTeacherGender(2), null), Is.True);
        Assert.That(AccessEngine.Check(gentsAdmin, "teachers:read", AccessTarget.ForTeacherGender(1), null), Is.True);
        Assert.That(AccessEngine.Check(gentsAdmin, "teachers:read", AccessTarget.ForTeacherGender(2), null), Is.False);
    }

    [Test]
    public void The_teacher_rule_with_scope_all_allows_both()
    {
        var admin = Resolve(roleId: 1, stored: ["teachers:read:all"]);

        Assert.That(AccessEngine.Check(admin, "teachers:read", AccessTarget.ForTeacherGender(2), null), Is.True);
    }

    // --- reach (PHP managedReach, searchReach, genderLock, assignedOnlyIds) ---

    private const int Token = 900001;

    private static Reach ReachOf(UserAccess state, string action = "classes:read") => AccessEngine.ReachOf(state, action, Token);

    [Test]
    public void Reach_reports_all_gender_and_assigned_ids_from_the_management_scopes_only()
    {
        var admin = Resolve(roleId: 1, stored: ["classes:read:all"]);
        var gents = Resolve(roleId: 3, stored: ["classes:read:gender"]);
        var coordinator = Resolve(roleId: 5, stored: ["classes:read:assigned"], assigned: [Class(4, 1), Class(9, 1)]);
        var teacher = Resolve(memberships: new([3], [], [8]));

        AssertReach(ReachOf(admin), true, null, []);
        AssertReach(ReachOf(gents), false, 1, []);
        AssertReach(ReachOf(coordinator), false, null, [4, 9]);
        // own and enrolled classes are not management reach
        AssertReach(ReachOf(teacher), false, null, []);
    }

    private static void AssertReach(Reach reach, bool all, int? gender, int[] ids)
    {
        Assert.That(reach.All, Is.EqualTo(all));
        Assert.That(reach.Gender, Is.EqualTo(gender));
        Assert.That(reach.ClassIds, Is.EqualTo(ids));
    }

    [Test]
    public void Assigned_only_is_null_for_a_user_who_reaches_everything_or_a_whole_gender_or_holds_no_assigned_grant()
    {
        var all = Resolve(roleId: 1, stored: ["classes:read:all", "classes:read:assigned"], assigned: [Class(4, 1)]);
        var gender = Resolve(roleId: 3, stored: ["classes:read:gender", "classes:read:assigned"], assigned: [Class(4, 1)]);
        var none = Resolve(memberships: new([3], [], [8]));

        Assert.That(ReachOf(all).AssignedOnlyIds, Is.Null);
        Assert.That(ReachOf(gender).AssignedOnlyIds, Is.Null);
        Assert.That(ReachOf(none).AssignedOnlyIds, Is.Null);
    }

    [Test]
    public void Assigned_only_lists_the_assigned_classes_for_a_coordinator()
    {
        var coordinator = Resolve(roleId: 5, stored: ["classes:read:assigned"], assigned: [Class(9, 1), Class(4, 1)]);

        Assert.That(ReachOf(coordinator).AssignedOnlyIds, Is.EqualTo(Expect.List(4, 9)));
    }

    [Test]
    public void Assigned_only_with_zero_classes_is_an_empty_list_not_null()
    {
        var coordinator = Resolve(roleId: 5, stored: ["classes:read:assigned"]);

        Assert.That(ReachOf(coordinator).AssignedOnlyIds, Is.Not.Null.And.Empty);
    }

    [Test]
    public void Quirk_the_gender_scope_of_a_role_without_a_gender_counts_as_no_gender_for_assigned_only()
    {
        // PHP: reach.gender is null for a non-admin role even when 'gender' is held, so assigned-only still applies.
        var coordinator = Resolve(roleId: 5, stored: ["classes:read:gender", "classes:read:assigned"], assigned: [Class(4, 1)]);

        Assert.That(ReachOf(coordinator).AssignedOnlyIds, Is.EqualTo(Expect.List(4)));
    }

    [Test]
    public void The_gender_lock_is_null_for_all_the_admins_gender_for_gender_and_the_single_assigned_gender_for_a_coordinator()
    {
        var all = Resolve(roleId: 3, stored: ["classes:read:all", "classes:read:gender"]);
        var gents = Resolve(roleId: 3, stored: ["classes:read:gender"]);
        var ladiesCoordinator = Resolve(roleId: 5, stored: ["classes:read:assigned"], assigned: [Class(4, 2), Class(6, 2)]);
        var mixed = Resolve(roleId: 5, stored: ["classes:read:assigned"], assigned: [Class(4, 1), Class(6, 2)]);
        var noClasses = Resolve(roleId: 5, stored: ["classes:read:assigned"]);
        var noScope = Resolve(memberships: new([3], [], [8]));

        Assert.That(ReachOf(all).GenderLock, Is.Null);
        Assert.That(ReachOf(gents).GenderLock, Is.EqualTo(1));
        Assert.That(ReachOf(ladiesCoordinator).GenderLock, Is.EqualTo(2));
        Assert.That(ReachOf(mixed).GenderLock, Is.Null);
        Assert.That(ReachOf(noClasses).GenderLock, Is.Null);
        Assert.That(ReachOf(noScope).GenderLock, Is.Null);
    }

    [Test]
    public void Search_reach_unions_the_assigned_own_taught_and_enrolled_classes_the_grant_reaches_each_once_sorted()
    {
        var state = Resolve(
            stored: ["classes:read:assigned", "classes:read:own", "classes:read:enrolled"],
            memberships: new([3], [7], [3, 8]),
            assigned: [Class(7, 1), Class(2, 1)]);

        var search = ReachOf(state).Search;

        Assert.That(search.ClassIds, Is.EqualTo(Expect.List(2, 3, 7, 8)));
    }

    [Test]
    public void Search_reach_leaves_out_scopes_the_action_is_not_held_in()
    {
        var state = Resolve(stored: ["classes:read:own"], memberships: new([3], [], [8]), assigned: [Class(7, 1)]);

        // The member set also grants classes:read:enrolled, so enrolled class 8 is reachable; assigned class 7 is not.
        Assert.That(ReachOf(state).Search.ClassIds, Is.EqualTo(Expect.List(3, 8)));
    }

    [Test]
    public void Search_reach_carries_all_gender_and_self()
    {
        var admin = Resolve(roleId: 3, stored: ["classes:read:all", "classes:read:gender", "profile:read:self"]);

        Assert.That(ReachOf(admin).Search.All, Is.True);
        Assert.That(ReachOf(admin).Search.Gender, Is.EqualTo(1));
        Assert.That(ReachOf(admin, "profile:read").Search.Self, Is.EqualTo(Token));
        Assert.That(ReachOf(admin).Search.Self, Is.Null);
    }

    [Test]
    public void Search_reach_self_is_null_for_a_guest_token()
    {
        var member = Resolve();

        Assert.That(AccessEngine.ReachOf(member, "profile:read", 0).Search.Self, Is.Null);
    }

    [Test]
    public void Quirk_two_rules_reaching_one_class_list_it_twice_in_assigned_but_once_in_search_and_genders()
    {
        // PHP's class_access view has one row per (rule, class): assigned [5,5], while searchReach and assigned_genders are unique.
        var state = Resolve(roleId: 5, stored: ["classes:read:assigned"], assigned: [Class(5, 1), Class(5, 1)]);

        Assert.That(state.Scopes.Assigned, Is.EqualTo(Expect.List(5, 5)));
        Assert.That(state.Scopes.AssignedGenders, Is.EqualTo(Expect.List(1)));
        Assert.That(ReachOf(state).ClassIds, Is.EqualTo(Expect.List(5, 5)));
        Assert.That(ReachOf(state).AssignedOnlyIds, Is.EqualTo(Expect.List(5, 5)));
        Assert.That(ReachOf(state).Search.ClassIds, Is.EqualTo(Expect.List(5)));
    }
}
