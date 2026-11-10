using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The six guardian self-service operations against a real database, as the limited role: PHP's answers, statuses and exact messages
/// (routes/children.php, models/guardians.php), the writes, and the lock that keeps one active link per pair under concurrent accepts.
/// </summary>
public sealed class GuardianTests
{
    private const int Parent = 900401;
    private const int Child = 900402;
    private const int Staff = 900403;
    private const string Code = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01";

    private MembershipTestKit _kit = null!;
    private int _parentId;
    private int _childId;
    private int _staffId;

    [OneTimeSetUp]
    public void Start() => _kit = new MembershipTestKit();

    [OneTimeTearDown]
    public void Stop() => _kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        _parentId = await MembershipTestKit.AddMemberAsync(Parent, "Parent One", "1");
        _childId = await MembershipTestKit.AddMemberAsync(Child, "Child One", "1", firstName: "Kid");
        _staffId = await MembershipTestKit.AddMemberAsync(Staff, "Staff Person", "1");
    }

    // ---- GET /me/children/links

    [Test]
    public async Task The_links_list_shows_every_status_newest_first_with_names_and_PHPs_creator_text()
    {
        await AddLinkAsync(Parent, Child, "father", "active", "token_entry", createdBy: _staffId, createdAt: "2026-01-10 09:00:00");
        await AddLinkAsync(Parent, 900409, "mother", "revoked", "token_entry", createdBy: _parentId, createdAt: "2026-02-10 09:00:00", revokedAt: "2026-02-11 09:00:00");
        await AddLinkAsync(Parent, Child, "guardian", "active", "link", createdBy: _staffId, createdAt: "2025-12-01 09:00:00");

        var reply = await _kit.SendAsync(Parent, HttpMethod.Get, "/me/children/links");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        var rows = reply.Json!.AsArray();
        Assert.That(rows.Select(r => r!["created_at"]!.GetValue<string>()), Is.EqualTo(["2026-02-10 09:00:00", "2026-01-10 09:00:00", "2025-12-01 09:00:00"]));
        Assert.That(rows[0]!["child_name"], Is.Null, "no member holds that token");
        Assert.That(rows[0]!["status"]!.GetValue<string>(), Is.EqualTo("revoked"));
        Assert.That(rows[0]!["revoked_at"]!.GetValue<string>(), Is.EqualTo("2026-02-11 09:00:00"));
        Assert.That(rows[0]!["created_by_name"]!.GetValue<string>(), Is.EqualTo("Parent One"));
        Assert.That(rows[1]!["child_name"]!.GetValue<string>(), Is.EqualTo("Child One"));
        Assert.That(rows[1]!["created_by_name"]!.GetValue<string>(), Is.EqualTo("Staff Person"));
        Assert.That(rows[1]!["id"]!.GetValue<int>(), Is.GreaterThan(0));
        Assert.That(rows[1]!["parent_token"]!.GetValue<int>(), Is.EqualTo(Parent));
        Assert.That(rows[2]!["created_by_name"]!.GetValue<string>(), Is.EqualTo("Invite link"));
    }

    [Test]
    public async Task A_child_token_shared_by_two_members_lists_the_link_once_per_member()
    {
        var other = await TestDatabase.ScalarAsync<int>(
            "insert into identity.users (token, email) values (900402, 'twin@example.invalid') returning id", TestDatabase.OwnerConnection);
        await TestDatabase.ExecuteAsync($"insert into membership.member_profiles (user_id, name) values ({other}, 'Child Twin')");
        await AddLinkAsync(Parent, Child, "father", "active", "token_entry", createdBy: _staffId);

        var rows = (await _kit.SendAsync(Parent, HttpMethod.Get, "/me/children/links")).Json!.AsArray();

        Assert.That(rows.Select(r => r!["child_name"]!.GetValue<string>()), Is.EquivalentTo(["Child One", "Child Twin"]));
    }

    [Test]
    public async Task A_member_with_no_links_gets_an_empty_list_and_never_another_members()
    {
        await AddLinkAsync(900499, Child, "father", "active", "token_entry", createdBy: _staffId);

        var reply = await _kit.SendAsync(Parent, HttpMethod.Get, "/me/children/links");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(reply.Body, Is.EqualTo("[]"));
    }

    // ---- GET /me/children/link/{code}

    [Test]
    public async Task Inspecting_a_live_invite_shows_valid_and_the_childs_first_name()
    {
        await AddInviteAsync(Child, Code, "2099-01-01 00:00:00");

        var reply = await _kit.SendAsync(Parent, HttpMethod.Get, "/me/children/link/" + Code);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(reply.Body, Is.EqualTo("{\"state\":\"valid\",\"first_name\":\"Kid\"}"));
    }

    [Test]
    public async Task A_valid_invite_for_a_child_with_no_first_name_shows_null()
    {
        await TestDatabase.ExecuteAsync($"update membership.member_profiles set first_name = null where user_id = {_childId}");
        await AddInviteAsync(Child, Code, "2099-01-01 00:00:00");

        var reply = await _kit.SendAsync(Parent, HttpMethod.Get, "/me/children/link/" + Code);

        Assert.That(reply.Body, Is.EqualTo("{\"state\":\"valid\",\"first_name\":null}"));
    }

    [Test]
    public async Task An_unknown_used_cancelled_or_past_invite_never_reveals_more_than_its_state()
    {
        await AddInviteAsync(Child, "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb01", "2000-01-01 00:00:00");
        await AddLinkAsync(Parent, Child, "father", "active", "token_entry", createdBy: _staffId, code: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb02");
        await AddLinkAsync(Parent, Child, "father", "revoked", "link", createdBy: _staffId, code: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb03");

        Assert.That((await _kit.SendAsync(Parent, HttpMethod.Get, "/me/children/link/nothing")).Body, Is.EqualTo("{\"state\":\"not_found\"}"));
        Assert.That((await _kit.SendAsync(Parent, HttpMethod.Get, "/me/children/link/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb01")).Body, Is.EqualTo("{\"state\":\"expired\"}"));
        Assert.That((await _kit.SendAsync(Parent, HttpMethod.Get, "/me/children/link/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb02")).Body, Is.EqualTo("{\"state\":\"expired\"}"));
        Assert.That((await _kit.SendAsync(Parent, HttpMethod.Get, "/me/children/link/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb03")).Body, Is.EqualTo("{\"state\":\"expired\"}"));
    }

    [Test]
    public async Task Inspecting_writes_nothing_and_the_sixty_first_call_in_an_hour_is_a_429()
    {
        await AddInviteAsync(Child, Code, "2099-01-01 00:00:00");

        for (var call = 1; call <= 60; call++)
        {
            Assert.That((await _kit.SendAsync(Staff, HttpMethod.Get, "/me/children/link/" + Code)).Status, Is.EqualTo(HttpStatusCode.OK), "call " + call);
        }

        var refused = await _kit.SendAsync(Staff, HttpMethod.Get, "/me/children/link/" + Code);

        Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.TooManyRequests));
        Assert.That(refused.Detail, Is.EqualTo("Too many lookups; try again later"));
        Assert.That((await _kit.SendAsync(Parent, HttpMethod.Get, "/me/children/link/" + Code)).Status, Is.EqualTo(HttpStatusCode.OK), "the count is per member");
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", "status = 'invited'"), Is.EqualTo(1));
    }

    // ---- POST /me/children/link/{code}

    [Test]
    public async Task Accepting_a_live_invite_activates_it_with_the_lower_cased_relationship()
    {
        await AddInviteAsync(Child, Code, "2099-01-01 00:00:00", createdBy: _childId);

        var reply = await _kit.SendAsync(Parent, HttpMethod.Post, "/me/children/link/" + Code, "{\"relationship\":\"  Mother \"}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(reply.Body, Is.EqualTo($"{{\"child_token\":{Child},\"relationship\":\"mother\",\"status\":\"active\"}}"));
        var row = (await TestDatabase.RowAsync($"select parent_token, relationship, status, activated_at is not null as activated from membership.user_guardians where code = '{Code}'"))!;
        Assert.That(row["parent_token"], Is.EqualTo(Parent.ToString(System.Globalization.CultureInfo.InvariantCulture)));
        Assert.That(row["relationship"], Is.EqualTo("mother"));
        Assert.That(row["status"], Is.EqualTo("active"));
        Assert.That(row["activated"], Is.EqualTo("true"));
        Assert.That((await _kit.SendAsync(Parent, HttpMethod.Post, "/me/children/link/" + Code, "{\"relationship\":\"mother\"}")).Status, Is.EqualTo(HttpStatusCode.Gone), "used");
    }

    [Test]
    public async Task The_refusals_come_in_PHPs_order_with_PHPs_statuses_and_texts()
    {
        await AddInviteAsync(Child, Code, "2099-01-01 00:00:00", createdBy: _staffId);
        await AddInviteAsync(Child, "cccccccccccccccccccccccccccccc01", "2000-01-01 00:00:00", createdBy: _childId);
        await AddInviteAsync(900499, "cccccccccccccccccccccccccccccc02", "2099-01-01 00:00:00", createdBy: _childId);
        await TestDatabase.ExecuteAsync("insert into identity.users (token, email) values (900405, 'a@example.invalid'), (900405, 'b@example.invalid')");
        await AddInviteAsync(900405, "cccccccccccccccccccccccccccccc03", "2099-01-01 00:00:00", createdBy: _childId);

        await AssertAsync(Parent, "unknown", "{\"relationship\":\"father\"}", HttpStatusCode.NotFound, "Invite not found");
        await AssertAsync(Parent, "cccccccccccccccccccccccccccccc01", "{\"relationship\":\"nonsense\"}", HttpStatusCode.Gone, "This link has expired or has already been used");
        await AssertAsync(Parent, Code, "{\"relationship\":\"uncle\"}", HttpStatusCode.UnprocessableEntity, "Invalid relationship or self-link not allowed");
        await AssertAsync(Parent, Code, "{}", HttpStatusCode.UnprocessableEntity, "Invalid relationship or self-link not allowed");
        await AssertAsync(Parent, Code, "{\"relationship\":[\"father\"]}", HttpStatusCode.UnprocessableEntity, "Invalid relationship or self-link not allowed");
        await AssertAsync(Child, Code, "{\"relationship\":\"father\"}", HttpStatusCode.UnprocessableEntity, "Invalid relationship or self-link not allowed");
        await AssertAsync(Staff, Code, "{\"relationship\":\"father\"}", HttpStatusCode.UnprocessableEntity, "Invalid relationship or self-link not allowed");
        await AssertAsync(Parent, "cccccccccccccccccccccccccccccc02", "{\"relationship\":\"father\"}", HttpStatusCode.NotFound, "Invite not found");
        await AssertAsync(Parent, "cccccccccccccccccccccccccccccc03", "{\"relationship\":\"father\"}", HttpStatusCode.UnprocessableEntity, "Invalid relationship or self-link not allowed");
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", "status = 'active'"), Is.EqualTo(0));
    }

    [Test]
    public async Task A_caller_whose_own_token_is_shared_is_refused_with_the_invalid_text()
    {
        await TestDatabase.ExecuteAsync("insert into identity.users (token, email, firebase_uid) values (900401, 'twin@example.invalid', 'uid-twin')");
        await AddInviteAsync(Child, Code, "2099-01-01 00:00:00", createdBy: _childId);

        await AssertAsync(Parent, Code, "{\"relationship\":\"father\"}", HttpStatusCode.UnprocessableEntity, "Invalid relationship or self-link not allowed");
    }

    [Test]
    public async Task A_body_that_is_not_JSON_is_a_422_before_anything_else_is_looked_at()
    {
        var reply = await _kit.SendAsync(Parent, HttpMethod.Post, "/me/children/link/unknown", "not json");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(reply.Detail, Is.EqualTo("Invalid JSON body"));
    }

    [Test]
    public async Task A_parent_the_child_removed_needs_an_invite_from_someone_who_manages_parents_for_the_childs_gender()
    {
        await AddLinkAsync(Parent, Child, "father", "revoked", "token_entry", createdBy: _staffId, revokedBy: _childId);
        await AddInviteAsync(Child, Code, "2099-01-01 00:00:00", createdBy: _staffId);

        await AssertAsync(Parent, Code, "{\"relationship\":\"father\"}", HttpStatusCode.Forbidden, "This person was removed by the child; ask an admin for a new link");

        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({_staffId}, 3)");
        var reply = await _kit.SendAsync(Parent, HttpMethod.Post, "/me/children/link/" + Code, "{\"relationship\":\"father\"}");
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), "a gents admin may bring back a gents child's parent");
    }

    [Test]
    public async Task A_gents_admin_may_not_bring_back_a_parent_of_a_ladies_child()
    {
        await TestDatabase.ExecuteAsync($"update membership.member_profiles set gender = '2' where user_id = {_childId}");
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({_staffId}, 3)");
        await AddLinkAsync(Parent, Child, "father", "revoked", "token_entry", createdBy: _staffId, revokedBy: _childId);
        await AddInviteAsync(Child, Code, "2099-01-01 00:00:00", createdBy: _staffId);

        await AssertAsync(Parent, Code, "{\"relationship\":\"father\"}", HttpStatusCode.Forbidden, "This person was removed by the child; ask an admin for a new link");
    }

    [Test]
    public async Task A_parent_removed_by_someone_other_than_the_child_may_come_back_by_invite()
    {
        await AddLinkAsync(Parent, Child, "father", "revoked", "token_entry", createdBy: _staffId, revokedBy: _staffId);
        await AddInviteAsync(Child, Code, "2099-01-01 00:00:00", createdBy: _childId);

        var reply = await _kit.SendAsync(Parent, HttpMethod.Post, "/me/children/link/" + Code, "{\"relationship\":\"father\"}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", "status = 'revoked'"), Is.EqualTo(1), "the old revoked row stays");
    }

    [Test]
    public async Task A_second_invite_for_a_pair_that_is_already_linked_is_a_409_and_stays_unused()
    {
        await AddLinkAsync(Parent, Child, "father", "active", "token_entry", createdBy: _staffId);
        await AddInviteAsync(Child, Code, "2099-01-01 00:00:00", createdBy: _childId);

        await AssertAsync(Parent, Code, "{\"relationship\":\"mother\"}", HttpStatusCode.Conflict, "An active link already exists for this parent and child");

        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", $"code = '{Code}' and status = 'invited'"), Is.EqualTo(1));
    }

    [Test]
    public async Task Two_invites_for_one_pair_accepted_at_once_make_exactly_one_active_link()
    {
        for (var round = 0; round < 8; round++)
        {
            await TestDatabase.ExecuteAsync("truncate membership.user_guardians restart identity");
            await AddInviteAsync(Child, "dddddddddddddddddddddddddddddd01", "2099-01-01 00:00:00", createdBy: _childId);
            await AddInviteAsync(Child, "dddddddddddddddddddddddddddddd02", "2099-01-01 00:00:00", createdBy: _childId);

            var replies = await Task.WhenAll(
                _kit.SendAsync(Parent, HttpMethod.Post, "/me/children/link/dddddddddddddddddddddddddddddd01", "{\"relationship\":\"father\"}"),
                _kit.SendAsync(Parent, HttpMethod.Post, "/me/children/link/dddddddddddddddddddddddddddddd02", "{\"relationship\":\"father\"}"));

            Assert.That(replies.Select(r => r.Status).Order(), Is.EqualTo(new[] { HttpStatusCode.OK, HttpStatusCode.Conflict }), "round " + round);
            Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", "status = 'active'"), Is.EqualTo(1), "round " + round);
        }
    }

    [Test]
    public async Task Accepting_a_used_invite_twice_at_once_activates_it_once()
    {
        const int second = 900404;
        await MembershipTestKit.AddMemberAsync(second, "Parent Two", "1");
        await AddInviteAsync(Child, Code, "2099-01-01 00:00:00", createdBy: _childId);

        var replies = await Task.WhenAll(
            _kit.SendAsync(Parent, HttpMethod.Post, "/me/children/link/" + Code, "{\"relationship\":\"father\"}"),
            _kit.SendAsync(second, HttpMethod.Post, "/me/children/link/" + Code, "{\"relationship\":\"mother\"}"));

        Assert.That(replies.Select(r => r.Status).Order(), Is.EqualTo(new[] { HttpStatusCode.OK, HttpStatusCode.Gone }));
    }

    // ---- DELETE /me/children/{child_token}/link and DELETE /me/parents/{parent_token}

    [Test]
    public async Task A_parent_revokes_their_own_active_link_and_the_row_records_who_and_when()
    {
        await AddLinkAsync(Parent, Child, "father", "active", "token_entry", createdBy: _staffId);

        var reply = await _kit.SendAsync(Parent, HttpMethod.Delete, $"/me/children/{Child}/link");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.NoContent));
        Assert.That(reply.Body, Is.Empty);
        var row = (await TestDatabase.RowAsync("select status, revoked_by, revoked_at is not null as stamped from membership.user_guardians"))!;
        Assert.That(row["status"], Is.EqualTo("revoked"));
        Assert.That(row["revoked_by"], Is.EqualTo(_parentId.ToString(System.Globalization.CultureInfo.InvariantCulture)));
        Assert.That(row["stamped"], Is.EqualTo("true"));
    }

    [TestCase("12345")]
    [TestCase("abc")]
    public async Task Revoking_a_link_that_is_not_there_is_a_404_and_a_non_number_is_token_zero(string childToken)
    {
        var reply = await _kit.SendAsync(Parent, HttpMethod.Delete, $"/me/children/{childToken}/link");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(reply.Detail, Is.EqualTo("Active link not found"));
    }

    [Test]
    public async Task Revoking_twice_the_second_time_is_a_404_and_a_revoked_or_invited_row_is_not_touched()
    {
        await AddLinkAsync(Parent, Child, "father", "revoked", "token_entry", createdBy: _staffId, revokedBy: _staffId);

        var reply = await _kit.SendAsync(Parent, HttpMethod.Delete, $"/me/children/{Child}/link");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", $"revoked_by = {_staffId}"), Is.EqualTo(1));
    }

    [Test]
    public async Task One_revoke_ends_every_active_row_of_a_pair_as_PHPs_update_does()
    {
        await AddLinkAsync(Parent, Child, "father", "active", "token_entry", createdBy: _staffId);
        await AddLinkAsync(Parent, Child, "mother", "active", "token_entry", createdBy: _staffId);

        await _kit.SendAsync(Parent, HttpMethod.Delete, $"/me/children/{Child}/link");

        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", "status = 'revoked'"), Is.EqualTo(2));
    }

    [Test]
    public async Task A_child_lists_only_their_active_parents_with_the_parents_name()
    {
        await AddLinkAsync(Parent, Child, "father", "active", "token_entry", createdBy: _staffId, createdAt: "2026-03-01 09:00:00");
        await AddLinkAsync(Staff, Child, "mother", "revoked", "token_entry", createdBy: _staffId);
        await AddLinkAsync(Parent, 900499, "father", "active", "token_entry", createdBy: _staffId);

        var reply = await _kit.SendAsync(Child, HttpMethod.Get, "/me/parents");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        var rows = reply.Json!.AsArray();
        Assert.That(rows, Has.Count.EqualTo(1));
        Assert.That(rows[0]!["parent_name"]!.GetValue<string>(), Is.EqualTo("Parent One"));
        Assert.That(rows[0]!["child_token"]!.GetValue<int>(), Is.EqualTo(Child));
        Assert.That(rows[0]!["created_by_name"]!.GetValue<string>(), Is.EqualTo("Staff Person"));
        Assert.That(rows[0]!.AsObject().ContainsKey("child_name"), Is.False);
        Assert.That((await _kit.SendAsync(Parent, HttpMethod.Get, "/me/parents")).Body, Is.EqualTo("[]"));
    }

    [Test]
    public async Task A_child_revokes_a_parent_and_the_row_records_the_child_so_a_return_needs_an_admin()
    {
        await AddLinkAsync(Parent, Child, "father", "active", "token_entry", createdBy: _staffId);

        var reply = await _kit.SendAsync(Child, HttpMethod.Delete, $"/me/parents/{Parent}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.NoContent));
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", $"status = 'revoked' and revoked_by = {_childId}"), Is.EqualTo(1));
        var again = await _kit.SendAsync(Child, HttpMethod.Delete, $"/me/parents/{Parent}");
        Assert.That(again.Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(again.Detail, Is.EqualTo("Active parent link not found"));
    }

    [Test]
    public async Task A_parent_cannot_revoke_through_the_childs_route()
    {
        await AddLinkAsync(Parent, Child, "father", "active", "token_entry", createdBy: _staffId);

        var reply = await _kit.SendAsync(Parent, HttpMethod.Delete, $"/me/parents/{Child}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", "status = 'active'"), Is.EqualTo(1));
    }

    // ---- helpers

    private async Task AssertAsync(int caller, string code, string json, HttpStatusCode status, string detail)
    {
        var reply = await _kit.SendAsync(caller, HttpMethod.Post, "/me/children/link/" + code, json);

        Assert.That(reply.Status, Is.EqualTo(status), "code " + code + " by " + caller + ": " + reply.Body);
        Assert.That(reply.Detail, Is.EqualTo(detail));
    }

    private static Task AddInviteAsync(int childToken, string code, string expiresAt, int? createdBy = null) =>
        TestDatabase.ExecuteAsync(
            "insert into membership.user_guardians (child_token, status, source, code, expires_at, created_by) values "
            + $"({childToken}, 'invited', 'link', '{code}', '{expiresAt}+00', {createdBy ?? 0})");

    private static Task AddLinkAsync(
        int parentToken, int childToken, string relationship, string status, string source, int createdBy,
        string createdAt = "2026-01-01 09:00:00", string? revokedAt = null, int? revokedBy = null, string? code = null) =>
        TestDatabase.ExecuteAsync(
            "insert into membership.user_guardians (parent_token, child_token, relationship, status, source, code, created_by, created_at, activated_at, revoked_by, revoked_at) values "
            + $"({parentToken}, {childToken}, '{relationship}', '{status}', '{source}', {MembershipTestKit.Quote(code)}, {createdBy}, '{createdAt}+00', '{createdAt}+00', "
            + $"{(revokedBy is null ? "null" : revokedBy.Value.ToString(System.Globalization.CultureInfo.InvariantCulture))}, {(revokedAt is null && status == "revoked" ? "'2026-01-02 09:00:00+00'" : revokedAt is null ? "null" : $"'{revokedAt}+00'")})");
}
