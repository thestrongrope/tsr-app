using NUnit.Framework;

namespace Tsr.Access.Api.Domain;

/// <summary>The three constant sets PHP holds in code, not in the tables (PermissionsModel::MEMBER, OWN, TAUGHT).</summary>
public sealed class PermissionSetsTests
{
    [Test]
    public void The_member_set_has_21_names_all_held_by_every_registered_member()
    {
        Assert.That(PermissionSets.Member, Has.Count.EqualTo(21));
        Assert.That(PermissionSets.Member, Does.Contain("feedback:create:self").And.Contain("classes:read:enrolled").And.Contain("quiz-competition:take:all"));
    }

    [Test]
    public void The_own_set_has_8_names()
    {
        Assert.That(PermissionSets.Own, Is.EquivalentTo(Expect.List(
            "classes:read:own", "sessions:create:own", "sessions:update:own", "notifications:send:own",
            "mcqs:manage:own", "class-students:read:own", "classes:schedule:own", "parents:add:own"
        )));
    }

    [Test]
    public void The_taught_set_has_2_names()
    {
        Assert.That(PermissionSets.Taught, Is.EquivalentTo(Expect.List("class-students:update:taught", "parents:add-direct:taught")));
    }

    [Test]
    public void Every_name_is_resource_action_scope()
    {
        foreach (var name in PermissionSets.Member.Concat(PermissionSets.Own).Concat(PermissionSets.Taught))
        {
            Assert.That(name.Split(':'), Has.Length.EqualTo(3), name);
        }
    }
}
