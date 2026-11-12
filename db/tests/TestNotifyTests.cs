using System.Collections.Concurrent;
using System.Net;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Notifications.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>
/// The notify lane (devices, the inbox, announcements, class notifications, scheduled ones, the published commands) against a real database through the API as the limited role, with a FAKE push sender
/// (nothing can reach FCM from here). Hurl proves the wire against PHP; this proves what it cannot see: who is pushed to and who gets an inbox row, the counts kept, dead tokens, the 500-character cut, the rate limits,
/// the events (ids and counts only, never a device token, a title or a body) and the commands other domains call (all on the caller's transaction).
/// World: super administrator 926101; members 926111 (devices dev-a1, dev-a2), 926112 (gender 2, dev-b1), 926113 (no device), 926114 (demo, dev-demo), 926115 (gender "Male", dev-e1);
/// class 9261 (level 3, teacher 926121 with dev-t1): students 926131 (dev-s1), 926132 (status A but removed, dev-s2), 926133 (inactive, dev-s3), 926134 (no device), 926135 (demo, dev-s5);
/// class 9262 (teacher 926122, no device): student 926136 without a device; class 9263 closed (teacher 926123, dev-t3).
/// </summary>
public sealed class TestNotifyTests
{
    private const int Super = 926101;
    private const int A = 926111;
    private const int B = 926112;
    private const int C = 926113;
    private const int Demo = 926114;
    private const int E = 926115;
    private const int T1 = 926121;
    private const int T2 = 926122;
    private const int T3 = 926123;
    private const int S1 = 926131;
    private const int S2 = 926132;
    private const int S3 = 926133;
    private const int S4 = 926134;
    private const int S5 = 926135;
    private const int S6 = 926136;
    private const string NotConfigured = "Push notifications are not configured";

    private sealed class FakeSender : IPushSender
    {
        public bool IsConfigured { get; set; } = true;

        public Func<string, PushResult> Decide { get; set; } = _ => PushResult.Sent;

        public ConcurrentBag<(PushMessage Message, string Token)> Sent { get; } = [];

        public Task<PushResult> SendAsync(PushMessage message, string deviceToken, CancellationToken ct)
        {
            Sent.Add((message, deviceToken));
            return Task.FromResult(Decide(deviceToken));
        }

        public string[] Tokens => [.. Sent.Select(s => s.Token).Order(StringComparer.Ordinal)];
    }

    private FakeSender fake = null!;
    private MembershipTestKit kit = null!;

    [SetUp]
    public async Task SeedAsync()
    {
        fake = new FakeSender();
        kit = new MembershipTestKit(services => services.AddSingleton<IPushSender>(fake));
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync(
            "truncate access.user_roles, access.class_access_rule_conditions, access.class_access_rules restart identity cascade; "
            + "truncate platform.outbox, platform.outbound_messages, platform.admin_access_log, notifications.user_notifications, notifications.notifications, notifications.user_devices, "
            + "notifications.class_scheduled_notification_runs, notifications.class_scheduled_notifications, classes.class_schedules, classes.class_students, classes.classes restart identity cascade");
        foreach (var token in new[] { Super, A, B, C, Demo, E, T1, T2, T3, S1, S2, S3, S4, S5, S6 })
        {
            await MembershipTestKit.AddMemberAsync(token, "Nt Member " + token, token == B ? "2" : token == E ? "Male" : "1");
        }

        await TestDatabase.ExecuteAsync(
            $"update identity.users set email = 'm{Demo}@demo.invalid' where token in ({Demo}, {S5}); "
            + "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + $"insert into access.user_roles (user_id, roleid) select id, 1 from identity.users where token = {Super}; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by, city) values "
            + $"(9261, 'NT-1', 1, 'ntl1', 'Nt One', 3, {T1}, 1, 'Offline', 'A', {T1}, 'Ntville'), (9262, 'NT-2', 1, 'ntl2', 'Nt Two', 3, {T2}, 1, 'Offline', 'A', {T2}, 'Ntville'), (9263, 'NT-3', 1, 'ntl3', 'Nt Closed', 3, {T3}, 1, 'Offline', 'I', {T3}, 'Ntville'); "
            + "insert into classes.class_students (class_id, token_no, joined_on, mcq_admin, status, removed_at) values "
            + $"(9261, {S1}, current_date, 0, 'A', null), (9261, {S2}, current_date, 0, 'A', '2025-10-01'), (9261, {S3}, current_date, 0, 'I', null), (9261, {S4}, current_date, 0, 'A', null), (9261, {S5}, current_date, 0, 'A', null), (9262, {S6}, current_date, 0, 'A', null); "
            + "insert into classes.class_schedules (id, class_id, day, hour, minute, timezone) values (926101, 9261, 1, 10, 0, 'Asia/Kolkata'); "
            + "insert into notifications.user_devices (token, device_id) values "
            + $"({A}, 'dev-a1'), ({A}, 'dev-a2'), ({B}, 'dev-b1'), ({Demo}, 'dev-demo'), ({E}, 'dev-e1'), ({T1}, 'dev-t1'), ({S1}, 'dev-s1'), ({S2}, 'dev-s2'), ({S3}, 'dev-s3'), ({S5}, 'dev-s5'), ({T3}, 'dev-t3')");
    }

    [TearDown]
    public void Stop() => kit.Dispose();

    private static Task<long> CountAsync(string table, string where = "true") => MembershipTestKit.CountAsync(table, where);

    private static async Task<long[]> InboxOfAsync(int notificationId) =>
        [.. (await TestDatabase.ScalarAsync<string>(
            $"select coalesce(string_agg(user_token::text, ',' order by user_token), '') from notifications.user_notifications where notification_id = {notificationId}",
            TestDatabase.OwnerConnection)).Split(',', StringSplitOptions.RemoveEmptyEntries).Select(long.Parse)];

    private static async Task<string> OutboxTextAsync() =>
        await TestDatabase.ScalarAsync<string>("select coalesce(string_agg(payload::text, ' '), '') from platform.outbox", TestDatabase.OwnerConnection);

    private static string Id(int value) => value.ToString(System.Globalization.CultureInfo.InvariantCulture);

    private Task<MembershipTestKit.Reply> SendAnnouncementAsync(string type, params object[] values) => SendAnnouncementAsync(type, values, "Nt Title", "Nt body");

    private Task<MembershipTestKit.Reply> SendAnnouncementAsync(string type, object[] values, string title, string body) =>
        kit.SendAsync(Super, HttpMethod.Post, "/notifications/send", JsonSerializer.Serialize(new { title, body, target = new { type, value = values.Length == 0 ? null : values } }));

    // ---- devices -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task Registering_a_device_another_member_holds_takes_it_over_whatever_the_case_and_the_event_never_carries_the_token()
    {
        var reply = await kit.SendAsync(C, HttpMethod.Post, "/devices", """{"fcmToken": "DEV-B1"}""");
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created));
        Assert.That(await CountAsync("notifications.user_devices", $"device_id = 'dev-b1' and token = {B}"), Is.Zero, "B lost the device (PHP #428: the last registrant owns it)");
        Assert.That(await CountAsync("notifications.user_devices", $"lower(device_id) = 'dev-b1' and token = {C}"), Is.EqualTo(1));
        var payload = await TestDatabase.ScalarAsync<string>("select payload::text from platform.outbox where event_type = 'notifications.device_registered'", TestDatabase.OwnerConnection);
        Assert.That(JsonElement.Parse(payload).GetProperty("reassignedFrom").GetInt32(), Is.EqualTo(1));
        Assert.That(payload.Contains("dev-b1", StringComparison.OrdinalIgnoreCase), Is.False, payload);
    }

    [Test]
    public async Task Two_members_registering_the_same_token_at_once_leave_one_owner_and_a_case_variant_counts_as_the_same_token()
    {
        var variants = new[] { "dev-race", "DEV-RACE", "Dev-Race", "dEV-rACE" };
        var members = new[] { A, B, C, E };
        await Task.WhenAll(members.Select((m, i) => kit.SendAsync(m, HttpMethod.Post, "/devices", $$"""{"fcmToken": "{{variants[i]}}"}""")));
        Assert.That(await CountAsync("notifications.user_devices", "lower(device_id) = 'dev-race'"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_member_removes_only_their_own_device_rows()
    {
        var other = await kit.SendAsync(C, HttpMethod.Delete, "/devices", """{"fcmToken": "dev-a1"}""");
        Assert.That(other.Json!["deleted"]!.GetValue<int>(), Is.Zero);
        Assert.That(await CountAsync("notifications.user_devices", "device_id = 'dev-a1'"), Is.EqualTo(1));
        var own = await kit.SendAsync(A, HttpMethod.Delete, "/devices", """{"fcmToken": "DEV-A1"}""");
        Assert.That(own.Json!["deleted"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'notifications.device_removed'"), Is.EqualTo(1), "one event for the one delete, none for the refused one");
        Assert.That(await OutboxTextAsync(), Does.Not.Contain("dev-a1"));
    }

    [Test]
    public async Task A_token_over_500_characters_or_with_a_NUL_is_a_422_and_writes_nothing()
    {
        foreach (var token in new[] { new string('x', 501), "dev\\u0000nul" })
        {
            var reply = await kit.SendAsync(C, HttpMethod.Post, "/devices", $$"""{"fcmToken": "{{token}}"}""");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), Id(token.Length));
        }

        Assert.That(await CountAsync("notifications.user_devices", $"token = {C}"), Is.Zero);
        Assert.That(await CountAsync("platform.outbox", "event_type like 'notifications.device%'"), Is.Zero);
    }

    // ---- the inbox -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task A_member_reads_counts_and_marks_only_their_own_inbox_rows()
    {
        await TestDatabase.ExecuteAsync(
            "insert into notifications.notifications (notification_id, title, body, target_audience_criteria, created_by) values (1, 't', 'b', '{}', 0); "
            + $"insert into notifications.user_notifications (id, notification_id, user_token, is_read) values (11, 1, {A}, 0), (12, 1, {B}, 0)");

        var other = await kit.SendAsync(A, HttpMethod.Post, "/user/notifications/12/read", "{}");
        Assert.That(other.Status, Is.EqualTo(HttpStatusCode.OK), "a silent ok, so ids cannot be probed");
        Assert.That(await CountAsync("notifications.user_notifications", "id = 12 and is_read = 1"), Is.Zero, "B's row is untouched");

        var list = await kit.SendAsync(A, HttpMethod.Get, "/user/notifications");
        Assert.That(list.Json!["notifications"]!.AsArray().Select(n => n!["id"]!.GetValue<int>()), Is.EqualTo((int[])[11]));
        Assert.That(list.Json["total"]!.GetValue<int>(), Is.EqualTo(1));

        await kit.SendAsync(A, HttpMethod.Post, "/user/notifications/read-all", "{}");
        Assert.That(await CountAsync("notifications.user_notifications", "is_read = 1"), Is.EqualTo(1));
        Assert.That(await CountAsync("notifications.user_notifications", $"user_token = {B} and is_read = 0"), Is.EqualTo(1));
    }

    // ---- POST /notifications/send --------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task An_announcement_to_everyone_pushes_to_every_device_but_the_demo_cohorts_and_records_the_counts_the_inbox_and_one_event()
    {
        fake.Decide = token => token switch { "dev-b1" => PushResult.TokenInvalid, "dev-e1" => PushResult.Failed, _ => PushResult.Sent };
        var body = new string('b', 600);
        var reply = await SendAnnouncementAsync("ALL_USERS", [], "Nt Title", body);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        string[] devices = ["dev-a1", "dev-a2", "dev-b1", "dev-e1", "dev-s1", "dev-s2", "dev-s3", "dev-t1", "dev-t3"];
        Assert.That(fake.Tokens, Is.EqualTo(devices), "the demo members' devices (dev-demo, dev-s5) are left out");
        Assert.That(reply.Json!["device_count"]!.GetValue<int>(), Is.EqualTo(9));
        Assert.That(reply.Json["success_count"]!.GetValue<int>(), Is.EqualTo(7));
        Assert.That(reply.Json["failure_count"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That(reply.Json["message"]!.GetValue<string>(), Is.EqualTo("Notification sent to 7 devices successfully"));

        var sent = fake.Sent.First().Message;
        Assert.That(sent.Body, Has.Length.EqualTo(500), "the push carries the first 500 characters");
        Assert.That(sent.Data["type"], Is.EqualTo("admin_announcement"));
        Assert.That(sent.Data["target_type"], Is.EqualTo("ALL_USERS"));
        Assert.That(sent.Data["action_link"], Is.Empty);
        Assert.That(sent.Data["click_action"], Is.EqualTo("FLUTTER_NOTIFICATION_CLICK"));

        var id = reply.Json["notification_id"]!.GetValue<int>();
        var row = await TestDatabase.RowAsync($"select title, body, target_audience_criteria::text as criteria, created_by, device_count, success_count, failure_count from notifications.notifications where notification_id = {id}");
        Assert.That(row!["body"], Has.Length.EqualTo(600), "the inbox keeps the full text");
        Assert.That(row["created_by"], Is.EqualTo(Id(Super)));
        Assert.That((row["device_count"], row["success_count"], row["failure_count"]), Is.EqualTo(("9", "7", "2")));
        Assert.That(JsonElement.Parse(row["criteria"]!).GetProperty("type").GetString(), Is.EqualTo("ALL_USERS"));
        Assert.That(await InboxOfAsync(id), Is.EqualTo((long[])[A, B, E, T1, T3, S1, S2, S3]), "members with a device, the demo cohort and the member without a device left out");
        Assert.That(await CountAsync("notifications.user_devices", "device_id = 'dev-b1'"), Is.EqualTo(1), "a dead token is NOT deleted by a send");

        Assert.That(await CountAsync("platform.outbox", "event_type = 'notifications.sent'"), Is.EqualTo(1));
        var events = await OutboxTextAsync();
        Assert.That(events, Does.Not.Contain("Nt Title").And.Not.Contain("bbbb").And.Not.Contain("dev-"));
    }

    [Test]
    public async Task An_announcement_with_nobody_to_push_to_writes_nothing_and_sends_nothing()
    {
        var reply = await SendAnnouncementAsync("TEACHERS", 9262);
        Assert.That(reply.Json!["message"]!.GetValue<string>(), Is.EqualTo("No devices found matching the target criteria"));
        Assert.That(fake.Sent, Is.Empty);
        Assert.That(await CountAsync("notifications.notifications"), Is.Zero);
        Assert.That(await CountAsync("platform.outbox", "event_type = 'notifications.sent'"), Is.Zero);
    }

    [Test]
    public async Task Without_a_credential_an_announcement_is_a_500_and_nothing_is_written()
    {
        fake.IsConfigured = false;
        var reply = await SendAnnouncementAsync("ALL_USERS");
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.InternalServerError));
        Assert.That(reply.Detail, Is.EqualTo(NotConfigured));
        Assert.That(await CountAsync("notifications.notifications"), Is.Zero);
        Assert.That(await CountAsync("notifications.user_notifications"), Is.Zero);
        Assert.That(await CountAsync("platform.outbox", "event_type = 'notifications.sent'"), Is.Zero);
    }

    [Test]
    public async Task A_plain_member_cannot_send_and_nothing_is_pushed()
    {
        var reply = await kit.SendAsync(A, HttpMethod.Post, "/notifications/send", """{"title":"T","body":"B","target":{"type":"ALL_USERS"}}""");
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(reply.Detail, Is.EqualTo("Only super administrators can send notifications"));
        Assert.That(fake.Sent, Is.Empty);
    }

    [Test]
    public async Task A_gender_audience_pushes_to_gender_one_but_writes_inbox_rows_for_non_numeric_genders_PHPs_split_pinned()
    {
        var reply = await SendAnnouncementAsync("GENDER", 1);
        Assert.That(fake.Tokens, Is.EqualTo((string[])["dev-a1", "dev-a2", "dev-s1", "dev-s2", "dev-s3", "dev-t1", "dev-t3"]), "devices of members whose gender is 1 (B is 2, E is the word Male, the demo cohort is out)");
        var id = reply.Json!["notification_id"]!.GetValue<int>();
        Assert.That(await InboxOfAsync(id), Is.EqualTo((long[])[E]), "the numeric 1 maps to 0 in the member query: only the non-numeric gender gets a row, and E was not pushed to (finding 17)");
    }

    [Test]
    public async Task A_gender_audience_by_word_finds_no_device_as_in_PHP()
    {
        var reply = await SendAnnouncementAsync("GENDER", "male");
        Assert.That(reply.Json!["message"]!.GetValue<string>(), Is.EqualTo("No devices found matching the target criteria"));
        Assert.That(fake.Sent, Is.Empty);
    }

    [Test]
    public async Task A_class_level_audience_pushes_by_the_level_and_writes_inbox_rows_by_the_class_id_PHPs_split_pinned()
    {
        var reply = await SendAnnouncementAsync("CLASS_LEVEL", 3, 9261);
        Assert.That(fake.Tokens, Is.EqualTo((string[])["dev-s1", "dev-s2"]), "the device query matches level 3, status A, and ignores removed_at (S2); S3 is inactive; the demo student's device is out");
        var id = reply.Json!["notification_id"]!.GetValue<int>();
        Assert.That(await InboxOfAsync(id), Is.EqualTo((long[])[S1, S4]), "the member query matches class 9261: active and not removed, the demo student left out");
    }

    [Test]
    public async Task A_teachers_audience_names_the_active_classes_and_none_means_every_active_class()
    {
        await SendAnnouncementAsync("TEACHERS", 9261);
        Assert.That(fake.Tokens, Is.EqualTo((string[])["dev-t1"]));

        fake.Sent.Clear();
        var all = await SendAnnouncementAsync("TEACHERS", "abc");
        Assert.That(fake.Tokens, Is.EqualTo((string[])["dev-t1"]), "non-numeric values select every active class's teacher; the closed class's teacher (dev-t3) is not one");
        Assert.That(await InboxOfAsync(all.Json!["notification_id"]!.GetValue<int>()), Is.EqualTo((long[])[T1, T2]), "the member query does not need a device: teacher 926122 gets a row and no push");
    }

    [Test]
    public async Task The_history_repeats_a_notification_whose_sender_token_is_shared_as_PHP_does_and_the_admin_audit_row_is_written_for_the_super_administrator_only()
    {
        await TestDatabase.ExecuteAsync(
            $"insert into identity.users (token, email, firebase_uid) values ({A}, 'twin{A}@example.invalid', 'uid-twin-{A}'); "
            + $"insert into notifications.notifications (notification_id, title, body, target_audience_criteria, created_by) values (77, 'Nt Shared', 'b', '{{\"type\":\"ALL_USERS\",\"value\":null}}', {A})");

        var refused = await kit.SendAsync(A, HttpMethod.Get, "/notifications/history");
        Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(await CountAsync("platform.admin_access_log"), Is.Zero, "no audit row for a refused caller");

        var reply = await kit.SendAsync(Super, HttpMethod.Get, "/notifications/history");
        Assert.That(reply.Json!["notifications"]!.AsArray().Count(n => n!["notification_id"]!.GetValue<int>() == 77), Is.EqualTo(2), "one row per account sharing the token (PHP's join; finding 7)");
        Assert.That(await CountAsync("platform.admin_access_log"), Is.EqualTo(1));
    }

    // ---- POST /notifications/cleanup-invalid-tokens ---------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task Cleanup_deletes_only_the_tokens_the_sender_calls_dead_and_pushes_the_system_check_to_every_device_but_the_demo_cohorts()
    {
        fake.Decide = token => token switch { "dev-b1" => PushResult.TokenInvalid, "dev-e1" => PushResult.Failed, _ => PushResult.Sent };
        var reply = await kit.SendAsync(Super, HttpMethod.Post, "/notifications/cleanup-invalid-tokens", "{}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(fake.Tokens, Has.Length.EqualTo(9));
        var message = fake.Sent.First().Message;
        Assert.That((message.Title, message.Body), Is.EqualTo(("System Check", "Verifying device connectivity")));
        Assert.That(message.Data["type"], Is.EqualTo("system_check"));
        Assert.That((reply.Json!["tokens_before"]!.GetValue<int>(), reply.Json["tokens_after"]!.GetValue<int>(), reply.Json["tokens_removed"]!.GetValue<int>()), Is.EqualTo((9, 8, 1)));
        Assert.That((reply.Json["successful_sends"]!.GetValue<int>(), reply.Json["failed_sends"]!.GetValue<int>()), Is.EqualTo((7, 2)));
        Assert.That(await CountAsync("notifications.user_devices", "device_id = 'dev-b1'"), Is.Zero);
        Assert.That(await CountAsync("notifications.user_devices", "device_id = 'dev-e1'"), Is.EqualTo(1), "a plain failure keeps the device");
        Assert.That(await CountAsync("notifications.user_devices", "device_id = 'dev-demo'"), Is.EqualTo(1));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'notifications.invalid_devices_removed'"), Is.EqualTo(1));
        Assert.That(await OutboxTextAsync(), Does.Not.Contain("dev-b1"));
    }

    [Test]
    public async Task Cleanup_with_no_device_says_so_and_omits_tokens_after()
    {
        await TestDatabase.ExecuteAsync("delete from notifications.user_devices");
        var reply = await kit.SendAsync(Super, HttpMethod.Post, "/notifications/cleanup-invalid-tokens", "{}");
        Assert.That(reply.Json!["message"]!.GetValue<string>(), Is.EqualTo("No device tokens found in database"));
        Assert.That(reply.Json["tokens_after"], Is.Null);
        Assert.That(fake.Sent, Is.Empty);
    }

    [Test]
    public async Task Cleanup_without_a_credential_is_a_500_and_deletes_nothing()
    {
        fake.IsConfigured = false;
        var reply = await kit.SendAsync(Super, HttpMethod.Post, "/notifications/cleanup-invalid-tokens", "{}");
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.InternalServerError));
        Assert.That(await CountAsync("notifications.user_devices"), Is.EqualTo(11));
    }

    // ---- POST /classes/{id}/notifications ------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task A_class_notification_reaches_the_active_students_devices_only_and_the_inbox_of_every_active_student_demo_included_as_in_PHP()
    {
        fake.Decide = token => token == "dev-s1" ? PushResult.Sent : PushResult.Failed;
        var body = new string('c', 700);
        var reply = await kit.SendAsync(T1, HttpMethod.Post, "/classes/9261/notifications", JsonSerializer.Serialize(new { title = " Nt Class ", body }));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(fake.Tokens, Is.EqualTo((string[])["dev-s1"]), "S2 was removed, S3 is inactive, S4 has no device, S5 is a demo device");
        Assert.That(reply.Json!["student_count"]!.GetValue<int>(), Is.EqualTo(3), "S1, S4 and S5 are the active students");
        Assert.That(reply.Json["device_count"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(reply.Json["success_count"]!.GetValue<int>(), Is.EqualTo(1));
        var sent = fake.Sent.Single().Message;
        Assert.That((sent.Title, sent.Body.Length), Is.EqualTo(("Nt Class", 500)));
        Assert.That((sent.Data["type"], sent.Data["class_id"], sent.Data["action_link"]), Is.EqualTo(("class_announcement", "9261", string.Empty)));

        var id = reply.Json["notification_id"]!.GetValue<int>();
        var row = await TestDatabase.RowAsync($"select action_link, created_by, target_audience_criteria::text as criteria, length(body) as len from notifications.notifications where notification_id = {id}");
        Assert.That((row!["action_link"], row["created_by"], row["len"]), Is.EqualTo(("/classes/9261/dashboard", Id(T1), "700")), "the inbox keeps the full text and the default link");
        Assert.That(row["criteria"], Does.Contain("CLASS").And.Contain("9261"));
        Assert.That(await InboxOfAsync(id), Is.EqualTo((long[])[S1, S4, S5]));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'notifications.sent'"), Is.EqualTo(1));
        Assert.That(await OutboxTextAsync(), Does.Not.Contain("Nt Class").And.Not.Contain("dev-s1"));
    }

    [Test]
    public async Task Only_the_class_sender_may_notify_the_class_and_a_refusal_pushes_and_writes_nothing()
    {
        foreach (var caller in new[] { T2, S1, A })
        {
            var reply = await kit.SendAsync(caller, HttpMethod.Post, "/classes/9261/notifications", """{"title":"T","body":"B"}""");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Forbidden), Id(caller));
            Assert.That(reply.Detail, Is.EqualTo("You do not have permission to send notifications for this class"));
        }

        var closed = await kit.SendAsync(T3, HttpMethod.Post, "/classes/9263/notifications", """{"title":"T","body":"B"}""");
        Assert.That(closed.Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(fake.Sent, Is.Empty);
        Assert.That(await CountAsync("notifications.notifications"), Is.Zero);
    }

    [Test]
    public async Task The_eleventh_class_notification_in_an_hour_is_a_429_and_a_refused_one_does_not_count()
    {
        for (var i = 0; i < 3; i++)
        {
            var invalid = await kit.SendAsync(T2, HttpMethod.Post, "/classes/9262/notifications", """{"title":"","body":"B"}""");
            Assert.That(invalid.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        }

        for (var i = 0; i < 10; i++)
        {
            var ok = await kit.SendAsync(T2, HttpMethod.Post, "/classes/9262/notifications", """{"title":"T","body":"B"}""");
            Assert.That(ok.Status, Is.EqualTo(HttpStatusCode.OK), Id(i));
        }

        var limited = await kit.SendAsync(T2, HttpMethod.Post, "/classes/9262/notifications", """{"title":"T","body":"B"}""");
        Assert.That(limited.Status, Is.EqualTo((HttpStatusCode)429));
        Assert.That(limited.Detail, Is.EqualTo("Too many class notifications; try again later"));
    }

    // ---- scheduled class notifications ---------------------------------------------------------------------------------------------------------------------------------------------------------------------

    private async Task<MembershipTestKit.Reply> ScheduleOnceAsync(int caller, string title = "Nt Scheduled") =>
        await kit.SendAsync(caller, HttpMethod.Post, "/classes/9261/notifications/scheduled", JsonSerializer.Serialize(new { title, body = "B", kind = "ONCE", timezone = "Asia/Kolkata", send_at = "2099-01-05T10:00" }));

    [Test]
    public async Task A_class_holds_at_most_20_active_scheduled_notifications_and_a_member_creates_at_most_20_an_hour_and_the_events_hold_ids_only()
    {
        for (var i = 0; i < 20; i++)
        {
            Assert.That((await ScheduleOnceAsync(T1)).Status, Is.EqualTo(HttpStatusCode.Created), Id(i));
        }

        var capped = await ScheduleOnceAsync(T1);
        Assert.That(capped.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(capped.Detail, Is.EqualTo("A class can have at most 20 active scheduled notifications"));

        var id = await TestDatabase.ScalarAsync<int>("select min(id) from notifications.class_scheduled_notifications", TestDatabase.OwnerConnection);
        Assert.That((await kit.SendAsync(T1, HttpMethod.Delete, $"/classes/9261/notifications/scheduled/{id}")).Status, Is.EqualTo(HttpStatusCode.OK));
        var limited = await ScheduleOnceAsync(T1);
        Assert.That(limited.Status, Is.EqualTo((HttpStatusCode)429), "20 creates in the hour, whatever was deleted since");
        Assert.That(limited.Detail, Is.EqualTo("Too many scheduled notifications created; try again later"));

        Assert.That(await CountAsync("platform.outbox", "event_type = 'notifications.class_schedule_created'"), Is.EqualTo(20));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'notifications.class_schedule_deleted'"), Is.EqualTo(1));
        Assert.That(await OutboxTextAsync(), Does.Not.Contain("Nt Scheduled"));
    }

    [Test]
    public async Task Only_the_class_sender_lists_or_deletes_scheduled_notifications()
    {
        var created = await ScheduleOnceAsync(T1);
        var id = created.Json!["item"]!["id"]!.GetValue<int>();
        Assert.That((await kit.SendAsync(T2, HttpMethod.Get, "/classes/9261/notifications/scheduled")).Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That((await kit.SendAsync(T2, HttpMethod.Delete, $"/classes/9261/notifications/scheduled/{id}")).Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That((await kit.SendAsync(T2, HttpMethod.Delete, $"/classes/9262/notifications/scheduled/{id}")).Status, Is.EqualTo(HttpStatusCode.NotFound), "another class's route cannot reach the row");
        Assert.That(await CountAsync("notifications.class_scheduled_notifications", $"id = {id} and status <> 'deleted'"), Is.EqualTo(1));
    }

    // ---- the published commands ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    private static async Task<T> InRolledBackTransactionAsync<T>(Func<NotificationsContext, Task<T>> act)
    {
        using var factory = TestApi.Create();
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<NotificationsContext>();
        await using var transaction = await db.Database.BeginTransactionAsync();
        var result = await act(db);
        await transaction.RollbackAsync();
        return result;
    }

    [Test]
    public async Task A_system_announcement_queues_one_push_per_device_reuses_its_notification_by_text_and_a_repeat_queues_nothing_and_a_rollback_leaves_nothing()
    {
        var first = new Announcement("Nt Sys", "Nt sys body", "/quiz/1", "quiz_announcement", "nt-key-1");
        var (one, two, notifications, inbox) = await InRolledBackTransactionAsync(async db =>
        {
            var a = await NotificationsCommands.AnnounceCountedAsync(db, first, CancellationToken.None);
            var b = await NotificationsCommands.AnnounceCountedAsync(db, first, CancellationToken.None);
            var n = await db.Database.SqlQuery<long>($"""select count(*) as "Value" from notifications.notifications where created_by = 0 and title = 'Nt Sys'""").SingleAsync();
            var i = await db.Database.SqlQuery<long>($"""select count(*) as "Value" from notifications.user_notifications""").SingleAsync();
            return (a, b, n, i);
        });

        Assert.That(one, Is.EqualTo(new AnnounceResult(9, 9)), "every registered member's devices, the demo cohort left out");
        Assert.That(two, Is.EqualTo(new AnnounceResult(9, 0)), "the dedupe key refuses a repeat");
        Assert.That(notifications, Is.EqualTo(1), "found again by title, body and link");
        Assert.That(inbox, Is.EqualTo(8), "the members with a device, the demo cohort out, each once");
        Assert.That(await CountAsync("notifications.notifications"), Is.Zero);
        Assert.That(await CountAsync("platform.outbound_messages"), Is.Zero);
    }

    [Test]
    public async Task An_announcement_is_found_again_when_its_title_body_and_link_differ_only_in_letter_case_CASE_C2()
    {
        var first = new Announcement("Nt Case", "Nt case body", "/quiz/Case", "quiz_announcement", "nt-case-1");
        var again = first with { Title = "NT CASE", Body = "NT CASE BODY", ActionLink = "/QUIZ/case", DedupeKey = "nt-case-2" };
        var notifications = await InRolledBackTransactionAsync(async db =>
        {
            await NotificationsCommands.AnnounceCountedAsync(db, first, CancellationToken.None);
            await NotificationsCommands.AnnounceCountedAsync(db, again, CancellationToken.None);
            return await db.Database.SqlQuery<long>($"""select count(*) as "Value" from notifications.notifications where title = 'Nt Case'""").SingleAsync();
        });

        Assert.That(notifications, Is.EqualTo(1), "MariaDB compares title, body and link without regard to letter case, so the second call reuses the first notification");
    }

    [Test]
    public async Task A_members_announcement_keeps_its_sender_criteria_and_counts_from_the_queue_skips_demo_devices_and_always_makes_a_new_notification()
    {
        var announcement = new Announcement(
            "Nt Pub", "Nt pub body", "/quiz/2", "quiz_published", "nt-key-2",
            Tokens: [A, Demo, C], Sender: T1, Criteria: """{"type":"MEMBERS","ids":3}""", Data: new Dictionary<string, string> { ["type"] = "custom" }, ReuseExisting: false, CountsFromQueue: true, SkipDemoDevices: true);
        var (first, second, rows) = await InRolledBackTransactionAsync(async db =>
        {
            var a = await NotificationsCommands.AnnounceCountedAsync(db, announcement, CancellationToken.None);
            var b = await NotificationsCommands.AnnounceCountedAsync(db, announcement with { DedupeKey = "nt-key-3" }, CancellationToken.None);
            var r = await db.Database.SqlQuery<string>($"""select created_by::text || '|' || device_count || '|' || success_count || '|' || failure_count || '|' || target_audience_criteria::text as "Value" from notifications.notifications order by notification_id""").ToListAsync();
            return (a, b, r);
        });

        Assert.That(first, Is.EqualTo(new AnnounceResult(2, 2)), "A's two devices; the demo member's device is skipped and C has none");
        Assert.That(second, Is.EqualTo(new AnnounceResult(2, 2)), "a new key queues again");
        Assert.That(rows, Has.Count.EqualTo(2), "ReuseExisting false: a notification for every call");
        Assert.That(rows[0], Does.StartWith($"{T1}|2|2|0|").And.Contain("MEMBERS"));
    }

    [Test]
    public async Task The_last_nudge_is_the_newest_reminder_to_that_teacher_inside_the_window()
    {
        await TestDatabase.ExecuteAsync(
            "insert into notifications.notifications (title, body, target_audience_criteria, sent_at, created_by) values "
            + $"('n1', 'b', '{{\"type\":\"CC_NUDGE\",\"teacher\":{T1}}}', now() - interval '2 hours', 0), "
            + $"('n2', 'b', '{{\"type\":\"CC_NUDGE\",\"teacher\":{T1}}}', now() - interval '30 hours', 0), "
            + $"('n3', 'b', '{{\"type\":\"CC_NUDGE\",\"teacher\":{T2}}}', now() - interval '1 hours', 0), "
            + $"('n4', 'b', '{{\"type\":\"OTHER\",\"teacher\":{T1}}}', now() - interval '1 hours', 0)");
        using var factory = TestApi.Create();
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<NotificationsContext>();
        var within = await NotificationsCommands.LastNudgeAsync(db, T1, 24, CancellationToken.None);
        Assert.That(within, Is.Not.Null);
        Assert.That(DateTimeOffset.UtcNow - within!.Value, Is.InRange(TimeSpan.FromHours(1.9), TimeSpan.FromHours(2.1)));
        Assert.That(await NotificationsCommands.LastNudgeAsync(db, T1, 1, CancellationToken.None), Is.Null);
        Assert.That(await NotificationsCommands.LastNudgeAsync(db, T3, 24, CancellationToken.None), Is.Null);
    }

    [Test]
    public async Task Erasing_a_members_devices_returns_the_ids_deletes_only_that_members_rows_and_a_rollback_keeps_them()
    {
        var ids = await InRolledBackTransactionAsync(async db =>
        {
            var erased = await NotificationsErasure.EraseDevicesAsync(db, A, CancellationToken.None);
            Assert.That(await db.Database.SqlQuery<long>($"""select count(*) as "Value" from notifications.user_devices where token = {A}""").SingleAsync(), Is.Zero);
            Assert.That(await db.Database.SqlQuery<long>($"""select count(*) as "Value" from notifications.user_devices where token = {B}""").SingleAsync(), Is.EqualTo(1));
            return erased;
        });
        Assert.That(ids.Order(StringComparer.Ordinal), Is.EqualTo((string[])["dev-a1", "dev-a2"]));
        Assert.That(await CountAsync("notifications.user_devices", $"token = {A}"), Is.EqualTo(2));
    }
}
