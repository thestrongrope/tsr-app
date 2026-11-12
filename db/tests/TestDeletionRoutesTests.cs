using System.Net;
using System.Text.Json.Nodes;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The member's three routes and the administrator's list, raise, hold and confirmation-sent routes of the deletion queue, through the API as the limited role. Statuses and texts are PHP's
/// (routes/account_deletion.php, routes/admin_deletion_requests.php); the same cases run against PHP in the Hurl files of domains/identity/spec/tests.
/// </summary>
public sealed class TestDeletionRoutesTests
{
    private const string Pending = "Your account will be deleted within 60 days.";
    private const string NoPermission = "You do not have permission to do that";

    private static readonly string[] MemberKeys = ["id", "status", "requested_at", "expected_completion_days", "message"];
    private static readonly string[] CountKeys = ["pending", "awaiting_prize_delivery", "completed", "cancelled"];
    private static readonly string[] AdminKeys =
    [
        "id", "status", "source", "token", "member_name", "contact_email", "requested_at", "reason", "operator_note", "confirmation_sent_at", "completed_at", "cancelled_at", "handled_by",
        "handled_by_name", "member_zip", "member_mobile", "is_demo", "can_complete", "confirmation",
    ];

    private TestDeletionKit api = null!;

    [SetUp]
    public async Task SetUpAsync()
    {
        await TestDeletionKit.ResetAsync();
        api = new TestDeletionKit(new FakeFirebase());
        await TestDeletionKit.AddAdminAsync();
        await MembershipTestKit.AddMemberAsync(TestDeletionKit.Plain, name: "Plain Member");
    }

    [TearDown]
    public void TearDown() => api.Dispose();

    private Task<MembershipTestKit.Reply> MemberPostAsync(int token, string? json = "{}") => api.AsAsync(token, HttpMethod.Post, "/me/deletion-request", json);

    private Task<MembershipTestKit.Reply> AdminAsync(HttpMethod method, string path, string? json = null) => api.AsAsync(TestDeletionKit.Admin, method, path, json);

    // POST /me/deletion-request

    [Test]
    public async Task A_first_request_is_202_with_every_key_and_a_duplicate_is_200_with_the_same_request_and_one_event()
    {
        var first = await MemberPostAsync(TestDeletionKit.Plain, """{"reason":"  leaving  "}""");
        var second = await MemberPostAsync(TestDeletionKit.Plain);

        ReplyAssert.Expect(first, HttpStatusCode.Accepted);
        ReplyAssert.Expect(second, HttpStatusCode.OK);
        Assert.That(first.Json!.AsObject().Select(p => p.Key), Is.EquivalentTo(MemberKeys));
        Assert.That(first.Json!["status"]!.GetValue<string>(), Is.EqualTo("pending"));
        Assert.That(first.Json!["expected_completion_days"]!.GetValue<int>(), Is.EqualTo(60));
        Assert.That(first.Json!["message"]!.GetValue<string>(), Is.EqualTo(Pending));
        Assert.That(second.Json!["id"]!.GetValue<int>(), Is.EqualTo(first.Json!["id"]!.GetValue<int>()));
        Assert.That(await MembershipTestKit.CountAsync("identity.account_deletion_requests"), Is.EqualTo(1));
        Assert.That(await TestDeletionKit.EventsAsync("identity.deletion_requested"), Is.EqualTo(1));
        var row = (await TestDatabase.RowAsync("select reason, contact_name, contact_email, source::text as source from identity.account_deletion_requests"))!;
        Assert.That(row["reason"], Is.EqualTo("leaving"), "trimmed");
        Assert.That(row["contact_name"], Is.EqualTo("Plain Member"));
        Assert.That(row["contact_email"], Is.EqualTo("m924002@example.invalid"));
        Assert.That(row["source"], Is.EqualTo("app"));
        var payload = await TestDeletionKit.EventPayloadAsync("identity.deletion_requested");
        Assert.That(payload.ToJsonString(), Does.Not.Contain("@").And.Not.Contain("Plain Member").And.Not.Contain("leaving"));
    }

    [Test]
    public async Task Several_simultaneous_requests_make_one_request_and_one_event()
    {
        var replies = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => MemberPostAsync(TestDeletionKit.Plain)));

        Assert.That(replies.Count(r => r.Status == HttpStatusCode.Accepted), Is.EqualTo(1));
        Assert.That(replies.Count(r => r.Status == HttpStatusCode.OK), Is.EqualTo(7));
        Assert.That(await MembershipTestKit.CountAsync("identity.account_deletion_requests"), Is.EqualTo(1));
        Assert.That(await TestDeletionKit.EventsAsync("identity.deletion_requested"), Is.EqualTo(1));
    }

    [TestCase("""{"reason":5}""", "reason must be text")]
    [TestCase("""{"reason":["a"]}""", "reason must be text")]
    [TestCase("""{"reason":"a\u0000b"}""", "reason must be text")]
    public async Task A_reason_that_is_not_text_is_422_and_writes_nothing(string body, string detail)
    {
        ReplyAssert.Expect(await MemberPostAsync(TestDeletionKit.Plain, body), HttpStatusCode.UnprocessableEntity, detail);

        Assert.That(await MembershipTestKit.CountAsync("identity.account_deletion_requests"), Is.EqualTo(0));
    }

    [Test]
    public async Task A_reason_of_501_characters_is_422_and_500_is_accepted_and_blank_is_stored_as_null()
    {
        ReplyAssert.Expect(await MemberPostAsync(TestDeletionKit.Plain, "{\"reason\":\"" + new string('a', 501) + "\"}"), HttpStatusCode.UnprocessableEntity, "reason must be 500 characters or fewer");

        ReplyAssert.Expect(await MemberPostAsync(TestDeletionKit.Plain, "{\"reason\":\"   \"}"), HttpStatusCode.Accepted);
        Assert.That((await TestDatabase.RowAsync("select reason from identity.account_deletion_requests"))!["reason"], Is.Null);
    }

    [Test]
    public async Task A_500_character_reason_is_stored_whole()
    {
        ReplyAssert.Expect(await MemberPostAsync(TestDeletionKit.Plain, "{\"reason\":\"" + new string('b', 500) + "\"}"), HttpStatusCode.Accepted);

        Assert.That(await MembershipTestKit.CountAsync("identity.account_deletion_requests", "char_length(reason) = 500"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_body_that_is_not_json_is_422_not_a_500()
    {
        var reply = await MemberPostAsync(TestDeletionKit.Plain, "{not json");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), reply.Body);
    }

    [Test]
    public async Task A_guest_row_with_token_zero_is_403_registration_incomplete_on_all_three_member_routes_because_every_registered_member_holds_account_delete()
    {
        await TestDatabase.ExecuteAsync("insert into identity.users (token, email, firebase_uid) values (0, 'm0@example.invalid', 'uid-0')");

        foreach (var method in new[] { HttpMethod.Post, HttpMethod.Get, HttpMethod.Delete })
        {
            ReplyAssert.Expect(await api.AsAsync(0, method, "/me/deletion-request", method == HttpMethod.Post ? "{}" : null), HttpStatusCode.Forbidden, "Registration incomplete");
        }

        Assert.That(await MembershipTestKit.CountAsync("identity.account_deletion_requests"), Is.EqualTo(0));
    }

    // GET /me/deletion-request

    [Test]
    public async Task Reading_with_no_request_is_the_same_shape_with_status_none_and_nulls()
    {
        var reply = await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Get, "/me/deletion-request");

        ReplyAssert.Expect(reply, HttpStatusCode.OK);
        Assert.That(reply.Json!["id"], Is.Null);
        Assert.That(reply.Json!["status"]!.GetValue<string>(), Is.EqualTo("none"));
        Assert.That(reply.Json!["requested_at"], Is.Null);
        Assert.That(reply.Json!["message"], Is.Null);
        Assert.That(reply.Json!["expected_completion_days"]!.GetValue<int>(), Is.EqualTo(60));
        Assert.That(reply.Json!.AsObject(), Has.Count.EqualTo(5));
    }

    [Test]
    public async Task A_held_request_shows_the_operators_note_or_the_prize_sentence_when_there_is_none()
    {
        await MemberPostAsync(TestDeletionKit.Plain);
        var id = await TestDatabase.ScalarAsync<int>("select id from identity.account_deletion_requests", TestDatabase.OwnerConnection);

        ReplyAssert.Expect(await AdminAsync(HttpMethod.Post, $"/admin/deletion-requests/{id}/hold", """{"note":"Prize on its way"}"""), HttpStatusCode.OK);
        var withNote = await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Get, "/me/deletion-request");
        await AdminAsync(HttpMethod.Post, $"/admin/deletion-requests/{id}/hold", """{"note":"  "}""");
        var withoutNote = await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Get, "/me/deletion-request");

        Assert.That(withNote.Json!["status"]!.GetValue<string>(), Is.EqualTo("awaiting_prize_delivery"));
        Assert.That(withNote.Json!["message"]!.GetValue<string>(), Is.EqualTo("Prize on its way"));
        Assert.That(withoutNote.Json!["message"]!.GetValue<string>(), Is.EqualTo("We are still delivering a prize to you. Your account will be deleted once that is complete."));
    }

    // DELETE /me/deletion-request

    [Test]
    public async Task Cancelling_is_200_status_cancelled_with_one_event_and_the_member_can_ask_again()
    {
        await MemberPostAsync(TestDeletionKit.Plain);

        var reply = await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Delete, "/me/deletion-request");

        ReplyAssert.Expect(reply, HttpStatusCode.OK);
        Assert.That(reply.Json!["status"]!.GetValue<string>(), Is.EqualTo("cancelled"));
        Assert.That(await TestDeletionKit.EventsAsync("identity.deletion_cancelled"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("identity.account_deletion_requests", "status = 'cancelled' and cancelled_at is not null"), Is.EqualTo(1));
        Assert.That((await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Get, "/me/deletion-request")).Json!["status"]!.GetValue<string>(), Is.EqualTo("none"));
        ReplyAssert.Expect(await MemberPostAsync(TestDeletionKit.Plain), HttpStatusCode.Accepted);
    }

    [Test]
    public async Task Cancelling_with_nothing_live_is_404_and_after_a_completion_is_409_and_neither_writes_an_event()
    {
        ReplyAssert.Expect(await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Delete, "/me/deletion-request"), HttpStatusCode.NotFound, "No pending deletion request");

        await TestDeletionKit.AddRequestAsync(TestDeletionKit.Plain, "completed", completedAt: "now() - interval '5 hours'");
        ReplyAssert.Expect(
            await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Delete, "/me/deletion-request"), HttpStatusCode.Conflict, "This account has already been deleted and cannot be restored");
        Assert.That(await TestDeletionKit.EventsAsync("identity.deletion_cancelled"), Is.EqualTo(0));
    }

    [Test]
    public async Task Several_simultaneous_cancels_cancel_once_and_write_one_event()
    {
        await MemberPostAsync(TestDeletionKit.Plain);

        var replies = await Task.WhenAll(Enumerable.Range(0, 6).Select(_ => api.AsAsync(TestDeletionKit.Plain, HttpMethod.Delete, "/me/deletion-request")));

        Assert.That(replies.Count(r => r.Status == HttpStatusCode.OK), Is.EqualTo(1));
        Assert.That(replies.Count(r => r.Status == HttpStatusCode.NotFound), Is.EqualTo(5));
        Assert.That(await TestDeletionKit.EventsAsync("identity.deletion_cancelled"), Is.EqualTo(1));
    }

    // The gate in the caller middleware

    [Test]
    public async Task A_member_with_a_live_request_can_read_and_cancel_it_but_is_refused_elsewhere_with_PHPs_body()
    {
        await MemberPostAsync(TestDeletionKit.Plain);

        ReplyAssert.Expect(await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Get, "/me/deletion-request"), HttpStatusCode.OK);
        ReplyAssert.Expect(await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Get, "/me"), HttpStatusCode.OK);
        foreach (var (method, path) in new[]
        {
            (HttpMethod.Post, "/feedback"), (HttpMethod.Patch, "/me"), (HttpMethod.Post, "/devices"), (HttpMethod.Get, "/admin/deletion-requests"), (HttpMethod.Post, "/admin/deletion-requests"),
        })
        {
            var refused = await api.AsAsync(TestDeletionKit.Plain, method, path, method == HttpMethod.Get ? null : "{}");
            Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.Forbidden), method + " " + path + " " + refused.Body);
            Assert.That(refused.Json!["detail"]!.GetValue<string>(), Is.EqualTo("Account deletion pending"));
            Assert.That(refused.Json!["deletion_status"]!.GetValue<string>(), Is.EqualTo("pending"));
        }

        ReplyAssert.Expect(await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Delete, "/me/deletion-request"), HttpStatusCode.OK);
        Assert.That((await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Post, "/feedback", """{"clientId":"c-1","text":"salaam"}""")).Status, Is.EqualTo(HttpStatusCode.Created), "cancelled: unblocked");
    }

    [Test]
    public async Task An_administrator_with_a_live_request_of_their_own_is_refused_on_every_admin_route_including_complete()
    {
        await TestDeletionKit.AddRequestAsync(TestDeletionKit.Admin);

        foreach (var path in new[] { "/admin/deletion-requests/1/hold", "/admin/deletion-requests/1/confirmation-sent", "/admin/deletion-requests/1/complete" })
        {
            var refused = await AdminAsync(HttpMethod.Post, path);
            Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.Forbidden), path);
            Assert.That(refused.Detail, Is.EqualTo("Account deletion pending"));
        }
    }

    // GET /admin/deletion-requests

    [Test]
    public async Task The_queue_has_the_four_counts_every_key_and_newest_first_and_a_filter_that_is_not_a_status_is_no_filter()
    {
        var older = await TestDeletionKit.AddRequestAsync(924031, confirmed: false);
        var newer = await TestDeletionKit.AddRequestAsync(924032, "cancelled");

        var all = await AdminAsync(HttpMethod.Get, "/admin/deletion-requests");
        var cancelled = await AdminAsync(HttpMethod.Get, "/admin/deletion-requests?status=cancelled");
        var junk = await AdminAsync(HttpMethod.Get, "/admin/deletion-requests?status=bogus");

        ReplyAssert.Expect(all, HttpStatusCode.OK);
        Assert.That(all.Json!["counts"]!.AsObject().Select(p => p.Key), Is.EqualTo(CountKeys));
        Assert.That(all.Json!["counts"]!["pending"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(all.Json!["counts"]!["cancelled"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(all.Json!["counts"]!["completed"]!.GetValue<int>(), Is.EqualTo(0));
        Assert.That(all.Json!["requests"]!.AsArray().Select(r => r!["id"]!.GetValue<int>()), Is.EqualTo(new[] { newer, older }));
        Assert.That(cancelled.Json!["requests"]!.AsArray(), Has.Count.EqualTo(1));
        Assert.That(junk.Json!["requests"]!.AsArray(), Has.Count.EqualTo(2));
        var view = all.Json!["requests"]!.AsArray()[1]!.AsObject();
        Assert.That(view.Select(p => p.Key), Is.EquivalentTo(AdminKeys));
        Assert.That(view["confirmation"]!["subject"]!.GetValue<string>(), Is.EqualTo("Your The Strong Rope account has been deleted"));
        Assert.That(view["can_complete"]!.GetValue<bool>(), Is.False, "no confirmation recorded");
    }

    [Test]
    public async Task Zip_and_mobile_are_shown_only_for_a_held_request_and_never_to_a_caller_without_the_permission()
    {
        await TestDeletionKit.AddFullMemberAsync(TestDeletionKit.Target, TestDeletionKit.TargetMobile, [TestDeletionKit.TargetDevice]);
        var id = await TestDeletionKit.AddRequestAsync(TestDeletionKit.Target);

        var pending = (await AdminAsync(HttpMethod.Get, "/admin/deletion-requests")).Json!["requests"]![0]!;
        await AdminAsync(HttpMethod.Post, $"/admin/deletion-requests/{id}/hold");
        var held = (await AdminAsync(HttpMethod.Get, "/admin/deletion-requests")).Json!["requests"]![0]!;
        var stranger = await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Get, "/admin/deletion-requests");

        Assert.That(pending["member_zip"], Is.Null);
        Assert.That(pending["member_mobile"], Is.Null);
        Assert.That(held["member_zip"]!.GetValue<string>(), Is.EqualTo("12345"));
        Assert.That(held["member_mobile"]!.GetValue<string>(), Is.EqualTo(TestDeletionKit.TargetMobile));
        Assert.That(held["member_name"]!.GetValue<string>(), Is.EqualTo("Real Name 924010"));
        ReplyAssert.Expect(stranger, HttpStatusCode.Forbidden, NoPermission);
        Assert.That(stranger.Body, Does.Not.Contain("12345"));
    }

    [Test]
    public async Task A_demo_member_is_marked_and_cannot_be_completed()
    {
        await TestDatabase.ExecuteAsync("insert into identity.users (token, email) values (924060, 'reviewer@demo.invalid')");
        await TestDeletionKit.AddRequestAsync(924060);

        var view = (await AdminAsync(HttpMethod.Get, "/admin/deletion-requests")).Json!["requests"]![0]!;

        Assert.That(view["is_demo"]!.GetValue<bool>(), Is.True);
        Assert.That(view["can_complete"]!.GetValue<bool>(), Is.False);
    }

    // POST /admin/deletion-requests

    [Test]
    public async Task Raising_by_email_is_201_created_true_then_200_created_false_with_one_event_and_source_web_in_any_case()
    {
        await TestDeletionKit.AddFullMemberAsync(TestDeletionKit.Target, TestDeletionKit.TargetMobile, []);

        var first = await AdminAsync(HttpMethod.Post, "/admin/deletion-requests", """{"email":"  M924010@Example.Invalid "}""");
        var second = await AdminAsync(HttpMethod.Post, "/admin/deletion-requests", """{"email":"m924010@example.invalid"}""");

        ReplyAssert.Expect(first, HttpStatusCode.Created);
        ReplyAssert.Expect(second, HttpStatusCode.OK);
        Assert.That(first.Json!["created"]!.GetValue<bool>(), Is.True);
        Assert.That(second.Json!["created"]!.GetValue<bool>(), Is.False);
        Assert.That(first.Json!["request"]!["source"]!.GetValue<string>(), Is.EqualTo("web"));
        Assert.That(first.Json!["request"]!["reason"]!.GetValue<string>(), Is.EqualTo("Raised by an administrator from an emailed request."));
        Assert.That(await TestDeletionKit.EventsAsync("identity.deletion_requested"), Is.EqualTo(1));
        Assert.That((await TestDeletionKit.EventPayloadAsync("identity.deletion_requested"))["source"]!.GetValue<string>(), Is.EqualTo("web"));
    }

    [TestCase("""{"email":"nobody@example.invalid"}""", HttpStatusCode.NotFound, "No account matches nobody@example.invalid")]
    [TestCase("""{"email":"guest@example.invalid"}""", HttpStatusCode.NotFound, "No account matches guest@example.invalid")]
    [TestCase("""{"email":"a\u0000b@example.invalid"}""", HttpStatusCode.NotFound, "No account matches a\0b@example.invalid")]
    [TestCase("""{"email":"   "}""", HttpStatusCode.UnprocessableEntity, "Enter the email address the request came from")]
    [TestCase("""{"email":7}""", HttpStatusCode.UnprocessableEntity, "Enter the email address the request came from")]
    [TestCase("""{}""", HttpStatusCode.UnprocessableEntity, "Enter the email address the request came from")]
    public async Task Raising_for_no_member_or_a_bad_email_is_refused_and_writes_nothing(string body, HttpStatusCode status, string detail)
    {
        await TestDatabase.ExecuteAsync("insert into identity.users (token, email) values (0, 'guest@example.invalid')");

        ReplyAssert.Expect(await AdminAsync(HttpMethod.Post, "/admin/deletion-requests", body), status, detail);

        Assert.That(await MembershipTestKit.CountAsync("identity.account_deletion_requests"), Is.EqualTo(0));
        Assert.That(await TestDeletionKit.EventsAsync("identity.deletion_requested"), Is.EqualTo(0));
    }

    [Test]
    public async Task Raising_without_the_permission_is_403_before_the_email_is_looked_up()
    {
        var hit = await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Post, "/admin/deletion-requests", """{"email":"m924002@example.invalid"}""");
        var miss = await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Post, "/admin/deletion-requests", """{"email":"nobody@example.invalid"}""");

        ReplyAssert.Expect(hit, HttpStatusCode.Forbidden, NoPermission);
        ReplyAssert.Expect(miss, HttpStatusCode.Forbidden, NoPermission);
    }

    // POST .../hold

    [Test]
    public async Task Holding_a_pending_request_writes_one_event_and_holding_again_replaces_the_note_without_one()
    {
        await TestDeletionKit.AddFullMemberAsync(TestDeletionKit.Target, TestDeletionKit.TargetMobile, []);
        var id = await TestDeletionKit.AddRequestAsync(TestDeletionKit.Target);

        var first = await AdminAsync(HttpMethod.Post, $"/admin/deletion-requests/{id}/hold", """{"note":" first "}""");
        var second = await AdminAsync(HttpMethod.Post, $"/admin/deletion-requests/{id}/hold", """{"note":"second"}""");

        ReplyAssert.Expect(first, HttpStatusCode.OK);
        Assert.That(first.Json!["request"]!["status"]!.GetValue<string>(), Is.EqualTo("awaiting_prize_delivery"));
        Assert.That(first.Json!["request"]!["operator_note"]!.GetValue<string>(), Is.EqualTo("first"));
        Assert.That(first.Json!["request"]!["handled_by"]!.GetValue<int>(), Is.EqualTo(TestDeletionKit.Admin));
        Assert.That(second.Json!["request"]!["operator_note"]!.GetValue<string>(), Is.EqualTo("second"));
        Assert.That(await TestDeletionKit.EventsAsync("identity.deletion_held"), Is.EqualTo(1));
    }

    [Test]
    public async Task Holding_refusals_are_PHPs_and_change_nothing()
    {
        var done = await TestDeletionKit.AddRequestAsync(924040, "completed", completedAt: "now() - interval '5 hours'");
        var live = await TestDeletionKit.AddRequestAsync(924041);
        var before = await TestDeletionKit.WholeDatabaseAsync();

        ReplyAssert.Expect(await AdminAsync(HttpMethod.Post, $"/admin/deletion-requests/{done}/hold"), HttpStatusCode.Conflict, "This request is no longer live");
        ReplyAssert.Expect(await AdminAsync(HttpMethod.Post, "/admin/deletion-requests/99999999/hold"), HttpStatusCode.NotFound, "Deletion request not found");
        ReplyAssert.Expect(await AdminAsync(HttpMethod.Post, "/admin/deletion-requests/abc/hold"), HttpStatusCode.NotFound, "Deletion request not found");
        ReplyAssert.Expect(await AdminAsync(HttpMethod.Post, $"/admin/deletion-requests/{live}/hold", """{"note":5}"""), HttpStatusCode.UnprocessableEntity, "note must be text");
        ReplyAssert.Expect(await AdminAsync(HttpMethod.Post, $"/admin/deletion-requests/{live}/hold", "{\"note\":\"" + new string('n', 501) + "\"}"), HttpStatusCode.UnprocessableEntity, "note must be 500 characters or fewer");
        ReplyAssert.Expect(await AdminAsync(HttpMethod.Post, $"/admin/deletion-requests/{live}/hold", """{"note":"a\u0000b"}"""), HttpStatusCode.UnprocessableEntity, "note must be text");

        Assert.That(await TestDeletionKit.WholeDatabaseAsync(), Is.EqualTo(before));
    }

    [Test]
    public async Task Hold_and_confirmation_need_the_permission_and_do_not_reveal_whether_the_id_exists()
    {
        var id = await TestDeletionKit.AddRequestAsync(924041);

        foreach (var path in new[] { $"/admin/deletion-requests/{id}/hold", "/admin/deletion-requests/99999999/hold", $"/admin/deletion-requests/{id}/confirmation-sent", "/admin/deletion-requests/99999999/confirmation-sent" })
        {
            ReplyAssert.Expect(await api.AsAsync(TestDeletionKit.Plain, HttpMethod.Post, path, "{}"), HttpStatusCode.Forbidden, NoPermission);
        }
    }

    // POST .../confirmation-sent

    [Test]
    public async Task The_confirmation_is_stamped_once_the_first_time_is_kept_no_event_is_written_and_the_text_goes_away()
    {
        var id = await TestDeletionKit.AddRequestAsync(924041, confirmed: false);

        var first = await AdminAsync(HttpMethod.Post, $"/admin/deletion-requests/{id}/confirmation-sent");
        var stamp = (await TestDatabase.RowAsync($"select confirmation_sent_at::text as t from identity.account_deletion_requests where id = {id}"))!["t"];
        await Task.Delay(1100);
        var second = await AdminAsync(HttpMethod.Post, $"/admin/deletion-requests/{id}/confirmation-sent");

        ReplyAssert.Expect(first, HttpStatusCode.OK);
        ReplyAssert.Expect(second, HttpStatusCode.OK);
        Assert.That(first.Json!["request"]!["confirmation"], Is.Null);
        Assert.That(first.Json!["request"]!["can_complete"]!.GetValue<bool>(), Is.True);
        Assert.That(first.Json!["request"]!["handled_by"]!.GetValue<int>(), Is.EqualTo(TestDeletionKit.Admin));
        Assert.That((await TestDatabase.RowAsync($"select confirmation_sent_at::text as t from identity.account_deletion_requests where id = {id}"))!["t"], Is.EqualTo(stamp));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }

    [Test]
    public async Task A_settled_request_cannot_take_a_confirmation_409_and_an_unknown_one_is_404()
    {
        var cancelled = await TestDeletionKit.AddRequestAsync(924042, "cancelled", confirmed: false);

        ReplyAssert.Expect(await AdminAsync(HttpMethod.Post, $"/admin/deletion-requests/{cancelled}/confirmation-sent"), HttpStatusCode.Conflict, "This request is settled and cannot take a confirmation");
        ReplyAssert.Expect(await AdminAsync(HttpMethod.Post, "/admin/deletion-requests/99999999/confirmation-sent"), HttpStatusCode.NotFound, "Deletion request not found");
        Assert.That(await MembershipTestKit.CountAsync("identity.account_deletion_requests", "confirmation_sent_at is not null"), Is.EqualTo(0));
    }
}
