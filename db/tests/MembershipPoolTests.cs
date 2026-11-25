using System.Globalization;
using System.Net;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// No request of membership holds two connections of the data source at once (domains/CLAUDE.md rule 6). Proved with a pool of one: a route that opened
/// a write transaction and then read through a service that takes its own connection would wait for the first, which it holds itself, and answer 500
/// after the 5 s timeout. Covers the three routes that write under the guardian lock, on their success path and on the "removed by the child" check.
/// </summary>
public sealed class MembershipPoolTests
{
    private const int Admin = 902401;
    private const int Child = 902402;
    private const int Parent = 902403;
    private const int Coordinator = 902404;
    private const int Creator = 902405;
    private const int ClassId = 9942;
    private const string Code = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeee01";
    private const string Father = "{\"relationship\":\"father\"}";

    private MembershipTestKit kit = null!;
    private int adminId;
    private int childId;
    private int creatorId;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit(services => services.AddSingleton<NpgsqlDataSource>(OnePooledConnection));

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync(
            "truncate platform.outbox, classes.class_students, classes.classes, access.class_access_rule_conditions, access.class_access_rules, access.user_permissions restart identity cascade");
        adminId = await MembershipTestKit.AddMemberAsync(Admin, "Pool Admin", "1");
        childId = await MembershipTestKit.AddMemberAsync(Child, "Pool Child", "1");
        await MembershipTestKit.AddMemberAsync(Parent, "Pool Parent", "1");
        var coordinatorId = await MembershipTestKit.AddMemberAsync(Coordinator, "Pool Coordinator", "1");
        creatorId = await MembershipTestKit.AddMemberAsync(Creator, "Pool Creator", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({adminId}, 1), ({coordinatorId}, 5); "
            + "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (1, 'SM', 'SALMAN', 1), (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + $"insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values ({ClassId}, 'POOL-C', 1, 'poollink', 'Pool Class', 3, {Admin}, 1, 'Offline', 'A', {Admin}); "
            + $"insert into classes.class_students (class_id, token_no, joined_on, mcq_admin) values ({ClassId}, {Child}, current_date, 0); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (1, {Coordinator}, 1, 'gents level 3'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (1, 'level', false, 3)");
    }

    [Test]
    public async Task Accepting_an_invite_answers_with_a_pool_of_one()
    {
        await AddInviteAsync(creatorId);

        var reply = await kit.SendAsync(Parent, HttpMethod.Post, "/me/children/link/" + Code, Father);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
    }

    [Test]
    public async Task Accepting_an_invite_for_a_parent_the_child_removed_is_refused_when_its_creator_may_not_manage_parents()
    {
        await AddRevokedLinkAsync();
        await AddInviteAsync(creatorId);

        var reply = await kit.SendAsync(Parent, HttpMethod.Post, "/me/children/link/" + Code, Father);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Forbidden), reply.Body);
        Assert.That(reply.Detail, Is.EqualTo("This person was removed by the child; ask an admin for a new link"));
    }

    [Test]
    public async Task Accepting_an_invite_for_a_parent_the_child_removed_is_allowed_when_its_creator_manages_parents()
    {
        await AddRevokedLinkAsync();
        await AddInviteAsync(adminId);

        var reply = await kit.SendAsync(Parent, HttpMethod.Post, "/me/children/link/" + Code, Father);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
    }

    [Test]
    public async Task A_direct_add_answers_with_a_pool_of_one()
    {
        var reply = await kit.SendAsync(Admin, HttpMethod.Post, $"/members/{Child}/parents", ParentBody);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created), reply.Body);
    }

    [Test]
    public async Task A_direct_add_of_a_parent_the_child_removed_is_refused_without_parents_manage_and_allowed_with_it()
    {
        await AddRevokedLinkAsync();

        var refused = await kit.SendAsync(Coordinator, HttpMethod.Post, $"/members/{Child}/parents", ParentBody);
        Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.Forbidden), refused.Body);
        Assert.That(refused.Detail, Is.EqualTo("Child previously revoked this parent; admin approval required"));

        var allowed = await kit.SendAsync(Admin, HttpMethod.Post, $"/members/{Child}/parents", ParentBody);
        Assert.That(allowed.Status, Is.EqualTo(HttpStatusCode.Created), allowed.Body);
    }

    [Test]
    public async Task Creating_an_invite_answers_with_a_pool_of_one()
    {
        var reply = await kit.SendAsync(Admin, HttpMethod.Post, $"/members/{Child}/parent-links");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created), reply.Body);
    }

    private static string ParentBody => $$"""{"parent_token": {{Parent}}, "relationship": "father"}""";

    private static Task AddInviteAsync(int createdBy) =>
        TestDatabase.ExecuteAsync(
            "insert into membership.user_guardians (child_token, status, source, code, expires_at, created_by) values "
            + $"({Child}, 'invited', 'link', '{Code}', '2099-01-01 00:00:00+00', {createdBy})");

    private Task AddRevokedLinkAsync() =>
        TestDatabase.ExecuteAsync(
            "insert into membership.user_guardians (parent_token, child_token, relationship, status, source, created_by, created_at, revoked_by, revoked_at) "
            + $"values ({Parent}, {Child}, 'father', 'revoked', 'token_entry', {adminId.ToString(CultureInfo.InvariantCulture)}, now(), {childId.ToString(CultureInfo.InvariantCulture)}, now())");

    // Pooling on and the shared source's 5 s timeouts, with a pool of one (as AccessPoolTests).
    private static NpgsqlDataSource OnePooledConnection(IServiceProvider services)
    {
        var connection = new NpgsqlConnectionStringBuilder(services.GetRequiredService<DbSettings>().ConnectionString)
        {
            Pooling = true,
            MaxPoolSize = 1,
            Timeout = 5,
            CommandTimeout = 5,
        };
        return new NpgsqlSlimDataSourceBuilder(connection.ConnectionString).EnableArrays().EnableTransportSecurity().Build();
    }
}
