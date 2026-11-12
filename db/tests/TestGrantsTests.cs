using System.Net;
using System.Text.Json.Nodes;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The grants lane (the ten /admin/permissions and /admin/class-access routes of access) against a real database, as the limited role: the rows a write leaves and who they name, exactly one outbox event
/// per change and none per refusal, a grant, a revoke and a rule that take effect on the member's very next request, what two simultaneous requests do (the member lock, class 6001), the row scope of every
/// route (who is refused, with which status and message, and that nothing was written), and the one published view of class levels. The HTTP contract against PHP is domains/access/spec/tests (tools/contract-grants.sh).
/// </summary>
public sealed class TestGrantsTests
{
    private const int Super = 925001;
    private const int GentsAdmin = 925003;
    private const int LadiesAdmin = 925004;
    private const int Plain = 925008;
    private const int Subject = 925041;
    private const int Other = 925042;
    private const int LadiesMember = 925043;
    private const int NoGender = 925044;
    private const string Ville = "{\"field\": \"city\", \"value\": \"GRville\"}";

    private MembershipTestKit kit = null!;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit();

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync(
            "truncate platform.outbox, access.user_permissions, access.class_access_rule_conditions, access.class_access_rules, classes.class_tags, classes.tags, classes.class_students, classes.classes restart identity cascade");
        foreach (var (token, gender) in new (int, string?)[] { (Super, "1"), (GentsAdmin, "1"), (LadiesAdmin, "2"), (Plain, "1"), (Subject, "1"), (Other, "1"), (LadiesMember, "2"), (NoGender, null) })
        {
            await MembershipTestKit.AddMemberAsync(token, "Gr " + token, gender);
        }

        await TestDatabase.ExecuteAsync(
            "insert into access.user_roles (user_id, roleid) select id, case token when 925001 then 1 when 925003 then 3 else 4 end from identity.users where token in (925001, 925003, 925004)");
        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (1, 'SM', 'SALMAN', 1), (2, 'AG', 'ABUZAR', 2), (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, city, country, status, created_by) values "
            + $"(98501, 'GR-G-501', 7, 'grl1', 'Gr One', 2, {Super}, 1, 'Offline', 'GRville', 'Grland', 'A', {Super}), "
            + $"(98502, 'GR-G-502', 7, 'grl2', 'Gr Two', 3, {Super}, 1, 'Offline', 'GRville', 'Grland', 'A', {Super}), "
            + $"(98503, 'GR-G-503', 7, 'grl3', 'Gr Three', 2, {Super}, 1, 'Offline', 'GRother', 'Grland', 'A', {Super}), "
            + $"(98504, 'GR-G-504', 7, 'grl4', 'Gr Closed', 2, {Super}, 1, 'Offline', 'GRville', 'Grland', 'I', {Super}), "
            + $"(98505, 'GR-L-505', 7, 'grl5', 'Gr Ladies', 2, {Super}, 2, 'Offline', 'GRville', 'Grland', 'A', {Super})");
    }

    // --- named grants: rows, events, effect ---

    [Test]
    public async Task A_grant_and_a_revoke_name_the_operator_trim_the_reason_and_write_one_event_each()
    {
        var granted = await kit.SendAsync(Super, HttpMethod.Post, $"/admin/permissions/members/{Plain}/grants", """{"permission": "donors:read:all", "reason": "  Needs the list  "}""");
        Assert.That(granted.Status, Is.EqualTo(HttpStatusCode.OK), granted.Body);
        var id = granted.Json!["granted"]![0]!["id"]!.GetValue<int>();
        var operatorId = await UserIdAsync(Super);

        Assert.That(await CountAsync("access.user_permissions", $"id = {id} and permission = 'donors:read:all' and granted_by = {operatorId} and reason = 'Needs the list' and revoked_at is null"), Is.EqualTo(1));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'access.permission_granted'"), Is.EqualTo(1));
        var payload = await PayloadAsync("access.permission_granted");
        Assert.That(payload.Select(p => p.Key), Is.EquivalentTo(Items("grantId", "token", "permission", "grantedBy")));
        Assert.That(payload["token"]!.GetValue<int>(), Is.EqualTo(Plain));

        var revoked = await kit.SendAsync(Super, HttpMethod.Post, $"/admin/permissions/grants/{id}/revoke", """{"reason": "  Done  "}""");
        Assert.That(revoked.Status, Is.EqualTo(HttpStatusCode.OK), revoked.Body);
        Assert.That(await CountAsync("access.user_permissions", $"id = {id} and revoked_by = {operatorId} and revoke_reason = 'Done' and revoked_at is not null"), Is.EqualTo(1));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'access.permission_revoked'"), Is.EqualTo(1));
        Assert.That((await PayloadAsync("access.permission_revoked")).Select(p => p.Key), Is.EquivalentTo(Items("grantId", "token", "permission", "revokedBy")));
        Assert.That(await CountAsync("platform.outbox"), Is.EqualTo(2));
    }

    [TestCase(Plain, "donors:read:all", "A reason", 403, "Only super admins can manage permissions")]
    [TestCase(GentsAdmin, "donors:read:all", "A reason", 403, "Only super admins can manage permissions")]
    [TestCase(Super, "permissions:manage:all", "A reason", 422, "That permission cannot be granted")]
    [TestCase(Super, "class-access:manage:all", "A reason", 422, "That permission cannot be granted")]
    [TestCase(Super, "members:enrol-by-token:all", "A reason", 422, "That permission cannot be granted")]
    [TestCase(Super, "donors:read:gender", "A reason", 422, "That permission cannot be granted")]
    [TestCase(Super, "content:read:all", "A reason", 409, "The member already holds that permission")]
    [TestCase(Super, "donors:read:all", "   ", 422, "A reason is required")]
    public async Task A_refused_grant_writes_no_row_and_no_event(int operatorToken, string permission, string reason, int status, string message)
    {
        var reply = await kit.SendAsync(operatorToken, HttpMethod.Post, $"/admin/permissions/members/{Plain}/grants", new JsonObject { ["permission"] = permission, ["reason"] = reason }.ToJsonString());

        Assert.That((int)reply.Status, Is.EqualTo(status), reply.Body);
        Assert.That(reply.Detail, Is.EqualTo(message));
        Assert.That(await CountAsync("access.user_permissions"), Is.Zero);
        Assert.That(await CountAsync("platform.outbox"), Is.Zero);
    }

    [Test]
    public async Task A_grant_to_oneself_is_refused_with_422_and_writes_no_row_and_no_event()
    {
        var reply = await kit.SendAsync(Super, HttpMethod.Post, $"/admin/permissions/members/{Super}/grants", """{"permission": "quiz:admin:all", "reason": "Self"}""");

        Assert.That((int)reply.Status, Is.EqualTo(422), reply.Body);
        Assert.That(reply.Detail, Is.EqualTo("You cannot grant a permission to yourself"));
        Assert.That(await CountAsync("access.user_permissions"), Is.Zero);
        Assert.That(await CountAsync("platform.outbox"), Is.Zero);
    }

    [Test]
    public async Task A_grant_to_oneself_by_a_member_without_permission_is_still_a_403()
    {
        var reply = await kit.SendAsync(Plain, HttpMethod.Post, $"/admin/permissions/members/{Plain}/grants", """{"permission": "donors:read:all", "reason": "Self"}""");

        Assert.That((int)reply.Status, Is.EqualTo(403), reply.Body);
        Assert.That(reply.Detail, Is.EqualTo("Only super admins can manage permissions"));
    }

    [Test]
    public async Task A_grant_and_a_revoke_take_effect_on_the_members_very_next_request()
    {
        Assert.That((await kit.SendAsync(Plain, HttpMethod.Get, "/admin/donors")).Status, Is.EqualTo(HttpStatusCode.Forbidden));

        var granted = await kit.SendAsync(Super, HttpMethod.Post, $"/admin/permissions/members/{Plain}/grants", """{"permission": "donors:read:all", "reason": "Needs the list"}""");
        var id = granted.Json!["granted"]![0]!["id"]!.GetValue<int>();
        Assert.That((await kit.SendAsync(Plain, HttpMethod.Get, "/admin/donors")).Status, Is.EqualTo(HttpStatusCode.OK));

        await kit.SendAsync(Super, HttpMethod.Post, $"/admin/permissions/grants/{id}/revoke", """{"reason": "Over"}""");
        Assert.That((await kit.SendAsync(Plain, HttpMethod.Get, "/admin/donors")).Status, Is.EqualTo(HttpStatusCode.Forbidden), "a revoked grant stops working at once");
    }

    // --- the revision of GET /me/permissions: changes with the answer, and only then ---

    [Test]
    public async Task The_revision_changes_with_a_grant_and_returns_with_its_revoke()
    {
        var before = await RevisionAsync(Plain);
        Assert.That(await RevisionAsync(Plain), Is.EqualTo(before), "the same answer, asked twice");

        var granted = await kit.SendAsync(Super, HttpMethod.Post, $"/admin/permissions/members/{Plain}/grants", """{"permission": "donors:read:all", "reason": "Needs the list"}""");
        var id = granted.Json!["granted"]![0]!["id"]!.GetValue<int>();
        var held = await RevisionAsync(Plain);
        Assert.That(held, Is.Not.EqualTo(before), "a grant");
        Assert.That(await RevisionAsync(Other), Is.EqualTo(before), "another member with the same answer as before is not touched");

        await kit.SendAsync(Super, HttpMethod.Post, $"/admin/permissions/grants/{id}/revoke", """{"reason": "Over"}""");
        Assert.That(await RevisionAsync(Plain), Is.EqualTo(before), "revoking returns to the same state, though a revoked row remains");
    }

    [Test]
    public async Task The_revision_changes_with_the_role()
    {
        var before = await RevisionAsync(Plain);

        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({await UserIdAsync(Plain)}, 7)");
        var finance = await RevisionAsync(Plain);
        Assert.That(finance, Is.Not.EqualTo(before), "role 7 adds donors:read:all");

        await TestDatabase.ExecuteAsync($"update access.user_roles set roleid = 3 where user_id = {await UserIdAsync(Plain)}");
        Assert.That(await RevisionAsync(Plain), Is.Not.EqualTo(finance).And.Not.EqualTo(before), "role 3");

        await TestDatabase.ExecuteAsync($"update access.user_roles set roleid = 6 where user_id = {await UserIdAsync(Plain)}");
        Assert.That(await RevisionAsync(Plain), Is.EqualTo(before), "role 6 holds nothing, so the answer is a plain member's again");
    }

    [Test]
    public async Task The_revision_changes_with_a_class_access_rule_that_reaches_a_class_and_not_with_one_that_reaches_none()
    {
        var before = await RevisionAsync(Subject);

        var nowhere = await TestDatabase.ScalarAsync<int>(
            $"insert into access.class_access_rules (token, gender, note, reason) values ({Subject}, 1, 'Nowhere', 'Fixture') returning id", TestDatabase.OwnerConnection);
        await TestDatabase.ExecuteAsync($"insert into access.class_access_rule_conditions (rule_id, field, negate, value) values ({nowhere}, 'city', false, 'GRnowhere')");
        Assert.That(await RevisionAsync(Subject), Is.EqualTo(before), "a rule no class matches leaves the answer as it was");

        var rule = await AddRuleAsync(Subject, 1, "Ville");
        var assigned = await RevisionAsync(Subject);
        Assert.That(assigned, Is.Not.EqualTo(before), "two assigned classes");

        await TestDatabase.ExecuteAsync("update classes.classes set status = 'I' where id = 98502");
        Assert.That(await RevisionAsync(Subject), Is.Not.EqualTo(assigned).And.Not.EqualTo(before), "one assigned class fewer");

        await TestDatabase.ExecuteAsync($"update access.class_access_rules set revoked_at = now() where id = {rule}");
        Assert.That(await RevisionAsync(Subject), Is.EqualTo(before), "the rule revoked");
    }

    [Test]
    public async Task The_grant_routes_are_503_when_the_members_permissions_cannot_be_loaded()
    {
        using var down = new MembershipTestKit(services => services.AddScoped<Tsr.Access.Api.IClassScopes>(_ => new UnreadableClasses(Plain)));

        var view = await down.SendAsync(Super, HttpMethod.Get, $"/admin/permissions/members/{Plain}");
        var grant = await down.SendAsync(Super, HttpMethod.Post, $"/admin/permissions/members/{Plain}/grants", """{"permission": "donors:read:all", "reason": "Needs the list"}""");

        Assert.That(view.Status, Is.EqualTo(HttpStatusCode.ServiceUnavailable), view.Body);
        Assert.That(view.Body, Is.EqualTo("""{"detail":"Permissions could not be loaded. Try again."}"""));
        Assert.That(grant.Status, Is.EqualTo(HttpStatusCode.ServiceUnavailable), grant.Body);
        Assert.That(grant.Body, Is.EqualTo("""{"detail":"Permissions could not be loaded. Try again."}"""));
        Assert.That(await CountAsync("access.user_permissions"), Is.EqualTo(0));
    }

    [Test]
    public async Task Two_simultaneous_grants_of_one_permission_leave_one_row_and_one_event()
    {
        var replies = await Task.WhenAll(Enumerable.Range(0, 6).Select(_ =>
            kit.SendAsync(Super, HttpMethod.Post, $"/admin/permissions/members/{Plain}/grants", """{"permission": "donors:read:all", "reason": "Race"}""")));

        Assert.That(replies.Count(r => r.Status == HttpStatusCode.OK), Is.EqualTo(1), string.Join(" | ", replies.Select(r => r.Body)));
        Assert.That(replies.Count(r => r.Status == HttpStatusCode.Conflict), Is.EqualTo(5));
        Assert.That(await CountAsync("access.user_permissions", "permission = 'donors:read:all' and revoked_at is null"), Is.EqualTo(1));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'access.permission_granted'"), Is.EqualTo(1));
    }

    [Test]
    public async Task Two_simultaneous_revokes_of_one_grant_write_one_event()
    {
        var granted = await kit.SendAsync(Super, HttpMethod.Post, $"/admin/permissions/members/{Plain}/grants", """{"permission": "donors:read:all", "reason": "Race"}""");
        var id = granted.Json!["granted"]![0]!["id"]!.GetValue<int>();

        var replies = await Task.WhenAll(Enumerable.Range(0, 4).Select(_ => kit.SendAsync(Super, HttpMethod.Post, $"/admin/permissions/grants/{id}/revoke", """{"reason": "Race"}""")));

        Assert.That(replies.Count(r => r.Status == HttpStatusCode.OK), Is.EqualTo(1), string.Join(" | ", replies.Select(r => r.Body)));
        Assert.That(replies.Count(r => r.Status == HttpStatusCode.Conflict), Is.EqualTo(3));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'access.permission_revoked'"), Is.EqualTo(1));
    }

    // --- class access rules: rows, events, role, effect, one matcher ---

    [Test]
    public async Task A_rule_writes_the_rule_its_conditions_the_operator_the_role_and_one_event_and_a_revoke_undoes_the_role()
    {
        var (version, hash) = await DraftAsync(GentsAdmin, Subject, 1, Ville);

        var saved = await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/members/{Subject}/rules", Body(1, Ville, "  Teaches there  ", version, hash));

        Assert.That(saved.Status, Is.EqualTo(HttpStatusCode.OK), saved.Body);
        var ruleId = saved.Json!["rules"]![0]!["id"]!.GetValue<int>();
        var operatorId = await UserIdAsync(GentsAdmin);
        Assert.That(await CountAsync("access.class_access_rules", $"id = {ruleId} and token = {Subject} and gender = 1 and note = 'Gents, GRville' and granted_by = {operatorId} and reason = 'Teaches there' and revoked_at is null"), Is.EqualTo(1));
        Assert.That(await CountAsync("access.class_access_rule_conditions", $"rule_id = {ruleId} and field = 'city' and value = 'GRville' and not negate and level_id is null"), Is.EqualTo(1));
        Assert.That(await CountAsync("access.user_roles", $"user_id = {await UserIdAsync(Subject)} and roleid = 5"), Is.EqualTo(1));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'access.class_access_rule_created'"), Is.EqualTo(1));
        var payload = await PayloadAsync("access.class_access_rule_created");
        Assert.That(payload.Select(p => p.Key), Is.EquivalentTo(Items("ruleId", "token", "gender", "grantedBy")));

        var revoked = await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/rules/{ruleId}/revoke", $$"""{"reason": "  Moved  ", "version": "{{saved.Json["version"]!.GetValue<string>()}}"}""");

        Assert.That(revoked.Status, Is.EqualTo(HttpStatusCode.OK), revoked.Body);
        Assert.That(await CountAsync("access.class_access_rules", $"id = {ruleId} and revoked_by = {operatorId} and revoke_reason = 'Moved' and revoked_at is not null"), Is.EqualTo(1));
        Assert.That(await CountAsync("access.user_roles", $"user_id = {await UserIdAsync(Subject)}"), Is.Zero, "the last rule gone: back to role 0, no row");
        Assert.That(await CountAsync("platform.outbox", "event_type = 'access.class_access_rule_revoked'"), Is.EqualTo(1));
        Assert.That(await CountAsync("platform.outbox"), Is.EqualTo(2));
    }

    [Test]
    public async Task A_rule_takes_effect_on_the_next_request_and_a_revoked_rule_stops_at_once_and_the_preview_the_saved_view_and_the_engine_agree()
    {
        Assert.That((await kit.SendAsync(Subject, HttpMethod.Get, "/classes/98501")).Status, Is.EqualTo(HttpStatusCode.Forbidden));
        var (version, hash) = await DraftAsync(GentsAdmin, Subject, 1, Ville);
        var preview = await kit.SendAsync(GentsAdmin, HttpMethod.Post, "/admin/class-access/preview", $$"""{"gender": 1, "conditions": [{{Ville}}]}""");

        var saved = await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/members/{Subject}/rules", Body(1, Ville, "Effect", version, hash));

        Assert.That(saved.Status, Is.EqualTo(HttpStatusCode.OK), saved.Body);
        var previewed = preview.Json!["classes"]!.AsArray().Select(c => c!["id"]!.GetValue<int>()).ToList();
        var savedClasses = saved.Json!["rules"]![0]!["classes"]!.AsArray().Select(c => c!["id"]!.GetValue<int>()).ToList();
        var assigned = (await kit.SendAsync(Subject, HttpMethod.Get, "/me/permissions")).Json!["scopes"]!["assigned"]!.AsArray().Select(c => c!.GetValue<int>()).ToList();
        Assert.That(previewed, Is.EqualTo(Items(98501, 98502)), "the closed class and the ladies class are not reached");
        Assert.That(savedClasses, Is.EqualTo(previewed));
        Assert.That(assigned, Is.EqualTo(previewed), "one matcher: the engine's assigned scope is what the preview showed");
        Assert.That((await kit.SendAsync(Subject, HttpMethod.Get, "/classes/98501")).Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That((await kit.SendAsync(Subject, HttpMethod.Get, "/classes/98503")).Status, Is.EqualTo(HttpStatusCode.Forbidden));

        var ruleId = saved.Json["rules"]![0]!["id"]!.GetValue<int>();
        await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/rules/{ruleId}/revoke", $$"""{"reason": "Over", "version": "{{saved.Json["version"]!.GetValue<string>()}}"}""");
        Assert.That((await kit.SendAsync(Subject, HttpMethod.Get, "/classes/98501")).Status, Is.EqualTo(HttpStatusCode.Forbidden), "a revoked rule stops working at once");
    }

    [Test]
    public async Task Simultaneous_saves_for_one_member_succeed_once_and_the_others_are_member_changed()
    {
        var (version, hash) = await DraftAsync(GentsAdmin, Subject, 1, Ville);

        var replies = await Task.WhenAll(Enumerable.Range(0, 6).Select(i =>
            kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/members/{Subject}/rules", Body(1, Ville, "Race " + i, version, hash))));

        Assert.That(replies.Count(r => r.Status == HttpStatusCode.OK), Is.EqualTo(1), string.Join(" | ", replies.Select(r => r.Body)));
        Assert.That(replies.Where(r => r.Status != HttpStatusCode.OK).Select(r => r.Json!["code"]!.GetValue<string>()), Is.All.EqualTo("member_changed"));
        Assert.That(await CountAsync("access.class_access_rules", $"token = {Subject}"), Is.EqualTo(1));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'access.class_access_rule_created'"), Is.EqualTo(1));
    }

    [Test]
    public async Task Simultaneous_revokes_of_one_rule_succeed_once()
    {
        var (version, hash) = await DraftAsync(GentsAdmin, Subject, 1, Ville);
        var saved = await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/members/{Subject}/rules", Body(1, Ville, "Race", version, hash));
        var ruleId = saved.Json!["rules"]![0]!["id"]!.GetValue<int>();
        var current = saved.Json["version"]!.GetValue<string>();

        var replies = await Task.WhenAll(Enumerable.Range(0, 5).Select(_ =>
            kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/rules/{ruleId}/revoke", $$"""{"reason": "Race", "version": "{{current}}"}""")));

        Assert.That(replies.Count(r => r.Status == HttpStatusCode.OK), Is.EqualTo(1), string.Join(" | ", replies.Select(r => r.Body)));
        Assert.That(replies.Count(r => r.Status == HttpStatusCode.Conflict), Is.EqualTo(4));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'access.class_access_rule_revoked'"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_stale_version_or_a_hash_of_another_draft_writes_nothing()
    {
        var (version, hash) = await DraftAsync(GentsAdmin, Subject, 1, Ville);

        var stale = await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/members/{Subject}/rules", Body(1, Ville, "Why", "0:0000000000000000", hash));
        var other = await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/members/{Subject}/rules", Body(1, "{\"field\": \"city\", \"value\": \"GRother\"}", "Why", version, hash));

        Assert.That(stale.Status, Is.EqualTo(HttpStatusCode.Conflict));
        Assert.That(stale.Json!["code"]!.GetValue<string>(), Is.EqualTo("member_changed"));
        Assert.That(other.Status, Is.EqualTo(HttpStatusCode.Conflict));
        Assert.That(other.Json!["code"]!.GetValue<string>(), Is.EqualTo("preview_changed"));
        Assert.That(other.Json["classCount"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(await CountAsync("access.class_access_rules"), Is.Zero);
        Assert.That(await CountAsync("platform.outbox"), Is.Zero);
    }

    // --- row scope: who is refused, with what, and that nothing is written ---

    [TestCase(Plain, Subject, 1, 403, "You do not have permission to do that")]
    [TestCase(GentsAdmin, GentsAdmin, 1, 422, "You cannot change your own access")]
    [TestCase(Super, Super, 1, 422, "You cannot change your own access")]
    [TestCase(GentsAdmin, LadiesMember, 1, 403, "This member belongs to the other gender")]
    [TestCase(GentsAdmin, NoGender, 1, 403, "This member belongs to the other gender")]
    [TestCase(Super, NoGender, 1, 403, "This member belongs to the other gender")]
    [TestCase(GentsAdmin, Subject, 2, 403, "This member belongs to the other gender")]
    [TestCase(GentsAdmin, Subject, 0, 403, "This member belongs to the other gender")]
    [TestCase(LadiesAdmin, Subject, 2, 403, "This member belongs to the other gender")]
    [TestCase(LadiesAdmin, Subject, 1, 403, "This member belongs to the other gender")]
    [TestCase(Super, 99999999, 1, 404, "Member not found")]
    public async Task A_rule_save_by_an_operator_outside_their_reach_is_refused_and_writes_nothing(int operatorToken, int memberToken, int gender, int status, string message)
    {
        var genderJson = gender == 0 ? string.Empty : $"\"gender\": {gender}, ";
        var reply = await kit.SendAsync(operatorToken, HttpMethod.Post, $"/admin/class-access/members/{memberToken}/rules",
            $$"""{ {{genderJson}}"conditions": [{{Ville}}], "reason": "Why", "version": "x", "previewHash": "x"}""");

        Assert.That((int)reply.Status, Is.EqualTo(status), reply.Body);
        Assert.That(reply.Detail, Is.EqualTo(message));
        Assert.That(await CountAsync("access.class_access_rules"), Is.Zero);
        Assert.That(await CountAsync("access.user_roles", "roleid = 5"), Is.Zero);
        Assert.That(await CountAsync("platform.outbox"), Is.Zero);
    }

    [Test]
    public async Task A_city_only_the_other_genders_classes_have_is_not_offered_to_a_gender_admin_and_nothing_is_written()
    {
        await TestDatabase.ExecuteAsync("insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, city, country, status, created_by) values "
            + $"(98507, 'GR-L-507', 7, 'grl7', 'Gr Ladies Only', 2, {Super}, 2, 'Offline', 'GRlady', 'Grland', 'A', {Super})");
        var lady = "{\"field\": \"city\", \"value\": \"GRlady\"}";

        var preview = await kit.SendAsync(GentsAdmin, HttpMethod.Post, "/admin/class-access/preview", $$"""{"gender": 1, "conditions": [{{lady}}]}""");
        var save = await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/members/{Subject}/rules", Body(1, lady, "Why", "x", "x"));

        Assert.That((int)preview.Status, Is.EqualTo(422));
        Assert.That(preview.Detail, Is.EqualTo("Choose a city from the list"));
        Assert.That((int)save.Status, Is.EqualTo(422));
        Assert.That(save.Detail, Is.EqualTo("Choose a city from the list"));
        Assert.That(await CountAsync("access.class_access_rules"), Is.Zero);
    }

    [Test]
    public async Task The_rules_of_the_other_gender_and_of_either_gender_cannot_be_revoked_by_a_gender_admin_and_are_not_listed_to_them()
    {
        var gentsRule = await AddRuleAsync(Other, 1, "Gents, GRville");
        var ladiesRule = await AddRuleAsync(Other, 2, "Ladies, GRville");
        var eitherRule = await AddRuleAsync(Other, null, "Any gender, GRville");
        var ladiesMemberRule = await AddRuleAsync(LadiesMember, 2, "Ladies, GRville");
        var view = await kit.SendAsync(GentsAdmin, HttpMethod.Get, $"/admin/class-access/members/{Other}");
        var version = view.Json!["version"]!.GetValue<string>();

        Assert.That(view.Json["rules"]!.AsArray().Select(r => r!["id"]!.GetValue<int>()), Is.EqualTo(new[] { gentsRule }));
        foreach (var (rule, who) in new[] { (ladiesRule, GentsAdmin), (eitherRule, GentsAdmin), (ladiesMemberRule, GentsAdmin), (gentsRule, LadiesAdmin), (ladiesRule, LadiesAdmin) })
        {
            var reply = await kit.SendAsync(who, HttpMethod.Post, $"/admin/class-access/rules/{rule}/revoke", $$"""{"reason": "Why", "version": "{{version}}"}""");
            Assert.That((int)reply.Status, Is.EqualTo(403), $"rule {rule} by {who}: {reply.Body}");
            Assert.That(reply.Detail, Is.EqualTo("This member belongs to the other gender"));
        }

        Assert.That(await CountAsync("access.class_access_rules", "revoked_at is null"), Is.EqualTo(4));
        Assert.That(await CountAsync("platform.outbox"), Is.Zero);
    }

    [Test]
    public async Task A_gender_admin_cannot_add_a_rule_to_or_remove_a_rule_from_a_gender_admin_or_a_super_admin()
    {
        await MembershipTestKit.AddMemberAsync(925005, "Gr 925005", "1");
        await TestDatabase.ExecuteAsync("insert into access.user_roles (user_id, roleid) select id, 3 from identity.users where token = 925005");
        var peerRule = await AddRuleAsync(925005, 1, "Gents, GRville");
        var superRule = await AddRuleAsync(Super, 1, "Gents, GRville");
        await TestDatabase.ExecuteAsync($"update access.class_access_rules set granted_by = {await UserIdAsync(GentsAdmin)} where id in ({peerRule}, {superRule})");

        foreach (var target in new[] { 925005, Super })
        {
            var (version, hash) = await DraftAsync(GentsAdmin, target, 1, "{\"field\": \"city\", \"value\": \"GRother\"}");
            var add = await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/members/{target}/rules", Body(1, "{\"field\": \"city\", \"value\": \"GRother\"}", "Why", version, hash));
            Assert.That((int)add.Status, Is.EqualTo(403), $"add to {target}: {add.Body}");
            Assert.That(add.Detail, Is.EqualTo("You do not have permission to do that"));
        }

        foreach (var rule in new[] { peerRule, superRule })
        {
            var remove = await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/rules/{rule}/revoke", """{"reason": "Why", "version": "x"}""");
            Assert.That((int)remove.Status, Is.EqualTo(403), $"remove {rule}: {remove.Body}");
            Assert.That(remove.Detail, Is.EqualTo("You do not have permission to do that"));
        }

        Assert.That(await CountAsync("access.class_access_rules", "revoked_at is null"), Is.EqualTo(2));
        Assert.That(await CountAsync("platform.outbox"), Is.Zero);
    }

    [Test]
    public async Task A_super_admin_may_add_a_rule_to_a_gender_admin_and_remove_a_rule_it_did_not_grant()
    {
        await MembershipTestKit.AddMemberAsync(925005, "Gr 925005", "1");
        await TestDatabase.ExecuteAsync("insert into access.user_roles (user_id, roleid) select id, 3 from identity.users where token = 925005");
        var (version, hash) = await DraftAsync(Super, 925005, 1, Ville);
        var added = await kit.SendAsync(Super, HttpMethod.Post, "/admin/class-access/members/925005/rules", Body(1, Ville, "Peer", version, hash));
        Assert.That(added.Status, Is.EqualTo(HttpStatusCode.OK), added.Body);

        var fixtureRule = await AddRuleAsync(Other, 1, "Gents, GRville");
        var view = await kit.SendAsync(Super, HttpMethod.Get, $"/admin/class-access/members/{Other}");
        var removed = await kit.SendAsync(Super, HttpMethod.Post, $"/admin/class-access/rules/{fixtureRule}/revoke", $$"""{"reason": "Why", "version": "{{view.Json!["version"]!.GetValue<string>()}}"}""");

        Assert.That(removed.Status, Is.EqualTo(HttpStatusCode.OK), removed.Body);
    }

    [Test]
    public async Task A_rule_may_be_removed_only_by_the_operator_who_granted_it_or_a_super_admin()
    {
        var (version, hash) = await DraftAsync(GentsAdmin, Subject, 1, Ville);
        var saved = await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/members/{Subject}/rules", Body(1, Ville, "Mine", version, hash));
        var ruleId = saved.Json!["rules"]![0]!["id"]!.GetValue<int>();
        var current = saved.Json["version"]!.GetValue<string>();
        var fixtureRule = await AddRuleAsync(Other, 1, "Gents, GRville");
        var otherVersion = (await kit.SendAsync(GentsAdmin, HttpMethod.Get, $"/admin/class-access/members/{Other}")).Json!["version"]!.GetValue<string>();
        await MembershipTestKit.AddMemberAsync(925005, "Gr 925005", "1");
        await TestDatabase.ExecuteAsync("insert into access.user_roles (user_id, roleid) select id, 3 from identity.users where token = 925005");

        var byPeer = await kit.SendAsync(925005, HttpMethod.Post, $"/admin/class-access/rules/{ruleId}/revoke", $$"""{"reason": "Why", "version": "{{current}}"}""");
        var ungranted = await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/admin/class-access/rules/{fixtureRule}/revoke", $$"""{"reason": "Why", "version": "{{otherVersion}}"}""");

        Assert.That((int)byPeer.Status, Is.EqualTo(403), byPeer.Body);
        Assert.That(byPeer.Detail, Is.EqualTo("You do not have permission to do that"));
        Assert.That((int)ungranted.Status, Is.EqualTo(403), ungranted.Body);
        Assert.That(await CountAsync("access.class_access_rules", "revoked_at is null"), Is.EqualTo(2));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'access.class_access_rule_revoked'"), Is.Zero);

        var bySuper = await kit.SendAsync(Super, HttpMethod.Post, $"/admin/class-access/rules/{ruleId}/revoke", $$"""{"reason": "Why", "version": "{{current}}"}""");
        Assert.That(bySuper.Status, Is.EqualTo(HttpStatusCode.OK), bySuper.Body);
    }

    [Test]
    public async Task The_options_and_the_matched_classes_follow_the_genders_the_operator_manages_and_active_classes_only()
    {
        await TestDatabase.ExecuteAsync("insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, city, country, status, created_by) values "
            + $"(98506, 'GR-G-506', 7, 'grl6', 'Gr Closed Only', 2, {Super}, 1, 'Offline', 'GRclosed', 'Grclosedland', 'I', {Super}), "
            + $"(98507, 'GR-L-507', 7, 'grl7', 'Gr Ladies Only', 2, {Super}, 2, 'Offline', 'GRlady', 'Grland', 'A', {Super})");

        var gents = (await kit.SendAsync(GentsAdmin, HttpMethod.Get, "/admin/class-access/options")).Json!;
        var super = (await kit.SendAsync(Super, HttpMethod.Get, "/admin/class-access/options")).Json!;

        Assert.That(Strings(gents["cities"]), Is.EquivalentTo(Items("GRother", "GRville")), "no ladies-only city and no closed-only city");
        Assert.That(Strings(super["cities"]), Is.EquivalentTo(Items("GRlady", "GRother", "GRville")));
        Assert.That(Strings(super["countries"]), Is.EquivalentTo(Items("Grland")));
        Assert.That(gents["genders"]!.AsArray().Select(g => g!["id"]!.GetValue<int>()), Is.EqualTo(Items(1)));
        var matched = (await kit.SendAsync(Super, HttpMethod.Post, "/admin/class-access/preview", $$"""{"conditions": [{{Ville}}]}""")).Json!;
        Assert.That(matched["classes"]!.AsArray().Select(c => c!["id"]!.GetValue<int>()), Is.EqualTo(Items(98501, 98502, 98505)), "a closed class is never reached, both genders for a rule of either gender");
    }

    // --- the one published view of class levels (finding: design point 8) ---

    [Test]
    public async Task One_published_view_of_class_levels_serves_the_class_access_screens_and_the_notification_history()
    {
        Assert.That(await CountAsync("information_schema.views", "table_schema = 'classes' and table_name like 'v_class_level%'"), Is.EqualTo(1));
        Assert.That(await CountAsync("information_schema.columns", "table_schema = 'classes' and table_name = 'v_class_levels' and column_name in ('id', 'code', 'name', 'sort_order')"), Is.EqualTo(4));

        var options = (await kit.SendAsync(Super, HttpMethod.Get, "/admin/class-access/options")).Json!;
        Assert.That(options["levels"]!.AsArray().Select(l => l!["id"]!.GetValue<int>()).Take(3), Is.EqualTo(Items(1, 2, 3)));
        var name = await TestDatabase.ScalarAsync<string>("select trim(name) from classes.v_class_levels where id = any(array[2])", TestDatabase.OwnerConnection);
        Assert.That(name, Is.EqualTo("ABUZAR"));
    }

    private static T[] Items<T>(params T[] items) => items;

    private static IEnumerable<string> Strings(JsonNode? array) => array!.AsArray().Select(v => v!.GetValue<string>());

    private static string Body(int gender, string condition, string reason, string version, string hash) =>
        $$"""{"gender": {{gender}}, "conditions": [{{condition}}], "reason": "{{reason}}", "version": "{{version}}", "previewHash": "{{hash}}"}""";

    private async Task<(string Version, string Hash)> DraftAsync(int operatorToken, int memberToken, int gender, string condition)
    {
        var view = await kit.SendAsync(operatorToken, HttpMethod.Get, $"/admin/class-access/members/{memberToken}");
        var preview = await kit.SendAsync(operatorToken, HttpMethod.Post, "/admin/class-access/preview", $$"""{"gender": {{gender}}, "conditions": [{{condition}}]}""");
        Assert.That(view.Status, Is.EqualTo(HttpStatusCode.OK), view.Body);
        Assert.That(preview.Status, Is.EqualTo(HttpStatusCode.OK), preview.Body);
        return (view.Json!["version"]!.GetValue<string>(), preview.Json!["previewHash"]!.GetValue<string>());
    }

    private async Task<string> RevisionAsync(int token)
    {
        var reply = await kit.SendAsync(token, HttpMethod.Get, "/me/permissions");
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        return reply.Json!["revision"]!.GetValue<string>();
    }

    private static async Task<int> AddRuleAsync(int token, int? gender, string note)
    {
        var id = await TestDatabase.ScalarAsync<int>(
            $"insert into access.class_access_rules (token, gender, note, reason) values ({token}, {(gender is int g ? g.ToString(System.Globalization.CultureInfo.InvariantCulture) : "null")}, '{note}', 'Fixture') returning id",
            TestDatabase.OwnerConnection);
        await TestDatabase.ExecuteAsync($"insert into access.class_access_rule_conditions (rule_id, field, negate, value) values ({id}, 'city', false, 'GRville')");
        return id;
    }

    private static Task<int> UserIdAsync(int token) =>
        TestDatabase.ScalarAsync<int>($"select id from identity.users where token = {token}", TestDatabase.OwnerConnection);

    private static Task<long> CountAsync(string table, string where = "true") => MembershipTestKit.CountAsync(table, where);

    private static async Task<JsonObject> PayloadAsync(string eventType) =>
        JsonNode.Parse(await TestDatabase.ScalarAsync<string>($"select payload::text from platform.outbox where event_type = '{eventType}' order by id desc limit 1", TestDatabase.OwnerConnection))!.AsObject();
}
