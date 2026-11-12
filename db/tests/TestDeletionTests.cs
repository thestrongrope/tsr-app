using System.Net;
using NUnit.Framework;
using Tsr.Identity.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// POST /admin/deletion-requests/{id}/complete, the irreversible route, through the API as the limited role (tsr_app) with the Firebase boundary faked (it cannot be called from a test).
/// Every erased column is PHP's (models/accountdeletion.php anonymisationMap and registrationAnonymisationMap, as far as this schema has them); no row of another member changes; the whole
/// completion is one transaction; the Firebase call comes BEFORE it, as PHP does (the task text said after the commit; PHP's own doc block says before, and so do these tests).
/// </summary>
public sealed class TestDeletionTests
{
    private FakeFirebase firebase = null!;
    private TestDeletionKit api = null!;
    private static readonly string[] BothUids = ["uid-924010", "uid-second"];

    private int adminId;

    [SetUp]
    public async Task SetUpAsync()
    {
        await TestDeletionKit.ResetAsync();
        firebase = new FakeFirebase();
        api = new TestDeletionKit(firebase);
        adminId = await TestDeletionKit.AddAdminAsync();
    }

    [TearDown]
    public void TearDown() => api.Dispose();

    private static async Task<int> AddTargetWithRequestAsync()
    {
        await TestDeletionKit.AddFullMemberAsync(TestDeletionKit.Target, TestDeletionKit.TargetMobile, [TestDeletionKit.TargetDevice, TestDeletionKit.TargetDevice2]);
        return await TestDeletionKit.AddRequestAsync(TestDeletionKit.Target);
    }

    [Test]
    public async Task A_completion_erases_what_PHP_erases_and_keeps_what_PHP_keeps()
    {
        var requestId = await AddTargetWithRequestAsync();

        var reply = await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        ReplyAssert.Expect(reply, HttpStatusCode.OK);
        Assert.That(reply.Json!["request"]!["status"]!.GetValue<string>(), Is.EqualTo("completed"));
        var user = (await TestDatabase.RowAsync($"select * from identity.users where token = {TestDeletionKit.Target}"))!;
        Assert.That(user["email"], Is.EqualTo("deleted-924010@deleted.invalid"));
        foreach (var column in new[] { "firebase_uid", "lastdevice", "device", "platform", "version", "lastloginip" })
        {
            Assert.That(user[column], Is.Null, column);
        }

        Assert.That(user["provider"], Is.EqualTo("firebase"), "provider stays");
        Assert.That(user["createdon"], Is.Not.Null, "createdon stays");
        Assert.That(user["lastlogin"], Is.Not.Null, "lastlogin stays");
        var profile = (await TestDatabase.RowAsync("select * from membership.member_profiles where user_id = (select id from identity.users where token = " + TestDeletionKit.Target + ")"))!;
        Assert.That(profile["name"], Is.EqualTo("Deleted member"));
        foreach (var column in new[] { "first_name", "last_name", "picture", "gender", "age_range", "country", "state", "city", "zip" })
        {
            Assert.That(profile[column], Is.Null, column);
        }

        Assert.That(profile["mobile"], Is.EqualTo(string.Empty));
        Assert.That(profile["language"], Is.EqualTo("0"));
        Assert.That(profile["sendupdates"], Is.EqualTo("N"));
        Assert.That(profile["unsubscribe"], Is.EqualTo("Y"));
    }

    [Test]
    public async Task A_completion_clears_the_class_request_data_and_keeps_the_class_record()
    {
        var requestId = await AddTargetWithRequestAsync();

        await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        var reg = (await TestDatabase.RowAsync($"select * from membership.class_registrations where token = {TestDeletionKit.Target}"))!;
        foreach (var column in new[]
        {
            "residence_location", "work_location", "preferred_location", "birth_year", "profession", "islamic_study_years", "interests", "other_interests", "education", "field_of_study",
            "field_of_study_other", "professional_courses", "professional_courses_other", "occupation_type", "field_of_work", "years_experience", "role_level", "linkedin_url", "status_reason",
        })
        {
            Assert.That(reg[column], Is.Null, column);
        }

        Assert.That(reg["for_classid"], Is.EqualTo("98400"));
        Assert.That(reg["status"], Is.EqualTo("Accepted"));
        Assert.That(reg["token"], Is.EqualTo($"{TestDeletionKit.Target}"));
    }

    [Test]
    public async Task A_completion_deletes_the_devices_and_feedback_and_blanks_the_recipient_of_the_queued_messages_but_keeps_those_rows()
    {
        var requestId = await AddTargetWithRequestAsync();

        await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        Assert.That(await MembershipTestKit.CountAsync("notifications.user_devices", "token = " + TestDeletionKit.Target), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.feedback", "message like 'feedback of 924010'"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages"), Is.EqualTo(3), "the rows stay");
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "recipient = '[deleted]'"), Is.EqualTo(3), "mobile and both device ids are redacted");
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "recipient in ('" + TestDeletionKit.TargetMobile + "', '" + TestDeletionKit.TargetDevice + "')"), Is.EqualTo(0));
    }

    [Test]
    public async Task A_member_with_more_than_1000_devices_is_completed_and_a_queued_push_to_the_last_device_is_redacted_REVIEW_S1()
    {
        var requestId = await AddTargetWithRequestAsync();
        await TestDatabase.ExecuteAsync(
            $"""
            insert into notifications.user_devices (token, device_id) select {TestDeletionKit.Target}, 'bulk-924010-' || n from generate_series(1, 1200) as n;
            insert into platform.outbound_messages (channel, recipient, payload, dedupe_key) values ('push', 'bulk-924010-1200', '[]', 'k-bulk-last');
            """);

        var reply = await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        ReplyAssert.Expect(reply, HttpStatusCode.OK);
        Assert.That(await MembershipTestKit.CountAsync("notifications.user_devices", "token = " + TestDeletionKit.Target), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "dedupe_key = 'k-bulk-last' and recipient = '[deleted]'"), Is.EqualTo(1),
            "PHP redacts every device of the member, with no bound");
    }

    [Test]
    public async Task A_completion_touches_no_row_of_another_member_with_the_same_device_id_and_a_feedback_of_their_own()
    {
        var requestId = await AddTargetWithRequestAsync();
        var bystanderId = await TestDeletionKit.AddFullMemberAsync(TestDeletionKit.Bystander, TestDeletionKit.BystanderMobile, [TestDeletionKit.TargetDevice]);
        await TestDatabase.ExecuteAsync(
            $"update identity.users set email = 'm924010x@example.invalid' where token = {TestDeletionKit.Bystander}; "
            + $"insert into identity.users (token, email) values ({TestDeletionKit.Bystander}, 'm924010@example.net')");
        var before = await TestDeletionKit.SnapshotAsync(TestDeletionKit.Bystander, bystanderId, TestDeletionKit.BystanderMobile);

        ReplyAssert.Expect(await api.CompleteAsync(TestDeletionKit.Admin, requestId), HttpStatusCode.OK);

        Assert.That(await TestDeletionKit.SnapshotAsync(TestDeletionKit.Bystander, bystanderId, TestDeletionKit.BystanderMobile), Is.EqualTo(before));
        Assert.That(await MembershipTestKit.CountAsync("notifications.user_devices", "token = " + TestDeletionKit.Bystander + " and device_id = '" + TestDeletionKit.TargetDevice + "'"), Is.EqualTo(1),
            "the device row of the other member is kept even though it carries the same device id");
    }

    [Test]
    public async Task A_queued_push_message_of_another_member_to_the_same_device_id_IS_redacted_because_PHP_matches_by_value_DECISION()
    {
        var requestId = await AddTargetWithRequestAsync();
        await TestDeletionKit.AddFullMemberAsync(TestDeletionKit.Bystander, TestDeletionKit.BystanderMobile, [TestDeletionKit.TargetDevice]);

        await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "dedupe_key = 'k-924020-device-924010-a'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "dedupe_key = 'k-924020-device-924010-a' and recipient = '[deleted]'"), Is.EqualTo(1),
            "PHP's redactQueuedMessages matches the recipient by value; a device id shared by two members loses both members' queued rows. Copied, recorded as a decision.");
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "recipient = '" + TestDeletionKit.BystanderMobile + "'"), Is.EqualTo(1), "their own mobile row is untouched");
    }

    [Test]
    public async Task A_queued_message_whose_recipient_differs_only_in_letter_case_is_redacted_and_a_similar_recipient_is_not_CASE_C1()
    {
        var requestId = await AddTargetWithRequestAsync();
        await TestDatabase.ExecuteAsync(
            """
            insert into platform.outbound_messages (channel, recipient, payload, dedupe_key) values
              ('push', 'DEVICE-924010-A', '[]', 'k-case-upper'),
              ('push', 'device-924010-ab', '[]', 'k-case-lookalike')
            """);

        ReplyAssert.Expect(await api.CompleteAsync(TestDeletionKit.Admin, requestId), HttpStatusCode.OK);

        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "dedupe_key = 'k-case-upper' and recipient = '[deleted]'"), Is.EqualTo(1),
            "MariaDB compares the recipient without regard to letter case, so the upper-case copy of the device id is redacted too");
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "dedupe_key = 'k-case-lookalike' and recipient = 'device-924010-ab'"), Is.EqualTo(1), "a recipient that only looks similar is kept");
    }

    [Test]
    public async Task A_token_held_by_two_user_rows_has_both_anonymised_and_both_Firebase_accounts_deleted()
    {
        var requestId = await AddTargetWithRequestAsync();
        await TestDatabase.ExecuteAsync($"insert into identity.users (token, email, firebase_uid) values ({TestDeletionKit.Target}, 'second-924010@example.invalid', 'uid-second')");

        ReplyAssert.Expect(await api.CompleteAsync(TestDeletionKit.Admin, requestId), HttpStatusCode.OK);

        Assert.That(await MembershipTestKit.CountAsync("identity.users", "token = 924010 and email = 'deleted-924010@deleted.invalid' and firebase_uid is null"), Is.EqualTo(2), "every row anonymised");
        Assert.That(firebase.Calls.Select(c => c.Uid), Is.EqualTo(BothUids), "every row's account, in id order");
    }

    [Test]
    public async Task A_row_with_no_stored_uid_among_several_is_looked_up_by_its_own_email_beside_the_others_uids()
    {
        var requestId = await AddTargetWithRequestAsync();
        await TestDatabase.ExecuteAsync($"insert into identity.users (token, email) values ({TestDeletionKit.Target}, 'noid-924010@example.invalid')");

        ReplyAssert.Expect(await api.CompleteAsync(TestDeletionKit.Admin, requestId), HttpStatusCode.OK);

        Assert.That(firebase.Calls, Is.EqualTo(new[] { ((string?)"uid-924010", (string?)"m924010@example.invalid"), (null, "noid-924010@example.invalid") }));
    }

    [Test]
    public async Task A_Firebase_failure_on_the_second_row_is_409_writes_nothing_and_a_retry_then_completes()
    {
        var requestId = await AddTargetWithRequestAsync();
        await TestDatabase.ExecuteAsync($"insert into identity.users (token, email, firebase_uid) values ({TestDeletionKit.Target}, 'second-924010@example.invalid', 'uid-second')");
        var before = await TestDeletionKit.WholeDatabaseAsync();
        firebase.FailOnUid = "uid-second";

        var reply = await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        ReplyAssert.Expect(reply, HttpStatusCode.Conflict, "Firebase could not be reached (HttpRequestException).");
        Assert.That(await TestDeletionKit.WholeDatabaseAsync(), Is.EqualTo(before));
        Assert.That(firebase.Calls.Select(c => c.Uid), Is.EqualTo(BothUids), "the first account was already deleted in this attempt");

        api.Dispose();
        var retryFirebase = new FakeFirebase();
        api = new TestDeletionKit(retryFirebase);
        ReplyAssert.Expect(await api.CompleteAsync(TestDeletionKit.Admin, requestId), HttpStatusCode.OK);
        Assert.That(retryFirebase.Calls.Select(c => c.Uid), Is.EqualTo(BothUids), "a retry asks about both again; an account Firebase no longer knows counts as done");
    }

    [Test]
    public async Task A_token_held_by_more_than_20_user_rows_is_refused_409_before_any_Firebase_call_and_nothing_is_written()
    {
        var requestId = await AddTargetWithRequestAsync();
        await TestDatabase.ExecuteAsync(
            $"insert into identity.users (token, email, firebase_uid) select {TestDeletionKit.Target}, 'many-' || g || '@example.invalid', 'uid-many-' || g from generate_series(1, 20) g");
        var before = await TestDeletionKit.WholeDatabaseAsync();

        var reply = await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        ReplyAssert.Expect(reply, HttpStatusCode.Conflict, $"Deletion request {requestId} names token 924010, which has more than 20 user rows; at most 20 can be completed here. Remove the extra rows first.");
        Assert.That(firebase.Calls, Is.Empty);
        Assert.That(await TestDeletionKit.WholeDatabaseAsync(), Is.EqualTo(before));
    }

    [Test]
    public async Task A_token_held_by_two_user_rows_has_the_feedback_of_both_erased()
    {
        var requestId = await AddTargetWithRequestAsync();
        await TestDatabase.ExecuteAsync(
            $"""
            with u as (insert into identity.users (token, email, firebase_uid) values ({TestDeletionKit.Target}, 'second-924010@example.invalid', 'uid-second') returning id)
            insert into platform.feedback (user_id, client_id, message) select id, 'c-second', 'feedback of the second row' from u
            """);

        ReplyAssert.Expect(await api.CompleteAsync(TestDeletionKit.Admin, requestId), HttpStatusCode.OK);

        Assert.That(await MembershipTestKit.CountAsync("platform.feedback", "message like 'feedback of%924010' or message = 'feedback of the second row'"), Is.EqualTo(0));
    }

    [Test]
    public async Task A_row_with_no_stored_uid_is_passed_to_Firebase_by_email_alone_and_Firebase_may_delete_whichever_account_owns_it_FINDING_2()
    {
        await TestDatabase.ExecuteAsync($"insert into identity.users (token, email) values ({TestDeletionKit.Target}, 'owner@example.invalid')");
        var requestId = await TestDeletionKit.AddRequestAsync(TestDeletionKit.Target);

        ReplyAssert.Expect(await api.CompleteAsync(TestDeletionKit.Admin, requestId), HttpStatusCode.OK);

        Assert.That(firebase.Calls, Is.EqualTo(new[] { ((string?)null, (string?)"owner@example.invalid") }), "uid null, email given: the real client then looks the account up by that address (PHP's getUserByEmail)");
    }

    [Test]
    public async Task Firebase_is_called_before_the_transaction_with_the_database_still_whole_as_PHP_does()
    {
        var requestId = await AddTargetWithRequestAsync();
        string? status = null;
        long devices = -1;
        string? email = null;
        firebase.Inside = async () =>
        {
            status = (await TestDatabase.RowAsync($"select status::text as s from identity.account_deletion_requests where id = {requestId}"))!["s"];
            devices = await MembershipTestKit.CountAsync("notifications.user_devices", "token = " + TestDeletionKit.Target);
            email = (await TestDatabase.RowAsync($"select email from identity.users where token = {TestDeletionKit.Target}"))!["email"];
        };

        await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        Assert.That(status, Is.EqualTo("pending"));
        Assert.That(devices, Is.EqualTo(2));
        Assert.That(email, Is.EqualTo("m924010@example.invalid"));
    }

    [Test]
    public async Task A_Firebase_failure_is_409_with_its_message_and_leaves_the_database_and_the_outbox_untouched()
    {
        var requestId = await AddTargetWithRequestAsync();
        var before = await TestDeletionKit.WholeDatabaseAsync();
        firebase.FailWith = "Firebase could not be reached (HttpRequestException).";

        var reply = await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        ReplyAssert.Expect(reply, HttpStatusCode.Conflict, "Firebase could not be reached (HttpRequestException).");
        Assert.That(await TestDeletionKit.WholeDatabaseAsync(), Is.EqualTo(before));
    }

    [Test]
    public async Task Without_a_service_account_every_completion_is_refused_409_before_the_database_is_touched()
    {
        api.Dispose();
        api = new TestDeletionKit(new UnconfiguredFirebaseAccounts());
        var requestId = await AddTargetWithRequestAsync();
        var before = await TestDeletionKit.WholeDatabaseAsync();

        var reply = await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        ReplyAssert.Expect(reply, HttpStatusCode.Conflict, UnconfiguredFirebaseAccounts.Message);
        Assert.That(await TestDeletionKit.WholeDatabaseAsync(), Is.EqualTo(before));
    }

    [Test]
    public async Task A_failure_after_the_devices_were_deleted_and_the_queue_redacted_rolls_the_whole_completion_back()
    {
        api.Dispose();
        api = new TestDeletionKit(firebase, new FailingErasure());
        var requestId = await AddTargetWithRequestAsync();
        var before = await TestDeletionKit.WholeDatabaseAsync();

        var reply = await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.InternalServerError), "PHP answers 409 carrying the exception text; here a bug is a 500 (the test host runs in Development and so shows the developer page; a Production host shows no text)");
        Assert.That(await TestDeletionKit.WholeDatabaseAsync(), Is.EqualTo(before), "devices, outbound rows, users, request and outbox are all as before");
        Assert.That(firebase.Calls, Has.Count.EqualTo(1), "the Google call cannot be rolled back: the sign-in is gone and the request stays open for a retry (PHP's order)");
    }

    [Test]
    public async Task A_cancellation_that_lands_while_Firebase_is_being_called_wins_and_nothing_else_is_written_the_claim_guard()
    {
        var requestId = await AddTargetWithRequestAsync();
        firebase.Inside = () => TestDatabase.ExecuteAsync($"update identity.account_deletion_requests set status = 'cancelled', cancelled_at = now() where id = {requestId}");
        var devicesBefore = await MembershipTestKit.CountAsync("notifications.user_devices");

        var reply = await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        ReplyAssert.Expect(reply, HttpStatusCode.Conflict, $"Deletion request {requestId} is no longer live and cannot be completed");
        Assert.That(await MembershipTestKit.CountAsync("notifications.user_devices"), Is.EqualTo(devicesBefore));
        Assert.That(await MembershipTestKit.CountAsync("identity.users", "email like 'deleted-%'"), Is.EqualTo(0));
        Assert.That(await TestDeletionKit.EventsAsync("identity.member_erased"), Is.EqualTo(0));
        Assert.That(await TestDeletionKit.EventsAsync("identity.deletion_completed"), Is.EqualTo(0));
    }

    [Test]
    public async Task A_completion_writes_exactly_two_events_with_ids_only()
    {
        var requestId = await AddTargetWithRequestAsync();
        var userId = await TestDatabase.ScalarAsync<int>($"select id from identity.users where token = {TestDeletionKit.Target}", TestDatabase.OwnerConnection);

        await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type like 'identity.%'"), Is.EqualTo(2));
        var erased = await TestDeletionKit.EventPayloadAsync("identity.member_erased");
        Assert.That(erased.ToJsonString(), Does.Contain("924010").And.Contain($"{userId}"));
        Assert.That(erased.AsObject().Count, Is.EqualTo(2));
        var completed = await TestDeletionKit.EventPayloadAsync("identity.deletion_completed");
        Assert.That(completed.AsObject().Count, Is.EqualTo(3));
        Assert.That(completed["requestId"]!.GetValue<int>(), Is.EqualTo(requestId));
        Assert.That(completed["token"]!.GetValue<int>(), Is.EqualTo(TestDeletionKit.Target));
        Assert.That(completed["handledBy"]!.GetValue<int>(), Is.EqualTo(TestDeletionKit.Admin));
        foreach (var text in new[] { erased.ToJsonString(), completed.ToJsonString() })
        {
            Assert.That(text, Does.Not.Contain("@").And.Not.Contain("Real Name").And.Not.Contain("+1555"));
        }
    }

    [Test]
    public async Task The_request_is_stamped_completed_by_the_operator()
    {
        var requestId = await AddTargetWithRequestAsync();

        await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        var row = (await TestDatabase.RowAsync($"select status::text as status, handled_by, completed_at from identity.account_deletion_requests where id = {requestId}"))!;
        Assert.That(row["status"], Is.EqualTo("completed"));
        Assert.That(row["handled_by"], Is.EqualTo($"{TestDeletionKit.Admin}"));
        Assert.That(row["completed_at"], Is.Not.Null);
    }

    [Test]
    public async Task A_request_naming_no_member_completes_with_no_Firebase_call_and_only_the_completed_event()
    {
        var requestId = await TestDeletionKit.AddRequestAsync(null);

        var reply = await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        ReplyAssert.Expect(reply, HttpStatusCode.OK);
        Assert.That(firebase.Calls, Is.Empty);
        Assert.That(await TestDeletionKit.EventsAsync("identity.member_erased"), Is.EqualTo(0));
        Assert.That(await TestDeletionKit.EventsAsync("identity.deletion_completed"), Is.EqualTo(1));
    }

    [Test]
    public async Task Contact_details_of_completions_older_than_two_hours_are_purged_after_a_completion_but_a_recent_one_keeps_them()
    {
        var oldId = await TestDeletionKit.AddRequestAsync(924099, "completed", completedAt: "now() - interval '3 hours'");
        var recentId = await TestDeletionKit.AddRequestAsync(924098, "completed", completedAt: "now() - interval '1 hour'");
        var requestId = await AddTargetWithRequestAsync();

        await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        Assert.That(await MembershipTestKit.CountAsync("identity.account_deletion_requests", $"id = {oldId} and contact_name is null and contact_email is null and reason is null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("identity.account_deletion_requests", $"id = {recentId} and contact_email is not null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("identity.account_deletion_requests", $"id = {requestId} and contact_email is not null"), Is.EqualTo(1), "the one just completed keeps its address for the window");
    }

    [Test]
    public async Task Two_simultaneous_completions_of_one_request_reach_Firebase_once_and_erase_once()
    {
        var requestId = await AddTargetWithRequestAsync();

        var replies = await Task.WhenAll(Enumerable.Range(0, 6).Select(_ => api.CompleteAsync(TestDeletionKit.Admin, requestId)));

        Assert.That(replies.Count(r => r.Status == HttpStatusCode.OK), Is.EqualTo(1));
        Assert.That(replies.Count(r => r.Status == HttpStatusCode.Conflict), Is.EqualTo(5));
        Assert.That(firebase.Calls, Has.Count.EqualTo(1));
        Assert.That(await TestDeletionKit.EventsAsync("identity.deletion_completed"), Is.EqualTo(1));
        Assert.That(await TestDeletionKit.EventsAsync("identity.member_erased"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_second_completion_inside_a_minute_is_409_rate_limited_and_the_key_is_also_held_after_a_refusal()
    {
        var requestId = await AddTargetWithRequestAsync();

        await api.CompleteAsync(TestDeletionKit.Admin, requestId);
        var again = await api.CompleteAsync(TestDeletionKit.Admin, requestId);

        ReplyAssert.Expect(again, HttpStatusCode.Conflict, "This request was just completed or is being completed. Wait a minute and reload.");

        var unconfirmed = await TestDeletionKit.AddRequestAsync(924050, confirmed: false);
        ReplyAssert.Expect(await api.CompleteAsync(TestDeletionKit.Admin, unconfirmed), HttpStatusCode.Conflict, "Send the confirmation email and record it before completing this request");
        await TestDatabase.ExecuteAsync($"update identity.account_deletion_requests set confirmation_sent_at = now() where id = {unconfirmed}");
        ReplyAssert.Expect(await api.CompleteAsync(TestDeletionKit.Admin, unconfirmed), HttpStatusCode.Conflict, "This request was just completed or is being completed. Wait a minute and reload.");
    }

    [Test]
    public async Task The_refusals_are_PHPs_statuses_and_texts_and_each_leaves_the_database_and_the_outbox_untouched()
    {
        await TestDeletionKit.AddFullMemberAsync(TestDeletionKit.Target, TestDeletionKit.TargetMobile, [TestDeletionKit.TargetDevice]);
        await TestDatabase.ExecuteAsync("insert into identity.users (token, email) values (924060, 'reviewer@demo.invalid')");
        var completed = await TestDeletionKit.AddRequestAsync(TestDeletionKit.Target, "completed", completedAt: "now() - interval '5 hours'");
        var cancelled = await TestDeletionKit.AddRequestAsync(TestDeletionKit.Target, "cancelled");
        var unconfirmed = await TestDeletionKit.AddRequestAsync(TestDeletionKit.Target, confirmed: false);
        var demo = await TestDeletionKit.AddRequestAsync(924060);
        var guest = await TestDeletionKit.AddRequestAsync(0);
        var negative = await TestDeletionKit.AddRequestAsync(-5);
        var noRow = await TestDeletionKit.AddRequestAsync(924070);
        var before = await TestDeletionKit.WholeDatabaseAsync();

        var cases = new (int Id, HttpStatusCode Status, string Detail)[]
        {
            (completed, HttpStatusCode.Conflict, $"Deletion request {completed} is already completed and cannot be completed"),
            (cancelled, HttpStatusCode.Conflict, $"Deletion request {cancelled} is already cancelled and cannot be completed"),
            (unconfirmed, HttpStatusCode.Conflict, "Send the confirmation email and record it before completing this request"),
            (demo, HttpStatusCode.Conflict,
                $"Deletion request {demo} belongs to the reviewer demo cohort and cannot be completed. Completing it would delete the account an app-store reviewer signs in with. "
                + "Cancel it instead, or run the cohort teardown when the review is finished."),
            (guest, HttpStatusCode.Conflict, "This request names no member and cannot be completed"),
            (negative, HttpStatusCode.Conflict, "This request names no member and cannot be completed"),
            (noRow, HttpStatusCode.Conflict,
                $"Deletion request {noRow} names token 924070, which has no user row. Check whether a Firebase account still exists for it before closing this request."),
            (99999999, HttpStatusCode.NotFound, "Deletion request not found"),
        };
        foreach (var (id, status, detail) in cases)
        {
            ReplyAssert.Expect(await api.CompleteAsync(TestDeletionKit.Admin, id), status, detail);
        }

        Assert.That(await TestDeletionKit.WholeDatabaseAsync(), Is.EqualTo(before));
        Assert.That(firebase.Calls, Is.Empty, "no refusal reaches Firebase");
    }

    [TestCase("0")]
    [TestCase("-3")]
    [TestCase("abc")]
    [TestCase("99999999999999999999")]
    [TestCase("1e3")]
    public async Task A_path_id_that_cannot_name_a_request_is_404_never_a_500(string id)
    {
        var reply = await api.AsAsync(TestDeletionKit.Admin, HttpMethod.Post, $"/admin/deletion-requests/{id}/complete");

        ReplyAssert.Expect(reply, HttpStatusCode.NotFound, "Deletion request not found");
    }

    [Test]
    public async Task A_caller_without_the_permission_is_403_before_any_lookup_so_ids_cannot_be_enumerated()
    {
        await MembershipTestKit.AddMemberAsync(TestDeletionKit.Plain);
        var requestId = await AddTargetWithRequestAsync();

        var real = await api.CompleteAsync(TestDeletionKit.Plain, requestId);
        var missing = await api.CompleteAsync(TestDeletionKit.Plain, 99999999);

        ReplyAssert.Expect(real, HttpStatusCode.Forbidden, "You do not have permission to do that");
        ReplyAssert.Expect(missing, HttpStatusCode.Forbidden, "You do not have permission to do that");
        Assert.That(firebase.Calls, Is.Empty);
        Assert.That(await MembershipTestKit.CountAsync("identity.users", "email like 'deleted-%'"), Is.EqualTo(0));
    }

    [Test]
    public async Task A_caller_holding_only_a_coordinator_role_is_403()
    {
        var coordinator = await MembershipTestKit.AddMemberAsync(924003);
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({coordinator}, 5)");
        var requestId = await AddTargetWithRequestAsync();

        ReplyAssert.Expect(await api.CompleteAsync(924003, requestId), HttpStatusCode.Forbidden, "You do not have permission to do that");
    }

    [Test]
    public async Task A_stranger_signed_in_on_this_create_route_becomes_a_member_without_the_permission_so_403_and_an_operator_who_is_being_deleted_is_403_too()
    {
        var requestId = await AddTargetWithRequestAsync();

        ReplyAssert.Expect(await api.CompleteAsync(924777, requestId), HttpStatusCode.Forbidden, "You do not have permission to do that");

        await TestDeletionKit.AddRequestAsync(TestDeletionKit.Admin);
        ReplyAssert.Expect(await api.CompleteAsync(TestDeletionKit.Admin, requestId), HttpStatusCode.Forbidden, "Account deletion pending");
    }

    [Test]
    public async Task The_columns_of_identity_users_and_the_membership_tables_are_each_erased_or_on_an_explicit_kept_list()
    {
        var erasedOrKept = new Dictionary<string, string[]>
        {
            ["identity.users"] = ["email", "firebase_uid", "lastdevice", "device", "platform", "version", "lastloginip", "id", "token", "provider", "createdon", "lastlogin"],
            ["membership.member_profiles"] =
            [
                "name", "first_name", "last_name", "picture", "gender", "age_range", "mobile", "country", "state", "city", "zip", "language", "sendupdates", "unsubscribe",
                "user_id",
            ],
            ["membership.class_registrations"] =
            [
                "residence_location", "work_location", "preferred_location", "birth_year", "profession", "islamic_study_years", "interests", "other_interests", "education", "field_of_study",
                "field_of_study_other", "professional_courses", "professional_courses_other", "occupation_type", "field_of_work", "years_experience", "role_level", "linkedin_url", "status_reason",
                "id", "token", "for_classid", "class_level", "class_number", "status", "status_date", "created_at", "modified_at", "modified_by",
            ],
        };
        foreach (var (table, known) in erasedOrKept)
        {
            var parts = table.Split('.');
            var actual = (await TestDatabase.ScalarAsync<string>(
                $"select string_agg(column_name, ',' order by column_name) from information_schema.columns where table_schema = '{parts[0]}' and table_name = '{parts[1]}'",
                TestDatabase.OwnerConnection)).Split(',');
            Assert.That(actual, Is.EquivalentTo(known), table + ": a new column must be erased by the completion or added to the kept list on purpose");
        }
    }

    [Test]
    public async Task The_app_role_may_do_every_cross_schema_read_and_write_a_completion_needs()
    {
        await using var connection = new Npgsql.NpgsqlConnection(TestDatabase.AppConnection);
        await connection.OpenAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        foreach (var sql in new[]
        {
            "select count(*) from membership.v_members",
            "select count(*) from identity.v_users",
            "delete from notifications.user_devices where token = -1",
            "delete from platform.feedback where user_id = -1",
            "update platform.outbound_messages set recipient = '[deleted]' where recipient = any(array['-']::text[])",
            "update membership.member_profiles set name = 'Deleted member' where user_id = -1",
            "update membership.class_registrations set linkedin_url = null where token = -1",
            "update identity.users set email = email where token = -1",
            "update identity.account_deletion_requests set status = status where id = -1",
            "insert into platform.outbox (id, event_type, payload, created_at) values (gen_random_uuid(), 'rights.check', '{}', now())",
        })
        {
            await using var command = new Npgsql.NpgsqlCommand(sql, connection, transaction);
            Assert.That(await command.ExecuteNonQueryAsync(), Is.GreaterThanOrEqualTo(-1), sql);
        }

        await transaction.RollbackAsync();
    }
}
