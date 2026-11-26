using System.Data.Common;
using System.Globalization;
using System.Net;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using NUnit.Framework;
using Tsr.Access.Api;
using Tsr.Access.Api.Domain;
using Tsr.Classes.Api;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// Issue 99, failure, isolation and concurrency pins on access as it is (ACC-R4, R6, R7, R8): what a caller sees when the database cannot be read or a write fails
/// part way, that a check never reads another domain's uncommitted rows, and that a grant and a rule save to one member at once both succeed. Each case runs on its own
/// copy of the golden database (<see cref="GoldenScenario"/>), so a revoked right or a trigger can never reach another test, and no case depends on test order.
/// </summary>
public sealed class AccessFailureTests
{
    private const string Unavailable = """{"detail":"Permissions could not be loaded. Try again."}""";
    private const string Ville = AccessGoldenScenarios.Ville;
    private static readonly HttpMethod Get = HttpMethod.Get;
    private static readonly HttpMethod Post = HttpMethod.Post;

    private static async Task MakeUnreadableAsync(GoldenScenario run) =>
        await run.ExecuteAsync("revoke select on access.permissions from tsr_app");

    [Test]
    public async Task Unreadable_access_tables_answer_503_and_leave_the_header_out()
    {
        await using var run = await GoldenScenario.StartAsync("failure-me-permissions");
        await MakeUnreadableAsync(run);

        var me = await run.SendAsync(GoldenSeed.Plain, Get, "/me/permissions");
        var link = await run.SendAsync(GoldenSeed.Plain, Post, "/auth/link");

        Assert.That(me.Status, Is.EqualTo(HttpStatusCode.ServiceUnavailable), me.Body);
        Assert.That(me.Body, Is.EqualTo(Unavailable));
        Assert.That(link.Status, Is.EqualTo(HttpStatusCode.OK), link.Body);
    }

    [Test]
    public async Task Unreadable_access_tables_fail_the_other_routes_with_a_500_and_store_nothing()
    {
        await using var run = await GoldenScenario.StartAsync("failure-other-routes");
        await MakeUnreadableAsync(run);
        var super = GoldenSeed.Super;

        var replies = new[]
        {
            await run.SendAsync(super, Get, "/me/permissions/donors:read"),
            await run.SendAsync(super, Get, $"/admin/permissions/members/{GoldenSeed.Subject}"),
            await run.SendAsync(super, Post, $"/admin/permissions/members/{GoldenSeed.Subject}/grants", """{"permission": "donors:read:all", "reason": "Needs the list"}"""),
            await run.SendAsync(super, Get, "/admin/class-access/members?q=al"),
        };

        Assert.That(replies.Select(r => r.Status), Is.All.EqualTo(HttpStatusCode.InternalServerError));
        Assert.That(replies.Select(r => r.Body), Is.All.Contain("42501: permission denied for table permissions"));
        Assert.That(await StoredAsync(run, GoldenSeed.Subject), Is.EqualTo(Stored(0, 0, 0, 0, 0)));
    }

    // Each of the four other tables made unreadable on its own; the member asking holds live rules, so every table is in the way of the read.
    // Today the plain member's own read still answers 200 when only the conditions are unreadable (a member with no rule never reads them).
    [TestCase("user_permissions")]
    [TestCase("user_roles")]
    [TestCase("class_access_rules")]
    [TestCase("class_access_rule_conditions")]
    public async Task One_unreadable_access_table_fails_the_routes_that_read_it(string table)
    {
        await using var run = await GoldenScenario.StartAsync("failure-table-" + table);
        await AccessGoldenScenarios.SeedAssignedRulesAsync(run);
        await run.ExecuteAsync($"revoke select on access.{table} from tsr_app");

        var replies = new[]
        {
            await run.SendAsync(GoldenSeed.Subject, Get, "/me/permissions"),
            await run.SendAsync(GoldenSeed.Plain, Get, "/me/permissions"),
            await run.SendAsync(GoldenSeed.Super, Get, $"/admin/permissions/members/{GoldenSeed.Subject}"),
            await run.SendAsync(GoldenSeed.GentsAdmin, Get, $"/admin/class-access/members/{GoldenSeed.Subject}"),
        };

        var conditionsOnly = table == "class_access_rule_conditions";
        HttpStatusCode[] expected = conditionsOnly
            ? [HttpStatusCode.ServiceUnavailable, HttpStatusCode.OK, HttpStatusCode.ServiceUnavailable, HttpStatusCode.InternalServerError]
            : [HttpStatusCode.ServiceUnavailable, HttpStatusCode.ServiceUnavailable, HttpStatusCode.InternalServerError, HttpStatusCode.InternalServerError];
        Assert.That(replies.Select(r => r.Status), Is.EqualTo(expected), string.Join(" | ", replies.Select(r => r.Body)));
        foreach (var reply in replies.Where(r => r.Status == HttpStatusCode.ServiceUnavailable))
        {
            Assert.That(reply.Body, Is.EqualTo(Unavailable));
        }

        foreach (var reply in replies.Where(r => r.Status == HttpStatusCode.InternalServerError))
        {
            Assert.That(reply.Body, Does.Contain($"42501: permission denied for table {table}"));
        }
    }

    // grants still live, rules still live, conditions, events and the role of the subject (0: none), as the subject's state reads.
    private static string Stored(int grants, int rules, int conditions, int events, int role) => $"{grants},{rules},{conditions},{events},{role}";

    private static async Task<string> StoredAsync(GoldenScenario run, int member) => (await run.QueryAsync(
        $"""
        select (select count(*) from access.user_permissions where revoked_at is null) || ',' ||
               (select count(*) from access.class_access_rules where revoked_at is null) || ',' ||
               (select count(*) from access.class_access_rule_conditions) || ',' ||
               (select count(*) from platform.outbox) || ',' ||
               (select coalesce(max(ur.roleid), 0) from identity.users u left join access.user_roles ur on ur.user_id = u.id where u.token = {member})
        """)).Single();

    private const string FailOutbox =
        """
        create function platform.fail_outbox() returns trigger language plpgsql as
        $$ begin raise exception 'outbox unavailable (test)'; end $$;
        create trigger fail_outbox before insert on platform.outbox for each row execute function platform.fail_outbox();
        """;

    private const string FailConditions =
        """
        create function access.fail_conditions() returns trigger language plpgsql as
        $$ begin raise exception 'conditions unavailable (test)'; end $$;
        create trigger fail_conditions before insert on access.class_access_rule_conditions for each row execute function access.fail_conditions();
        """;

    [TestCase("rule-add")]
    [TestCase("rule-revoke")]
    [TestCase("permission-grant")]
    [TestCase("permission-revoke")]
    public async Task A_write_that_fails_before_commit_stores_nothing(string write)
    {
        await using var run = await GoldenScenario.StartAsync("failure-write-" + write);

        var failed = await FailingWriteAsync(run, write);

        Assert.That(failed.Status, Is.EqualTo(HttpStatusCode.InternalServerError), failed.Body);
        if (write.StartsWith("rule", StringComparison.Ordinal))
        {
            Assert.That(failed.Body, Is.EqualTo("""{"detail":"Nothing was changed"}"""));
        }
        else
        {
            Assert.That(failed.Body, Does.Contain("outbox unavailable (test)"));
        }

        // Only what the write's own set-up stored is left: the rule or the grant made before the trigger, and its event.
        var expected = write switch
        {
            "rule-revoke" => Stored(0, 1, 1, 1, 5),
            "permission-revoke" => Stored(1, 0, 0, 1, 0),
            _ => Stored(0, 0, 0, 0, 0),
        };
        Assert.That(await StoredAsync(run, GoldenSeed.Subject), Is.EqualTo(expected));
    }

    // Each write is made to fail at its last statement: the conditions of a new rule, or the event of the other three. A write that needs something to exist first gets it before the trigger.
    private static async Task<GoldenReply> FailingWriteAsync(GoldenScenario run, string write)
    {
        var subject = GoldenSeed.Subject;
        var rules = $"/admin/class-access/members/{subject}/rules";
        switch (write)
        {
            case "rule-add":
            {
                var (version, hash) = await AccessGoldenScenarios.DraftAsync(run, GoldenSeed.GentsAdmin, subject, 1, Ville);
                await run.ExecuteAsync(FailConditions);
                return await run.SendAsync(GoldenSeed.GentsAdmin, Post, rules, AccessGoldenScenarios.SaveBody(1, Ville, "Teaches there", version, hash));
            }

            case "rule-revoke":
            {
                var (version, hash) = await AccessGoldenScenarios.DraftAsync(run, GoldenSeed.GentsAdmin, subject, 1, Ville);
                var saved = await run.SendAsync(GoldenSeed.GentsAdmin, Post, rules, AccessGoldenScenarios.SaveBody(1, Ville, "Teaches there", version, hash));
                var ruleId = saved.Json!["rules"]![0]!["id"]!.GetValue<int>();
                await run.ExecuteAsync(FailOutbox);
                return await run.SendAsync(GoldenSeed.GentsAdmin, Post, $"/admin/class-access/rules/{ruleId}/revoke", AccessGoldenScenarios.RevokeBody("Moved", AccessGoldenScenarios.StringOf(saved.Json, "version")));
            }

            case "permission-grant":
                await run.ExecuteAsync(FailOutbox);
                return await run.SendAsync(GoldenSeed.Super, Post, $"/admin/permissions/members/{subject}/grants", """{"permission": "donors:read:all", "reason": "Needs the list"}""");

            default:
            {
                var granted = await run.SendAsync(GoldenSeed.Super, Post, $"/admin/permissions/members/{subject}/grants", """{"permission": "donors:read:all", "reason": "Needs the list"}""");
                var id = granted.Json!["granted"]![0]!["id"]!.GetValue<int>();
                await run.ExecuteAsync(FailOutbox);
                return await run.SendAsync(GoldenSeed.Super, Post, $"/admin/permissions/grants/{id}/revoke", """{"reason": "Done"}""");
            }
        }
    }

    [Test]
    public async Task A_saved_rule_whose_view_cannot_be_read_answers_saved_with_no_view()
    {
        var probe = new PortBudget();
        int ownCalls;
        await using (var counted = await GoldenScenario.StartAsync("failure-saved-probe", services => UseBudget(services, probe)))
        {
            var (version, hash) = await AccessGoldenScenarios.DraftAsync(counted, GoldenSeed.GentsAdmin, GoldenSeed.Subject, 1, Ville);
            probe.Calls = 0;
            var saved = await counted.SendAsync(GoldenSeed.GentsAdmin, Post, SubjectRules, AccessGoldenScenarios.SaveBody(1, Ville, "Teaches there", version, hash));
            Assert.That(saved.Status, Is.EqualTo(HttpStatusCode.OK), saved.Body);
            Assert.That(saved.Json!["member"], Is.Not.Null, "with a readable port the saved answer carries the view");
            ownCalls = probe.Calls;
            Assert.That(ownCalls, Is.EqualTo(4), "asks of the active classes by one save on today's code (counted, not predicted); the failing run lets all but the last through");
        }

        var budget = new PortBudget();
        await using var run = await GoldenScenario.StartAsync("failure-saved-view", services => UseBudget(services, budget));
        var (draftVersion, draftHash) = await AccessGoldenScenarios.DraftAsync(run, GoldenSeed.GentsAdmin, GoldenSeed.Subject, 1, Ville);
        budget.Calls = 0;
        budget.Limit = ownCalls - 1;

        var reply = await run.SendAsync(GoldenSeed.GentsAdmin, Post, SubjectRules, AccessGoldenScenarios.SaveBody(1, Ville, "Teaches there", draftVersion, draftHash));

        Assert.Multiple(async () =>
        {
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
            Assert.That(reply.Body, Is.EqualTo("""{"saved":true,"member":null,"version":null,"fromRole":null,"rules":[]}"""));
            Assert.That(await run.QueryAsync("select count(*) from access.class_access_rules"), Is.EqualTo(["1"]));
            Assert.That(await run.QueryAsync("select count(*) from platform.outbox where event_type = 'access.class_access_rule_created'"), Is.EqualTo(["1"]));
        });
    }

    private static string SubjectRules => $"/admin/class-access/members/{GoldenSeed.Subject}/rules";

    private static void UseBudget(IServiceCollection services, PortBudget budget) =>
        services.AddScoped<IClassScopes>(provider => new BudgetedClasses(new ClassScopes(provider.GetRequiredService<NpgsqlDataSource>()), budget));

    /// <summary>How many times the classes port was asked for the active classes, and from which call on it fails as a database does.</summary>
    private sealed class PortBudget
    {
        public int Calls { get; set; }

        public int Limit { get; set; } = int.MaxValue;
    }

    private sealed class BudgetedClasses(IClassScopes inner, PortBudget budget) : IClassScopes
    {
        public Task<ClassMemberships> MembershipsAsync(int token, CancellationToken ct) => inner.MembershipsAsync(token, ct);

        public Task<ClassFacts?> ActiveClassAsync(int classId, CancellationToken ct) => inner.ActiveClassAsync(classId, ct);

        public Task<IReadOnlyList<ClassFacts>> ActiveClassesAsync(CancellationToken ct)
        {
            budget.Calls++;
            return budget.Calls > budget.Limit ? throw new StorageDown() : inner.ActiveClassesAsync(ct);
        }
    }

    private sealed class StorageDown() : DbException("storage is down");

    [Test]
    public async Task A_check_inside_another_domains_transaction_does_not_see_its_uncommitted_rows()
    {
        await using var run = await GoldenScenario.StartAsync("failure-isolation");
        var plainId = int.Parse((await run.QueryAsync($"select id from identity.users where token = {GoldenSeed.Plain}"))[0], CultureInfo.InvariantCulture);
        var superId = int.Parse((await run.QueryAsync($"select id from identity.users where token = {GoldenSeed.Super}"))[0], CultureInfo.InvariantCulture);
        await using var scope = run.Services.CreateAsyncScope();
        var source = scope.ServiceProvider.GetRequiredService<NpgsqlDataSource>();
        await using (var tx = await source.BeginAsync(CancellationToken.None))
        {
            await tx.ExecuteAsync($"insert into access.user_permissions (user_id, permission, granted_by, granted_at, reason) values ({plainId}, 'donors:read:all', {superId}, now(), 'probe')", CancellationToken.None);

            var allowed = await scope.ServiceProvider.GetRequiredService<Permissions>()
                .CanAsync(new Caller(plainId, GoldenSeed.Plain), "donors:read", AccessTarget.None, CancellationToken.None);

            Assert.That(allowed, Is.False, "the grant is in another domain's open transaction: a member without it");
        }

        Assert.That(await run.QueryAsync("select count(*) from access.user_permissions"), Is.EqualTo(["0"]));
    }

    [Test]
    public async Task A_check_sees_the_other_domains_rows_once_its_transaction_commits()
    {
        await using var run = await GoldenScenario.StartAsync("failure-isolation-commit");
        var plainId = int.Parse((await run.QueryAsync($"select id from identity.users where token = {GoldenSeed.Plain}"))[0], CultureInfo.InvariantCulture);
        var superId = int.Parse((await run.QueryAsync($"select id from identity.users where token = {GoldenSeed.Super}"))[0], CultureInfo.InvariantCulture);
        var caller = new Caller(plainId, GoldenSeed.Plain);
        await using (var writing = run.Services.CreateAsyncScope())
        {
            var source = writing.ServiceProvider.GetRequiredService<NpgsqlDataSource>();
            await using var tx = await source.BeginAsync(CancellationToken.None);
            await tx.ExecuteAsync($"insert into access.user_permissions (user_id, permission, granted_by, granted_at, reason) values ({plainId}, 'donors:read:all', {superId}, now(), 'probe')", CancellationToken.None);
            await tx.CommitAsync(CancellationToken.None);
        }

        // A new scope: the first scope's Permissions keeps the answer it resolved, so a second question there would not read again.
        await using var reading = run.Services.CreateAsyncScope();
        var allowed = await reading.ServiceProvider.GetRequiredService<Permissions>().CanAsync(caller, "donors:read", AccessTarget.None, CancellationToken.None);

        Assert.That(allowed, Is.True, "the grant is committed: the member holds it");
    }

    // The lock itself (MemberLock, class 6001): a separate transaction holds it, the write must not finish and must store nothing until it is released, then it completes as it normally does.
    [TestCase("grant")]
    [TestCase("rule-save")]
    public async Task A_write_waits_for_the_member_lock_and_completes_when_it_is_released(string write)
    {
        await using var run = await GoldenScenario.StartAsync("failure-lock-" + write);
        var subject = GoldenSeed.Subject;
        var (version, hash) = await AccessGoldenScenarios.DraftAsync(run, GoldenSeed.GentsAdmin, subject, 1, Ville);
        await using var holder = await run.OpenOwnerConnectionAsync();
        await using var tx = await holder.BeginTransactionAsync();
        await using (var take = new NpgsqlCommand($"select pg_advisory_xact_lock({MemberLock.LockClass}, {subject})", holder, tx))
        {
            await take.ExecuteNonQueryAsync();
        }

        var pending = write == "grant"
            ? run.SendAsync(GoldenSeed.Super, Post, $"/admin/permissions/members/{subject}/grants", """{"permission": "donors:read:all", "reason": "Locked"}""")
            : run.SendAsync(GoldenSeed.GentsAdmin, Post, $"/admin/class-access/members/{subject}/rules", AccessGoldenScenarios.SaveBody(1, Ville, "Locked", version, hash));

        Assert.That(async () => await pending.WaitAsync(TimeSpan.FromSeconds(1.5)), Throws.InstanceOf<TimeoutException>(), "the write finished while another transaction held the member's lock");
        Assert.That(await run.QueryAsync("select count(*) from access.user_permissions"), Is.EqualTo(["0"]), "nothing is stored while the lock is held");
        Assert.That(await run.QueryAsync("select count(*) from access.class_access_rules"), Is.EqualTo(["0"]), "nothing is stored while the lock is held");

        await tx.CommitAsync();
        var reply = await pending.WaitAsync(TimeSpan.FromSeconds(10));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        var stored = write == "grant" ? "select count(*) from access.user_permissions" : "select count(*) from access.class_access_rules";
        Assert.That(await run.QueryAsync(stored), Is.EqualTo(["1"]));
    }

    [Test]
    public async Task A_grant_and_a_rule_save_for_one_member_at_once_both_succeed()
    {
        await using var run = await GoldenScenario.StartAsync("failure-grant-and-rule");
        for (var i = 0; i < 10; i++)
        {
            var token = 910001 + i;
            await SeedMemberAsync(run, token);
            var (version, hash) = await AccessGoldenScenarios.DraftAsync(run, GoldenSeed.GentsAdmin, token, 1, Ville);

            var replies = await Task.WhenAll(
                run.SendAsync(GoldenSeed.Super, Post, $"/admin/permissions/members/{token}/grants", """{"permission": "donors:read:all", "reason": "Race"}"""),
                run.SendAsync(GoldenSeed.GentsAdmin, Post, $"/admin/class-access/members/{token}/rules", AccessGoldenScenarios.SaveBody(1, Ville, "Race", version, hash)));

            Assert.That(replies.Select(r => r.Status), Is.All.EqualTo(HttpStatusCode.OK), string.Join(" | ", replies.Select(r => r.Body)));
            var user = $"(select id from identity.users where token = {token})";
            Assert.Multiple(async () =>
            {
                Assert.That(await run.QueryAsync($"select count(*) from access.user_permissions where user_id = {user} and revoked_at is null"), Is.EqualTo(["1"]), "grants of member " + token);
                Assert.That(await run.QueryAsync($"select count(*) from access.class_access_rules where token = {token} and revoked_at is null"), Is.EqualTo(["1"]), "rules of member " + token);
                Assert.That(await run.QueryAsync($"select roleid from access.user_roles where user_id = {user}"), Is.EqualTo(["5"]), "role of member " + token);
                Assert.That(await run.QueryAsync("select count(*) from platform.outbox"), Is.EqualTo([(2 * (i + 1)).ToString(CultureInfo.InvariantCulture)]), "events after pair " + i);
            });
        }
    }

    private static Task SeedMemberAsync(GoldenScenario run, int token) => run.ExecuteAsync(
        $"""
        insert into identity.users (token, email, firebase_uid) values ({token}, '{MembershipTestKit.EmailOf(token)}', 'uid-{token}');
        insert into membership.member_profiles (user_id, name, gender) select id, 'Race Member {token}', '1' from identity.users where token = {token};
        """);
}
