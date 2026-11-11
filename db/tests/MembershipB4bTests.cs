using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// Batch B4b: the staff parent-link writes, the rejection of a waiting registrant and the people cards, through the API as the limited role. Hurl runs on PHP too and cannot see the outbox or the
/// lock, so the rows, the one event per change (none for a refusal, never an invite code) and the limits of a caller who is NOT a super admin are proved here: a gents admin (reach by gender) and a
/// class coordinator (role 5, reach by assigned class).
/// </summary>
public sealed class MembershipB4bTests
{
    private const int Admin = 901401;
    private const int Child = 901402;
    private const int Parent = 901403;
    private const int Coordinator = 901404;
    private const int Outsider = 901405;
    private const int Registrant = 901406;
    private const int LadiesRegistrant = 901407;
    private const int GentsAdmin = 901408;
    private const int ClassId = 9941;

    private MembershipTestKit kit = null!;
    private int adminId;
    private int childId;
    private int coordinatorId;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit();

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync(
            "truncate platform.outbox, classes.class_students, classes.classes, access.class_access_rule_conditions, access.class_access_rules, access.user_permissions restart identity cascade");
        adminId = await MembershipTestKit.AddMemberAsync(Admin, "B4b Admin", "1");
        childId = await MembershipTestKit.AddMemberAsync(Child, "B4b Child", "1");
        await MembershipTestKit.AddMemberAsync(Parent, "B4b Parent", "1");
        coordinatorId = await MembershipTestKit.AddMemberAsync(Coordinator, "B4b Coordinator", "1");
        await MembershipTestKit.AddMemberAsync(Outsider, "B4b Outsider", "1");
        await MembershipTestKit.AddMemberAsync(Registrant, "B4b Registrant", "1");
        await MembershipTestKit.AddMemberAsync(LadiesRegistrant, "B4b Ladies Registrant", "2");
        var gentsAdmin = await MembershipTestKit.AddMemberAsync(GentsAdmin, "B4b Gents Admin", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({adminId}, 1), ({coordinatorId}, 5), ({gentsAdmin}, 3); "
            + "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (1, 'SM', 'SALMAN', 1), (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + $"insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values ({ClassId}, 'B4B-C', 1, 'b4blink', 'B4b Class', 3, {Admin}, 1, 'Offline', 'A', {Admin}); "
            + $"insert into classes.class_students (class_id, token_no, joined_on, mcq_admin) values ({ClassId}, {Child}, current_date, 0); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (1, {Coordinator}, 1, 'gents level 3'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (1, 'level', false, 3)");
    }

    // ---- invites

    [Test]
    public async Task An_invite_is_one_row_and_one_event_and_the_event_never_carries_the_code()
    {
        var made = await kit.SendAsync(Admin, HttpMethod.Post, $"/members/{Child}/parent-links");

        Assert.That(made.Status, Is.EqualTo(HttpStatusCode.Created), made.Body);
        var code = made.Json!["code"]!.GetValue<string>();
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", $"child_token = {Child} and status = 'invited' and source = 'link' and created_by = {adminId} and code = '{code}'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'membership.parent_invite_created'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", $"payload::text like '%{code}%'"), Is.EqualTo(0));
    }

    [Test]
    public async Task Concurrent_invites_for_one_child_stop_at_five_under_the_lock()
    {
        var replies = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => kit.SendAsync(Admin, HttpMethod.Post, $"/members/{Child}/parent-links")));

        Assert.That(replies.Count(r => r.Status == HttpStatusCode.Created), Is.EqualTo(5));
        Assert.That(replies.Count(r => r.Status == HttpStatusCode.UnprocessableEntity), Is.EqualTo(3));
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", $"child_token = {Child} and status = 'invited'"), Is.EqualTo(5));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'membership.parent_invite_created'"), Is.EqualTo(5));
    }

    [Test]
    public async Task A_class_coordinator_may_invite_for_a_student_in_their_class_and_not_for_another()
    {
        Assert.That((await kit.SendAsync(Coordinator, HttpMethod.Post, $"/members/{Child}/parent-links")).Status, Is.EqualTo(HttpStatusCode.Created));

        var other = await kit.SendAsync(Coordinator, HttpMethod.Post, $"/members/{Outsider}/parent-links");

        Assert.That(other.Status, Is.EqualTo(HttpStatusCode.NotFound), other.Body);
        Assert.That(other.Detail, Is.EqualTo("Student not found"));
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", $"child_token = {Outsider}"), Is.EqualTo(0));
    }

    [Test]
    public async Task Cancelling_is_for_the_creator_or_a_manager_and_never_anyone_else()
    {
        var inviteId = await AddInviteAsync(Child, adminId);

        var stranger = await kit.SendAsync(Coordinator, HttpMethod.Delete, $"/members/{Child}/parent-links/{inviteId}");
        Assert.That(stranger.Status, Is.EqualTo(HttpStatusCode.NotFound), stranger.Body);
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", $"id = {inviteId} and status = 'invited'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));

        var coordinatorInvite = await AddInviteAsync(Child, coordinatorId);
        Assert.That((await kit.SendAsync(Coordinator, HttpMethod.Delete, $"/members/{Child}/parent-links/{coordinatorInvite}")).Status, Is.EqualTo(HttpStatusCode.NoContent));
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", $"id = {coordinatorInvite} and status = 'revoked' and revoked_by = {coordinatorId} and revoked_at is not null"), Is.EqualTo(1));

        Assert.That((await kit.SendAsync(Admin, HttpMethod.Delete, $"/members/{Child}/parent-links/{inviteId}")).Status, Is.EqualTo(HttpStatusCode.NoContent));
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", $"id = {inviteId} and status = 'revoked' and revoked_by = {adminId}"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'membership.parent_invite_cancelled'"), Is.EqualTo(2));
        Assert.That((await kit.SendAsync(Admin, HttpMethod.Delete, $"/members/{Child}/parent-links/{inviteId}")).Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'membership.parent_invite_cancelled'"), Is.EqualTo(2));
    }

    // ---- direct add and candidate

    [Test]
    public async Task A_direct_add_writes_one_active_row_and_one_event_and_a_refusal_writes_nothing()
    {
        var added = await kit.SendAsync(Admin, HttpMethod.Post, $"/members/{Child}/parents", $$"""{"parent_token": {{Parent}}, "relationship": " Mother "}""");

        Assert.That(added.Status, Is.EqualTo(HttpStatusCode.Created), added.Body);
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", $"parent_token = {Parent} and child_token = {Child} and relationship = 'mother' and status = 'active' and source = 'token_entry' and created_by = {adminId} and activated_at is not null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'membership.parent_link_added'"), Is.EqualTo(1));

        var again = await kit.SendAsync(Admin, HttpMethod.Post, $"/members/{Child}/parents", $$"""{"parent_token": {{Parent}}, "relationship": "mother"}""");
        Assert.That(again.Status, Is.EqualTo(HttpStatusCode.Conflict));
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_parent_the_child_removed_returns_only_through_someone_who_manages_parents()
    {
        await TestDatabase.ExecuteAsync(
            "insert into membership.user_guardians (parent_token, child_token, relationship, status, source, created_by, created_at, revoked_by, revoked_at) "
            + $"values ({Parent}, {Child}, 'father', 'revoked', 'token_entry', {adminId}, now(), {childId}, now())");
        var body = $$"""{"parent_token": {{Parent}}, "relationship": "father"}""";

        var coordinator = await kit.SendAsync(Coordinator, HttpMethod.Post, $"/members/{Child}/parents", body);
        Assert.That(coordinator.Status, Is.EqualTo(HttpStatusCode.Forbidden), coordinator.Body);
        Assert.That(coordinator.Detail, Is.EqualTo("Child previously revoked this parent; admin approval required"));
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", "status = 'active'"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));

        Assert.That((await kit.SendAsync(Admin, HttpMethod.Post, $"/members/{Child}/parents", body)).Status, Is.EqualTo(HttpStatusCode.Created));
    }

    [Test]
    public async Task The_candidate_lookup_follows_the_callers_reach()
    {
        var inClass = await kit.SendAsync(Coordinator, HttpMethod.Get, $"/members/{Child}/parents/candidate/{Parent}");
        Assert.That(inClass.Status, Is.EqualTo(HttpStatusCode.OK), inClass.Body);
        Assert.That(inClass.Json!["name"]!.GetValue<string>(), Is.EqualTo("B4b Parent"));

        var outside = await kit.SendAsync(Coordinator, HttpMethod.Get, $"/members/{Outsider}/parents/candidate/{Parent}");
        Assert.That(outside.Status, Is.EqualTo(HttpStatusCode.NotFound), outside.Body);
        Assert.That(outside.Detail, Is.EqualTo("Member not found"));
    }

    // ---- reject

    [Test]
    public async Task A_rejection_marks_every_row_of_the_member_and_writes_one_event()
    {
        await AddRegistrationAsync(Registrant, "Pending");
        var latest = await AddRegistrationAsync(Registrant, "Pending");

        var rejected = await kit.SendAsync(Admin, HttpMethod.Post, $"/registrations/{latest}/reject", """{"reason": "  too far  "}""");

        Assert.That(rejected.Status, Is.EqualTo(HttpStatusCode.OK), rejected.Body);
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", $"token = {Registrant} and status = 'Rejected' and status_reason = 'too far' and modified_by = {adminId} and status_date is not null and modified_at is not null"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'membership.registration_rejected'"), Is.EqualTo(1));
    }

    [Test]
    public async Task Concurrent_rejections_of_one_registrant_write_one_event()
    {
        var id = await AddRegistrationAsync(Registrant, "Pending");

        var replies = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => kit.SendAsync(Admin, HttpMethod.Post, $"/registrations/{id}/reject", """{"reason": "twice"}""")));

        Assert.That(replies.Count(r => r.Status == HttpStatusCode.OK), Is.EqualTo(1));
        Assert.That(replies.Count(r => r.Status == HttpStatusCode.Conflict), Is.EqualTo(7));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'membership.registration_rejected'"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_refused_rejection_changes_nothing_and_a_NUL_byte_in_the_reason_is_422_not_500()
    {
        var id = await AddRegistrationAsync(Registrant, "Pending");

        Assert.That((await kit.SendAsync(Admin, HttpMethod.Post, $"/registrations/{id}/reject", """{"reason": "  "}""")).Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That((await kit.SendAsync(Admin, HttpMethod.Post, $"/registrations/{id}/reject", """{"reason": "a\u0000b"}""")).Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That((await kit.SendAsync(Outsider, HttpMethod.Post, $"/registrations/{id}/reject", """{"reason": "x"}""")).Status, Is.EqualTo(HttpStatusCode.Forbidden));

        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", "status = 'Rejected'"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }

    [Test]
    public async Task A_gents_admin_who_may_read_registrations_but_not_reject_them_changes_nothing_for_either_gender()
    {
        var gents = await AddRegistrationAsync(Registrant, "Pending");
        var ladies = await AddRegistrationAsync(LadiesRegistrant, "Pending");

        foreach (var id in new[] { gents, ladies })
        {
            var reply = await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/registrations/{id}/reject", """{"reason": "x"}""");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Forbidden), reply.Body);
        }

        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", "status = 'Rejected'"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }

    // ---- cards

    [Test]
    public async Task The_subscriber_card_is_for_a_caller_reaching_every_class_and_a_coordinator_learns_nothing()
    {
        Assert.That((await kit.SendAsync(Admin, HttpMethod.Get, $"/subscribers/{Registrant}")).Status, Is.EqualTo(HttpStatusCode.OK));

        var coordinator = await kit.SendAsync(Coordinator, HttpMethod.Get, $"/subscribers/{Registrant}");

        Assert.That(coordinator.Status, Is.EqualTo(HttpStatusCode.NotFound), coordinator.Body);
        Assert.That(coordinator.Detail, Is.EqualTo("Person not found"));
    }

    private static async Task<int> AddInviteAsync(int childToken, int createdBy) =>
        await TestDatabase.ScalarAsync<int>(
            "insert into membership.user_guardians (child_token, status, source, code, expires_at, created_by, created_at) "
            + $"values ({childToken}, 'invited', 'link', md5(random()::text), now() + interval '7 days', {createdBy}, now()) returning id",
            TestDatabase.OwnerConnection);

    private static async Task<int> AddRegistrationAsync(int token, string status) =>
        await TestDatabase.ScalarAsync<int>(
            $"insert into membership.class_registrations (token, status, created_at) values ({token}, '{status}', now()) returning id",
            TestDatabase.OwnerConnection);
}
