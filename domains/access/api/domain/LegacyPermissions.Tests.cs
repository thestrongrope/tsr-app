using NUnit.Framework;

namespace Tsr.Access.Api.Domain;

/// <summary>GET /user/permissions: PHP's older, role-id based answer (pages.json). Copied, bug included.</summary>
public sealed class LegacyPermissionsTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 10, 12, 0, 0, TimeSpan.Zero);

    private static LegacyPermissions Build(int roleId, int enrolled = 0, bool mcqAdmin = false, int teaching = 0) =>
        LegacyPermissions.Build(roleId, enrolled, mcqAdmin, teaching);

    [Test]
    public void A_plain_member_has_no_roles_and_no_pages()
    {
        var answer = Build(0);

        Assert.That(answer.Permissions, Is.Empty);
        Assert.That(answer.RoleId, Is.EqualTo(0));
        Assert.That(answer.RoleName, Is.EqualTo("USER"));
        Assert.That(answer.ApplicableRoles, Is.Empty);
        Assert.That(answer.Version, Is.EqualTo(3));
    }

    [Test]
    public void A_database_role_lists_its_pages_sorted()
    {
        var answer = Build(7);

        Assert.That(answer.Permissions, Is.EqualTo(Expect.List("donor_management", "finance_dashboard", "financial_reports")));
        Assert.That(answer.RoleName, Is.EqualTo("FINANCE"));
        Assert.That(answer.ApplicableRoles.Single().Source, Is.EqualTo("database_role"));
    }

    [Test]
    public void An_unknown_role_id_is_named_USER_and_has_no_pages()
    {
        var answer = Build(2);

        Assert.That(answer.RoleName, Is.EqualTo("USER"));
        Assert.That(answer.Permissions, Is.Empty);
        Assert.That(answer.ApplicableRoles.Single().RoleId, Is.EqualTo(2));
    }

    [Test]
    public void Quirk_the_derived_roles_are_listed_but_never_grant_pages()
    {
        // PHP looks the derived roles up by the strings 'class_admin' and 'class_teacher'; the catalog is keyed by
        // role number, so they never match. Ported as it is: granting them would be a privilege change.
        var answer = Build(0, enrolled: 2, mcqAdmin: true, teaching: 1);

        Assert.That(answer.ApplicableRoles.Select(r => r.Source), Is.EqualTo(Expect.List("class_students.mcq_admin", "classes.teacher")));
        Assert.That(answer.Permissions, Is.Empty);
        Assert.That(answer.RoleId, Is.EqualTo(0));
        Assert.That(answer.RoleName, Is.EqualTo("CLASS_ADMIN"));
    }

    [Test]
    public void The_lowest_priority_applicable_role_is_the_effective_one()
    {
        var answer = Build(4, teaching: 1);

        Assert.That(answer.RoleId, Is.EqualTo(4));
        Assert.That(answer.RoleName, Is.EqualTo("LADIES_ADMIN"));
        Assert.That(answer.ApplicableRoles.Select(r => r.Priority), Is.EqualTo(Expect.List(1, 3)));
    }

    [Test]
    public void The_class_facts_come_through_as_flags_and_counts()
    {
        var answer = Build(0, enrolled: 3, mcqAdmin: false, teaching: 2);

        Assert.That(answer.Enrolled, Is.True);
        Assert.That(answer.ClassCount, Is.EqualTo(3));
        Assert.That(answer.TeacherCount, Is.EqualTo(2));
        Assert.That(answer.IsTeacher, Is.True);
        Assert.That(answer.McqAdmin, Is.False);
    }

    [Test]
    public void IssuedAt_has_microseconds_and_a_plus_zero_offset()
    {
        Assert.That(LegacyPermissions.IssuedAt(Now.AddTicks(1234560)), Is.EqualTo("2026-11-10T12:00:00.123456+00:00"));
        Assert.That(LegacyPermissions.IssuedAt(new DateTimeOffset(2026, 1, 2, 3, 4, 5, TimeSpan.FromHours(5.5))), Is.EqualTo("2026-01-01T21:34:05.000000+00:00"));
    }
}
