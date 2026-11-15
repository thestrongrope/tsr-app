using System.Net;
using System.Text.Json.Nodes;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Notifications.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// The member calendar and a class's scheduled events (GET /me/calendar, PUT /me/calendar/settings, GET and POST /classes/{id}/scheduled-events, PATCH and DELETE .../{event_id}) against a real database
/// through the API as the limited role, with a fixed clock (12 Nov 2026 10:00:00.250 UTC). Hurl proves the wire against PHP; this proves what it cannot see: the rows, the order of the refusals, who may
/// manage and who owns, the sync rules (last writer, tie, tombstone, clock skew, a batch that is refused as a whole) and the events (ids only, none on a refusal).
/// World: super administrator 928101; class 9701 (teacher 928111): students 928121 and 928122, 928123 removed, 928124 inactive; slots 970101 (live) and 970102 (deleted);
/// class 9702 (teacher 928112): student 928122, slot 970103; class 9703 closed (teacher 928111): student 928121; 928131 is in no class.
/// </summary>
public sealed class TestCalendarTests
{
    private const int Super = 928101;
    private const int Teacher = 928111;
    private const int OtherTeacher = 928112;
    private const int Student = 928121;
    private const int BothClasses = 928122;
    private const int Removed = 928123;
    private const int Inactive = 928124;
    private const int Outsider = 928131;
    private const string NotAllowed = "You cannot manage events for this class";
    private const string Events = "/classes/9701/scheduled-events";
    private const string Settings = "/me/calendar/settings";
    private const string DeviceA = "aaaaaaaaaaaaaaaa";
    private const string DeviceB = "bbbbbbbbbbbbbbbb";
    private const string ValidEvent = """{"message": " Read the lesson ", "description": "Chapter two", "weekdays": [3, 1], "send_time": "18:30", "timezone": "Asia/Kolkata", "action_link": "/classes/9701/syllabus"}""";

    private static readonly DateTimeOffset Now = new(2026, 11, 12, 10, 0, 0, 250, TimeSpan.Zero);
    private static readonly string[] EventKeys = ["key", "id", "kind", "class_id", "message", "description", "action_link", "weekdays", "send_time", "timezone", "created_by_user_id", "editable_by_me", "takeover"];
    private static readonly string[] SlotKeys = ["key", "kind", "class_id", "message", "description", "action_link", "weekdays", "send_time", "timezone", "editable_by_me", "takeover"];
    private static readonly string[] SettingKeys = ["offset_minutes", "muted", "deleted", "updated_at", "server_updated_at", "device_key"];

    private sealed class FixedClock(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    private readonly Dictionary<int, int> userIds = [];
    private MembershipTestKit kit = null!;

    [SetUp]
    public async Task SeedAsync()
    {
        kit = new MembershipTestKit(services => services.AddSingleton<TimeProvider>(new FixedClock(Now)));
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync(
            "truncate access.user_roles, access.class_access_rule_conditions, access.class_access_rules restart identity cascade; "
            + "truncate platform.outbox, notifications.class_scheduled_events, notifications.member_event_settings, classes.class_schedules, classes.class_students, classes.classes restart identity cascade");
        userIds.Clear();
        foreach (var token in new[] { Super, Teacher, OtherTeacher, Student, BothClasses, Removed, Inactive, Outsider })
        {
            userIds[token] = await MembershipTestKit.AddMemberAsync(token, "Cal Member " + token, "1");
        }

        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + $"insert into access.user_roles (user_id, roleid) values ({userIds[Super]}, 1); "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by, city) values "
            + $"(9701, 'CAL-1', 1, 'call1', 'Cal One', 3, {Teacher}, 1, 'Offline', 'A', {Teacher}, 'Calville'), (9702, 'CAL-2', 1, 'call2', 'Cal Two', 3, {OtherTeacher}, 1, 'Offline', 'A', {OtherTeacher}, 'Calville'), "
            + $"(9703, 'CAL-3', 1, 'call3', 'Cal Closed', 3, {Teacher}, 1, 'Offline', 'I', {Teacher}, 'Calville'); "
            + "insert into classes.class_students (class_id, token_no, joined_on, mcq_admin, status, removed_at) values "
            + $"(9701, {Student}, current_date, 0, 'A', null), (9701, {BothClasses}, current_date, 0, 'A', null), (9701, {Removed}, current_date, 0, 'A', '2026-10-01'), (9701, {Inactive}, current_date, 0, 'I', null), "
            + $"(9702, {BothClasses}, current_date, 0, 'A', null), (9703, {Student}, current_date, 0, 'A', null); "
            + "insert into classes.class_schedules (id, class_id, day, hour, minute, timezone, deleted_at) values "
            + "(970101, 9701, 1, 18, 5, 'Europe/London', null), (970102, 9701, 3, 19, 0, 'Asia/Kolkata', '2026-10-01'), (970103, 9702, 5, 7, 0, 'Asia/Kolkata', null)");
    }

    [TearDown]
    public void Stop() => kit.Dispose();

    // ---- helpers -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    private static Task<long> EventLogAsync(string type = "notifications.%") => MembershipTestKit.CountAsync("platform.outbox", $"event_type like '{type}'");

    private static Task<long> EventRowsAsync(string where = "true") => MembershipTestKit.CountAsync("notifications.class_scheduled_events", where);

    private static Task<long> SettingRowsAsync(string where = "true") => MembershipTestKit.CountAsync("notifications.member_event_settings", where);

    private static Task<string> TextAsync(string sql) => TestDatabase.ScalarAsync<string>(sql, TestDatabase.OwnerConnection);

    private static string[] Keys(JsonNode? node) => [.. node!.AsObject().Select(p => p.Key)];

    private static string Change(string key, string at, bool muted = false, bool deleted = false, string offset = "null") =>
        $$"""{"event_key": "{{key}}", "offset_minutes": {{offset}}, "muted": {{(muted ? "true" : "false")}}, "deleted": {{(deleted ? "true" : "false")}}, "client_updated_at": "{{at}}"}""";

    private static string Batch(string device, params string[] changes) => $$"""{"device_key": "{{device}}", "changes": [{{string.Join(", ", changes)}}]}""";

    private Task<MembershipTestKit.Reply> SyncAsync(int token, string device, params string[] changes) => kit.SendAsync(token, HttpMethod.Put, Settings, Batch(device, changes));

    /// <summary>An event written straight to the table (created 1 Nov 2026), so a test can start from any owner, class or status. Returns its id.</summary>
    private async Task<int> AddEventAsync(int classId, int creator, string status = "active", string message = "Cal event") =>
        await TestDatabase.ScalarAsync<int>(
            "insert into notifications.class_scheduled_events (class_id, created_by, created_by_user_id, message, description, action_link, weekdays, send_time, tz, status, created_at, updated_at, deleted_at) values "
            + $"({classId}, {creator}, {userIds[creator]}, '{message}', null, null, '2,4', '07:15', 'Europe/London', '{status}', '2026-11-01', '2026-11-01', {(status == "deleted" ? "'2026-11-02'" : "null")}) returning id",
            TestDatabase.OwnerConnection);

    private static async Task ExpectRefusedAsync(MembershipTestKit.Reply reply, HttpStatusCode status, string detail)
    {
        Assert.That(reply.Status, Is.EqualTo(status), reply.Body);
        Assert.That(reply.Detail, Is.EqualTo(detail));
        Assert.That(await EventLogAsync(), Is.Zero, "a refusal writes no event");
    }

    // ---- sign-in and permission ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [TestCase("GET", "/me/calendar")]
    [TestCase("PUT", "/me/calendar/settings")]
    [TestCase("GET", "/classes/9701/scheduled-events")]
    [TestCase("POST", "/classes/9701/scheduled-events")]
    [TestCase("PATCH", "/classes/9701/scheduled-events/1")]
    [TestCase("DELETE", "/classes/9701/scheduled-events/1")]
    public async Task Every_route_needs_a_sign_in(string method, string path)
    {
        var reply = await kit.SendUnsignedAsync(new HttpMethod(method), path, method is "GET" or "DELETE" ? null : "{}");
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Unauthorized));
    }

    [TestCase(Teacher, true)]
    [TestCase(Super, true)]
    [TestCase(Student, false)]
    [TestCase(Outsider, false)]
    [TestCase(OtherTeacher, false)]
    public async Task Only_who_may_send_notifications_for_the_class_manages_its_events(int token, bool allowed)
    {
        var id = await AddEventAsync(9701, token);
        var list = await kit.SendAsync(token, HttpMethod.Get, Events);
        // The body is not read before the permission: a refused caller never learns whether their JSON was valid.
        var create = await kit.SendAsync(token, HttpMethod.Post, Events, allowed ? ValidEvent : "{not json");
        var update = await kit.SendAsync(token, HttpMethod.Patch, $"{Events}/{id}", allowed ? """{"message": "Changed"}""" : "{not json");
        var delete = await kit.SendAsync(token, HttpMethod.Delete, $"{Events}/{id}");

        var expected = allowed ? (HttpStatusCode[])[HttpStatusCode.OK, HttpStatusCode.Created, HttpStatusCode.OK, HttpStatusCode.OK] : [.. Enumerable.Repeat(HttpStatusCode.Forbidden, 4)];
        Assert.That((HttpStatusCode[])[list.Status, create.Status, update.Status, delete.Status], Is.EqualTo(expected));
        if (!allowed)
        {
            Assert.That((string?[])[list.Detail, create.Detail, update.Detail, delete.Detail], Is.All.EqualTo(NotAllowed));
            Assert.That(await EventRowsAsync("status = 'active' and message = 'Cal event'"), Is.EqualTo(1), "nothing changed");
            Assert.That(await EventLogAsync(), Is.Zero);
        }
    }

    // ---- create --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task Creating_an_event_stores_it_in_the_senders_zone_answers_201_with_the_item_and_writes_one_event_of_ids()
    {
        var reply = await kit.SendAsync(Teacher, HttpMethod.Post, Events, ValidEvent);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created), reply.Body);
        var item = reply.Json!["item"]!;
        var id = item["id"]!.GetValue<int>();
        Assert.That(Keys(reply.Json), Is.EqualTo((string[])["item"]));
        Assert.That(Keys(item), Is.EqualTo(EventKeys));
        Assert.That(item.ToJsonString(), Is.EqualTo(
            $$"""{"key":"event:{{id}}","id":{{id}},"kind":"event","class_id":9701,"message":"Read the lesson","description":"Chapter two","action_link":"/classes/9701/syllabus","weekdays":[1,3],"send_time":"18:30","timezone":"Asia/Kolkata","created_by_user_id":{{userIds[Teacher]}},"editable_by_me":true,"takeover":false}"""));
        Assert.That(
            await TextAsync($"select concat_ws('|', class_id, created_by, created_by_user_id, weekdays, send_time, tz, status, created_at at time zone 'UTC', updated_at at time zone 'UTC', deleted_at) from notifications.class_scheduled_events where id = {id}"),
            Is.EqualTo($"9701|{Teacher}|{userIds[Teacher]}|1,3|18:30:00|Asia/Kolkata|active|2026-11-12 10:00:00.25|2026-11-12 10:00:00.25"));
        var payload = await TextAsync("select payload::text from platform.outbox where event_type = 'notifications.class_event_created'");
        Assert.That(JsonNode.Parse(payload)!.ToJsonString(), Is.EqualTo($$"""{"id":{{id}},"classId":9701,"createdBy":{{Teacher}}}"""));
        Assert.That(await EventLogAsync(), Is.EqualTo(1));
    }

    [TestCase("{not json", "Invalid JSON body")]
    [TestCase("""{"description": 5, "send_time": "x", "weekdays": [], "timezone": "x"}""", "Message is required and must be at most 500 characters")]
    [TestCase("""{"message": "m", "description": 5, "send_time": "x", "weekdays": [], "timezone": "x"}""", "Description must be at most 2000 characters")]
    [TestCase("""{"message": "m", "send_time": "25:00", "action_link": "ftp://x.invalid", "weekdays": [], "timezone": "x"}""", "Time must be HH:MM")]
    [TestCase("""{"message": "m", "send_time": "09:00", "action_link": "ftp://x.invalid", "weekdays": [], "timezone": "x"}""", "action_link must be an https:// link or an in-app path such as /classes/12/syllabus")]
    [TestCase("""{"message": "m", "send_time": "09:00", "weekdays": [], "timezone": "x"}""", "Choose between one and seven weekdays")]
    [TestCase("""{"message": "m", "send_time": "09:00", "weekdays": [1, 9], "timezone": "x"}""", "Weekdays must be integers from 1 (Monday) to 7")]
    [TestCase("""{"message": "m", "send_time": "09:00", "weekdays": [1]}""", "A valid IANA time zone from this phone is required")]
    [TestCase("""{"message": "m", "send_time": "09:00", "weekdays": [1], "timezone": "Nope/Nowhere"}""", "A valid IANA time zone from this phone is required")]
    public async Task A_bad_event_is_refused_in_PHPs_order_and_nothing_is_stored(string body, string detail)
    {
        await ExpectRefusedAsync(await kit.SendAsync(Teacher, HttpMethod.Post, Events, body), HttpStatusCode.UnprocessableEntity, detail);
        Assert.That(await EventRowsAsync(), Is.Zero);
    }

    [Test]
    public async Task A_class_holds_at_most_500_active_events_and_deleted_ones_do_not_count()
    {
        await TestDatabase.ExecuteAsync(
            "insert into notifications.class_scheduled_events (class_id, created_by, created_by_user_id, message, weekdays, send_time, tz, status, created_at, updated_at) "
            + $"select 9701, {Teacher}, {userIds[Teacher]}, 'Cal bulk ' || n, '1', '09:00', 'UTC', case when n <= 499 then 'active' else 'deleted' end, now(), now() from generate_series(1, 520) n");

        var last = await kit.SendAsync(Teacher, HttpMethod.Post, Events, ValidEvent);
        Assert.That(last.Status, Is.EqualTo(HttpStatusCode.Created), last.Body);
        var over = await kit.SendAsync(Teacher, HttpMethod.Post, Events, ValidEvent);
        Assert.That(over.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(over.Detail, Is.EqualTo("This class already has 500 scheduled events"));
        Assert.That(await EventRowsAsync("status = 'active'"), Is.EqualTo(500));
        Assert.That(await EventLogAsync(), Is.EqualTo(1));
    }

    // ---- list ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task The_list_has_the_classs_live_events_and_live_slots_in_id_order_and_says_which_the_caller_may_edit()
    {
        var mine = await AddEventAsync(9701, Teacher);
        var supers = await AddEventAsync(9701, Super, message: "Cal by super");
        await AddEventAsync(9701, Teacher, "deleted");
        await AddEventAsync(9702, OtherTeacher);

        var reply = await kit.SendAsync(Teacher, HttpMethod.Get, Events);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(Keys(reply.Json), Is.EqualTo((string[])["events", "slots"]));
        var events = reply.Json!["events"]!.AsArray();
        Assert.That(events.Select(e => e!["id"]!.GetValue<int>()), Is.EqualTo((int[])[mine, supers]));
        Assert.That(events[0]!.ToJsonString(), Is.EqualTo(
            $$"""{"key":"event:{{mine}}","id":{{mine}},"kind":"event","class_id":9701,"message":"Cal event","description":null,"action_link":null,"weekdays":[2,4],"send_time":"07:15","timezone":"Europe/London","created_by_user_id":{{userIds[Teacher]}},"editable_by_me":true,"takeover":false}"""));
        Assert.That((bool[])[events[1]!["editable_by_me"]!.GetValue<bool>(), events[1]!["takeover"]!.GetValue<bool>()], Is.EqualTo((bool[])[false, false]), "its owner, the super administrator, still has access");
        var slots = reply.Json["slots"]!.AsArray();
        Assert.That(slots, Has.Count.EqualTo(1), "the deleted slot is left out");
        Assert.That(Keys(slots[0]), Is.EqualTo(SlotKeys));
        Assert.That(slots[0]!.ToJsonString(), Is.EqualTo(
            """{"key":"slot:970101","kind":"slot","class_id":9701,"message":"Class timetable","description":null,"action_link":"/classes/9701/dashboard","weekdays":[1],"send_time":"18:05","timezone":"Europe/London","editable_by_me":false,"takeover":false}"""));
    }

    [Test]
    public async Task A_sender_takes_over_an_event_whose_owner_lost_access_and_the_owner_stays_the_owner()
    {
        var id = await AddEventAsync(9701, Teacher);
        await TestDatabase.ExecuteAsync($"update classes.classes set teacher = {OtherTeacher} where id = 9701");

        var listed = (await kit.SendAsync(OtherTeacher, HttpMethod.Get, Events)).Json!["events"]![0]!;
        Assert.That((bool[])[listed["editable_by_me"]!.GetValue<bool>(), listed["takeover"]!.GetValue<bool>()], Is.EqualTo((bool[])[true, true]));
        var update = await kit.SendAsync(OtherTeacher, HttpMethod.Patch, $"{Events}/{id}", """{"message": "Taken over"}""");
        Assert.That(update.Status, Is.EqualTo(HttpStatusCode.OK), update.Body);
        Assert.That(update.Json!["item"]!["takeover"]!.GetValue<bool>(), Is.True);
        Assert.That(update.Json["item"]!["created_by_user_id"]!.GetValue<int>(), Is.EqualTo(userIds[Teacher]));
        Assert.That(await EventRowsAsync($"id = {id} and message = 'Taken over' and created_by = {Teacher} and created_by_user_id = {userIds[Teacher]}"), Is.EqualTo(1));
        Assert.That((await kit.SendAsync(Teacher, HttpMethod.Patch, $"{Events}/{id}", "{}")).Detail, Is.EqualTo(NotAllowed), "the former teacher no longer manages the class");
        Assert.That((await kit.SendAsync(OtherTeacher, HttpMethod.Delete, $"{Events}/{id}")).Status, Is.EqualTo(HttpStatusCode.OK));
    }

    // ---- update --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task An_edit_changes_only_the_fields_sent_keeps_the_creators_zone_and_writes_one_event()
    {
        var id = await AddEventAsync(9701, Teacher);

        var reply = await kit.SendAsync(Teacher, HttpMethod.Patch, $"{Events}/{id}", """{"message": " Updated ", "description": "More", "timezone": "Asia/Kolkata", "action_link": "https://youtu.be/abc123"}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(Keys(reply.Json), Is.EqualTo((string[])["item"]));
        Assert.That(reply.Json!["item"]!.ToJsonString(), Is.EqualTo(
            $$"""{"key":"event:{{id}}","id":{{id}},"kind":"event","class_id":9701,"message":"Updated","description":"More","action_link":"/videos/abc123","weekdays":[2,4],"send_time":"07:15","timezone":"Europe/London","created_by_user_id":{{userIds[Teacher]}},"editable_by_me":true,"takeover":false}"""));
        Assert.That(await TextAsync($"select concat_ws('|', tz, created_at at time zone 'UTC', updated_at at time zone 'UTC') from notifications.class_scheduled_events where id = {id}"), Is.EqualTo("Europe/London|2026-11-01 00:00:00|2026-11-12 10:00:00.25"));
        var payload = await TextAsync("select payload::text from platform.outbox where event_type = 'notifications.class_event_updated'");
        Assert.That(JsonNode.Parse(payload)!.ToJsonString(), Is.EqualTo($$"""{"id":{{id}},"classId":9701,"updatedBy":{{Teacher}}}"""));
        Assert.That(await EventLogAsync(), Is.EqualTo(1));

        var cleared = await kit.SendAsync(Teacher, HttpMethod.Patch, $"{Events}/{id}", """{"description": null, "action_link": null, "weekdays": [7], "send_time": "23:59"}""");
        Assert.That(cleared.Json!["item"]!.ToJsonString(), Does.Contain("""message":"Updated","description":null,"action_link":null,"weekdays":[7],"send_time":"23:59","""));
    }

    [Test]
    public async Task An_edit_is_refused_in_PHPs_order_the_body_then_the_event_then_the_owner_then_the_fields()
    {
        var mine = await AddEventAsync(9701, Teacher);
        var supers = await AddEventAsync(9701, Super);
        var deleted = await AddEventAsync(9701, Teacher, "deleted");
        var elsewhere = await AddEventAsync(9702, OtherTeacher);
        const string notFound = "Scheduled event not found";
        const string notOwner = "Only the owner can change this event while they retain access";

        await ExpectRefusedAsync(await kit.SendAsync(Teacher, HttpMethod.Patch, $"{Events}/999999", "{not json"), HttpStatusCode.UnprocessableEntity, "Invalid JSON body");
        await ExpectRefusedAsync(await kit.SendAsync(Teacher, HttpMethod.Patch, $"{Events}/999999", """{"message": ""}"""), HttpStatusCode.NotFound, notFound);
        await ExpectRefusedAsync(await kit.SendAsync(Teacher, HttpMethod.Patch, $"{Events}/{deleted}", """{"message": "x"}"""), HttpStatusCode.NotFound, notFound);
        await ExpectRefusedAsync(await kit.SendAsync(Teacher, HttpMethod.Patch, $"{Events}/{elsewhere}", """{"message": "x"}"""), HttpStatusCode.NotFound, notFound);
        await ExpectRefusedAsync(await kit.SendAsync(Super, HttpMethod.Patch, $"/classes/9702/scheduled-events/{mine}", """{"message": "x"}"""), HttpStatusCode.NotFound, notFound);
        await ExpectRefusedAsync(await kit.SendAsync(Teacher, HttpMethod.Patch, $"{Events}/{supers}", """{"message": ""}"""), HttpStatusCode.Forbidden, notOwner);
        await ExpectRefusedAsync(await kit.SendAsync(Super, HttpMethod.Patch, $"{Events}/{mine}", """{"message": "x"}"""), HttpStatusCode.Forbidden, notOwner);
        await ExpectRefusedAsync(await kit.SendAsync(Teacher, HttpMethod.Patch, $"{Events}/{mine}", """{"message": null}"""), HttpStatusCode.UnprocessableEntity, "Message is required and must be at most 500 characters");
        await ExpectRefusedAsync(await kit.SendAsync(Teacher, HttpMethod.Patch, $"{Events}/{mine}", """{"weekdays": null}"""), HttpStatusCode.UnprocessableEntity, "Choose between one and seven weekdays");
        await ExpectRefusedAsync(await kit.SendAsync(Teacher, HttpMethod.Patch, $"{Events}/{mine}", """{"send_time": "7:15"}"""), HttpStatusCode.UnprocessableEntity, "Time must be HH:MM");
        Assert.That(await EventRowsAsync("message = 'Cal event' and updated_at = '2026-11-01'"), Is.EqualTo(4), "no row changed");
    }

    // ---- delete --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task Deleting_an_event_keeps_its_row_as_deleted_writes_one_event_and_a_second_delete_finds_nothing()
    {
        var id = await AddEventAsync(9701, Teacher);

        var reply = await kit.SendAsync(Teacher, HttpMethod.Delete, $"{Events}/{id}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!.ToJsonString(), Is.EqualTo("""{"success":true}"""));
        Assert.That(
            await TextAsync($"select concat_ws('|', status, deleted_at at time zone 'UTC', updated_at at time zone 'UTC') from notifications.class_scheduled_events where id = {id}"),
            Is.EqualTo("deleted|2026-11-12 10:00:00.25|2026-11-12 10:00:00.25"));
        var payload = await TextAsync("select payload::text from platform.outbox where event_type = 'notifications.class_event_deleted'");
        Assert.That(JsonNode.Parse(payload)!.ToJsonString(), Is.EqualTo($$"""{"id":{{id}},"classId":9701,"deletedBy":{{Teacher}}}"""));

        var again = await kit.SendAsync(Teacher, HttpMethod.Delete, $"{Events}/{id}");
        Assert.That((again.Status, again.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Scheduled event not found")));
        Assert.That(await EventLogAsync(), Is.EqualTo(1));
        Assert.That((await kit.SendAsync(Teacher, HttpMethod.Get, Events)).Json!["events"]!.AsArray(), Is.Empty);
    }

    [Test]
    public async Task A_delete_is_refused_for_another_classs_event_and_for_an_event_whose_owner_still_has_access()
    {
        var mine = await AddEventAsync(9701, Teacher);
        var supers = await AddEventAsync(9701, Super);
        var elsewhere = await AddEventAsync(9702, OtherTeacher);

        await ExpectRefusedAsync(await kit.SendAsync(Teacher, HttpMethod.Delete, $"{Events}/{elsewhere}"), HttpStatusCode.NotFound, "Scheduled event not found");
        await ExpectRefusedAsync(await kit.SendAsync(Super, HttpMethod.Delete, $"/classes/9702/scheduled-events/{mine}"), HttpStatusCode.NotFound, "Scheduled event not found");
        await ExpectRefusedAsync(await kit.SendAsync(Teacher, HttpMethod.Delete, $"{Events}/{supers}"), HttpStatusCode.Forbidden, "Only the owner can delete this event while they retain access");
        await ExpectRefusedAsync(await kit.SendAsync(Super, HttpMethod.Delete, $"{Events}/{mine}"), HttpStatusCode.Forbidden, "Only the owner can delete this event while they retain access");
        Assert.That(await EventRowsAsync("status = 'active'"), Is.EqualTo(3));
    }

    // ---- the calendar --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task A_student_sees_the_events_and_slots_of_their_live_classes_and_may_edit_none()
    {
        var first = await AddEventAsync(9701, Teacher);
        await AddEventAsync(9701, Teacher, "deleted");
        var other = await AddEventAsync(9702, OtherTeacher);
        await AddEventAsync(9703, Teacher);

        var reply = await kit.SendAsync(BothClasses, HttpMethod.Get, "/me/calendar");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(Keys(reply.Json), Is.EqualTo((string[])["server_time", "freshness", "classes", "settings"]));
        Assert.That(reply.Json!["server_time"]!.GetValue<string>(), Is.EqualTo("2026-11-12T10:00:00Z"));
        Assert.That(reply.Json["freshness"]!.ToJsonString(), Is.EqualTo("""{"max_hours":12,"target_hours":6}"""));
        Assert.That(reply.Json["settings"]!.ToJsonString(), Is.EqualTo("{}"), "an object even when empty");
        var classes = reply.Json["classes"]!.AsArray();
        Assert.That(classes.Select(c => c!["class_id"]!.GetValue<int>()), Is.EqualTo((int[])[9701, 9702]));
        Assert.That(Keys(classes[0]), Is.EqualTo((string[])["class_id", "code", "name", "events", "slots"]));
        Assert.That((string[])[classes[0]!["code"]!.GetValue<string>(), classes[0]!["name"]!.GetValue<string>()], Is.EqualTo((string[])["CAL-1", "Cal One"]));
        Assert.That(classes[0]!["events"]!.ToJsonString(), Is.EqualTo(
            $$"""[{"key":"event:{{first}}","id":{{first}},"kind":"event","class_id":9701,"message":"Cal event","description":null,"action_link":null,"weekdays":[2,4],"send_time":"07:15","timezone":"Europe/London","created_by_user_id":{{userIds[Teacher]}},"editable_by_me":false,"takeover":false}]"""));
        Assert.That(classes[0]!["slots"]!.AsArray().Select(s => s!["key"]!.GetValue<string>()), Is.EqualTo((string[])["slot:970101"]));
        Assert.That(classes[1]!["events"]!.AsArray().Select(e => e!["id"]!.GetValue<int>()), Is.EqualTo((int[])[other]));
        Assert.That(classes[1]!["slots"]!.AsArray().Select(s => s!["key"]!.GetValue<string>()), Is.EqualTo((string[])["slot:970103"]));
    }

    [TestCase(Teacher, "the teacher is not a student of the class: the calendar is the student's view")]
    [TestCase(Super, "a super administrator is in no class")]
    [TestCase(Removed, "removed from the class")]
    [TestCase(Inactive, "an inactive enrolment")]
    [TestCase(Outsider, "in no class")]
    public async Task Who_is_not_a_current_student_of_a_live_class_has_an_empty_calendar(int token, string why)
    {
        await AddEventAsync(9701, Teacher);

        var reply = await kit.SendAsync(token, HttpMethod.Get, "/me/calendar");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["classes"]!.ToJsonString(), Is.EqualTo("[]"), why);
    }

    [Test]
    public async Task A_student_of_a_closed_class_does_not_see_it_and_what_they_deleted_for_themselves_is_hidden_but_kept_in_the_settings()
    {
        var kept = await AddEventAsync(9701, Teacher);
        var hidden = await AddEventAsync(9701, Teacher, message: "Cal hidden");
        var sync = await SyncAsync(Student, DeviceA, Change($"event:{hidden}", "2026-11-12T09:00:00Z", deleted: true), Change("slot:970101", "2026-11-12T09:00:00Z", deleted: true), Change($"event:{kept}", "2026-11-12T09:00:00Z", muted: true, offset: "-15"));
        Assert.That(sync.Status, Is.EqualTo(HttpStatusCode.OK), sync.Body);

        var reply = await kit.SendAsync(Student, HttpMethod.Get, "/me/calendar");

        var classes = reply.Json!["classes"]!.AsArray();
        Assert.That(classes.Select(c => c!["class_id"]!.GetValue<int>()), Is.EqualTo((int[])[9701]), "9703 is closed");
        Assert.That(classes[0]!["events"]!.AsArray().Select(e => e!["id"]!.GetValue<int>()), Is.EqualTo((int[])[kept]));
        Assert.That(classes[0]!["slots"]!.AsArray(), Is.Empty);
        var settings = reply.Json["settings"]!.AsObject();
        Assert.That(settings.Select(p => p.Key).Order(StringComparer.Ordinal), Is.EqualTo(((string[])[$"event:{hidden}", $"event:{kept}", "slot:970101"]).Order(StringComparer.Ordinal)));
        Assert.That(settings[$"event:{kept}"]!.ToJsonString(), Is.EqualTo(
            """{"offset_minutes":-15,"muted":true,"deleted":false,"updated_at":"2026-11-12T09:00:00.000Z","server_updated_at":"2026-11-12T10:00:00.250Z","device_key":"aaaaaaaaaaaaaaaa"}"""));
        Assert.That((await kit.SendAsync(BothClasses, HttpMethod.Get, "/me/calendar")).Json!["classes"]![0]!["events"]!.AsArray(), Has.Count.EqualTo(2), "another student still sees both");
    }

    // ---- the settings sync ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task A_sync_stores_the_members_setting_answers_the_canonical_state_and_writes_one_event_of_ids_and_counts()
    {
        var id = await AddEventAsync(9701, Teacher);

        var reply = await SyncAsync(Student, DeviceA, Change($"event:{id}", "2026-11-12T09:59:58.5Z", muted: true, offset: "-30"));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(Keys(reply.Json), Is.EqualTo((string[])["settings", "rejected", "clock_skew", "server_time"]));
        Assert.That(Keys(reply.Json!["settings"]![$"event:{id}"]), Is.EqualTo(SettingKeys));
        Assert.That(reply.Json.ToJsonString(), Is.EqualTo(
            "{\"settings\":{\"event:" + id + "\":{\"offset_minutes\":-30,\"muted\":true,\"deleted\":false,\"updated_at\":\"2026-11-12T09:59:58.500Z\",\"server_updated_at\":\"2026-11-12T10:00:00.250Z\",\"device_key\":\"aaaaaaaaaaaaaaaa\"}},"
            + "\"rejected\":[],\"clock_skew\":false,\"server_time\":\"2026-11-12T10:00:00.250Z\"}"));
        Assert.That(
            await TextAsync("select concat_ws('|', user_id, class_id, event_key, offset_minutes, muted, deleted_for_me, client_updated_at at time zone 'UTC', server_updated_at at time zone 'UTC', device_key) from notifications.member_event_settings"),
            Is.EqualTo($"{userIds[Student]}|9701|event:{id}|-30|1|0|2026-11-12 09:59:58.5|2026-11-12 10:00:00.25|aaaaaaaaaaaaaaaa"));
        var payload = await TextAsync("select payload::text from platform.outbox where event_type = 'notifications.event_settings_synced'");
        Assert.That(JsonNode.Parse(payload)!.ToJsonString(), Is.EqualTo($$"""{"token":{{Student}},"written":1}"""));
    }

    [Test]
    public async Task An_empty_batch_answers_an_empty_object_and_writes_nothing()
    {
        var reply = await SyncAsync(Student, DeviceA);

        Assert.That(reply.Json!.ToJsonString(), Is.EqualTo("""{"settings":{},"rejected":[],"clock_skew":false,"server_time":"2026-11-12T10:00:00.250Z"}"""));
        Assert.That(await EventLogAsync(), Is.Zero);
    }

    [TestCase("{not json", "Invalid JSON body")]
    [TestCase("""{"changes": "x"}""", "device_key must be a random installation identifier (16-64 characters)")]
    [TestCase("""{"device_key": "short", "changes": []}""", "device_key must be a random installation identifier (16-64 characters)")]
    [TestCase("""{"device_key": "aaaaaaaaaaaaaaaa"}""", "A batch must contain at most 200 changes")]
    [TestCase("""{"device_key": "aaaaaaaaaaaaaaaa", "changes": {"event_key": "event:1"}}""", "A batch must contain at most 200 changes")]
    [TestCase("""{"device_key": "aaaaaaaaaaaaaaaa", "changes": [7]}""", "Each change must be an object")]
    [TestCase("""{"device_key": "aaaaaaaaaaaaaaaa", "changes": [{"event_key": 7}]}""", "event_key must be a string")]
    [TestCase("""{"device_key": "aaaaaaaaaaaaaaaa", "changes": [{"event_key": "quiz:1"}]}""", "Invalid event_key")]
    [TestCase("""{"device_key": "aaaaaaaaaaaaaaaa", "changes": [{"event_key": "slot:970101", "offset_minutes": -7, "muted": 1}]}""", "Choose a supported alert offset")]
    [TestCase("""{"device_key": "aaaaaaaaaaaaaaaa", "changes": [{"event_key": "slot:970101", "muted": 1, "deleted": false}]}""", "muted and deleted must be booleans")]
    [TestCase("""{"device_key": "aaaaaaaaaaaaaaaa", "changes": [{"event_key": "slot:970101", "muted": true, "deleted": false, "client_updated_at": "yesterday"}]}""", "client_updated_at must be an ISO UTC timestamp")]
    [TestCase("""{"device_key": "aaaaaaaaaaaaaaaa", "changes": [{"event_key": "slot:970101", "muted": true, "deleted": false, "client_updated_at": "2026-02-30T00:00:00Z"}]}""", "Invalid client_updated_at")]
    public async Task A_bad_sync_is_refused_in_PHPs_order(string body, string detail)
    {
        await ExpectRefusedAsync(await kit.SendAsync(Student, HttpMethod.Put, Settings, body), HttpStatusCode.UnprocessableEntity, detail);
        Assert.That(await SettingRowsAsync(), Is.Zero);
    }

    [Test]
    public async Task A_batch_of_more_than_200_changes_is_refused_and_200_pass()
    {
        var change = Change("slot:970101", "2026-11-12T09:00:00Z");

        await ExpectRefusedAsync(await SyncAsync(Student, DeviceA, [.. Enumerable.Repeat(change, 201)]), HttpStatusCode.UnprocessableEntity, "A batch must contain at most 200 changes");
        Assert.That((await SyncAsync(Student, DeviceA, [.. Enumerable.Repeat(change, 200)])).Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(await SettingRowsAsync(), Is.EqualTo(1));
    }

    [Test]
    public async Task One_bad_change_refuses_the_whole_batch_and_the_changes_before_it_are_not_kept()
    {
        var reply = await SyncAsync(Student, DeviceA, Change("slot:970101", "2026-11-12T09:00:00Z", muted: true), """{"event_key": "slot:970101", "muted": "no", "deleted": false}""");

        await ExpectRefusedAsync(reply, HttpStatusCode.UnprocessableEntity, "muted and deleted must be booleans");
        Assert.That(await SettingRowsAsync(), Is.Zero);
    }

    [Test]
    public async Task A_change_for_an_item_the_member_cannot_see_is_rejected_by_key_and_the_rest_of_the_batch_is_kept()
    {
        var live = await AddEventAsync(9701, Teacher);
        var deleted = await AddEventAsync(9701, Teacher, "deleted");
        var elsewhere = await AddEventAsync(9702, OtherTeacher);
        var closed = await AddEventAsync(9703, Teacher);
        string[] gone = [$"event:{deleted}", $"event:{elsewhere}", $"event:{closed}", "event:999999", "slot:970102", "slot:970103", "slot:9999999999"];

        // A rejected change is not checked any further: its bad offset is never a 422.
        var reply = await SyncAsync(Student, DeviceA, [.. gone.Select(k => Change(k, "2026-11-12T09:00:00Z", offset: "-7")), Change($"event:{live}", "2026-11-12T09:00:00Z")]);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["rejected"]!.AsArray().Select(r => r!.GetValue<string>()), Is.EqualTo(gone));
        Assert.That(Keys(reply.Json["settings"]), Is.EqualTo((string[])[$"event:{live}"]));
        Assert.That(await SettingRowsAsync(), Is.EqualTo(1));
    }

    [TestCase(Teacher)]
    [TestCase(Super)]
    [TestCase(Removed)]
    [TestCase(Inactive)]
    [TestCase(Outsider)]
    public async Task Only_a_current_student_of_the_class_keeps_settings_for_its_items(int token)
    {
        var id = await AddEventAsync(9701, Teacher);

        var reply = await SyncAsync(token, DeviceA, Change($"event:{id}", "2026-11-12T09:00:00Z"), Change("slot:970101", "2026-11-12T09:00:00Z"));

        Assert.That(reply.Json!["rejected"]!.ToJsonString(), Is.EqualTo($$"""["event:{{id}}","slot:970101"]"""));
        Assert.That(await SettingRowsAsync(), Is.Zero);
        Assert.That(await EventLogAsync(), Is.Zero);
    }

    [Test]
    public async Task An_older_client_update_loses_the_stored_setting_is_answered_and_nothing_is_written()
    {
        await SyncAsync(Student, DeviceA, Change("slot:970101", "2026-11-12T09:00:00Z", muted: true, offset: "-60"));
        await TestDatabase.ExecuteAsync("truncate platform.outbox");

        var reply = await SyncAsync(Student, DeviceB, Change("slot:970101", "2026-11-12T08:59:59.999Z", muted: false, offset: "-5"));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["settings"]!["slot:970101"]!.ToJsonString(), Is.EqualTo(
            """{"offset_minutes":-60,"muted":true,"deleted":false,"updated_at":"2026-11-12T09:00:00.000Z","server_updated_at":"2026-11-12T10:00:00.250Z","device_key":"aaaaaaaaaaaaaaaa"}"""));
        Assert.That(await SettingRowsAsync("muted = 1 and offset_minutes = -60 and device_key = 'aaaaaaaaaaaaaaaa'"), Is.EqualTo(1));
        Assert.That(await EventLogAsync(), Is.Zero, "nothing changed, so no event");
    }

    [Test]
    public async Task A_newer_client_update_wins_and_at_the_same_millisecond_the_greater_device_key_wins()
    {
        await SyncAsync(Student, DeviceA, Change("slot:970101", "2026-11-12T09:00:00Z", muted: true));

        var sameDevice = await SyncAsync(Student, DeviceA, Change("slot:970101", "2026-11-12T09:00:00.000Z", muted: false));
        Assert.That(sameDevice.Json!["settings"]!["slot:970101"]!["muted"]!.GetValue<bool>(), Is.True, "the same time from the same device changes nothing");
        var greater = await SyncAsync(Student, DeviceB, Change("slot:970101", "2026-11-12T09:00:00Z", muted: false, offset: "-5"));
        Assert.That(greater.Json!["settings"]!["slot:970101"]!["device_key"]!.GetValue<string>(), Is.EqualTo(DeviceB));
        var smaller = await SyncAsync(Student, DeviceA, Change("slot:970101", "2026-11-12T09:00:00Z", muted: true));
        Assert.That(smaller.Json!["settings"]!["slot:970101"]!["device_key"]!.GetValue<string>(), Is.EqualTo(DeviceB), "the smaller key loses the tie");
        var newer = await SyncAsync(Student, DeviceA, Change("slot:970101", "2026-11-12T09:00:00.001Z", muted: true));
        Assert.That(newer.Json!["settings"]!["slot:970101"]!.ToJsonString(), Does.StartWith("""{"offset_minutes":null,"muted":true,"deleted":false,"updated_at":"2026-11-12T09:00:00.001Z","""));
        Assert.That(await SettingRowsAsync(), Is.EqualTo(1), "one row per member and item");
        Assert.That(await SettingRowsAsync("muted = 1 and offset_minutes is null and device_key = 'aaaaaaaaaaaaaaaa'"), Is.EqualTo(1));
    }

    [Test]
    public async Task Deleted_for_me_is_a_tombstone_a_later_change_cannot_clear()
    {
        await SyncAsync(Student, DeviceA, Change("slot:970101", "2026-11-12T09:00:00Z", deleted: true));

        var reply = await SyncAsync(Student, DeviceB, Change("slot:970101", "2026-11-12T09:30:00Z", deleted: false, muted: true));

        Assert.That(reply.Json!["settings"]!["slot:970101"]!.ToJsonString(), Does.StartWith("""{"offset_minutes":null,"muted":true,"deleted":true,"updated_at":"2026-11-12T09:30:00.000Z","""));
        Assert.That(await SettingRowsAsync("deleted_for_me = 1 and muted = 1"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_phone_whose_clock_runs_more_than_five_minutes_ahead_is_given_the_servers_time_and_told()
    {
        var onTime = await SyncAsync(Student, DeviceA, Change("slot:970101", "2026-11-12T10:05:00.250Z"));
        Assert.That(onTime.Json!["clock_skew"]!.GetValue<bool>(), Is.False);
        Assert.That(onTime.Json["settings"]!["slot:970101"]!["updated_at"]!.GetValue<string>(), Is.EqualTo("2026-11-12T10:05:00.250Z"));

        var ahead = await SyncAsync(BothClasses, DeviceA, Change("slot:970101", "2031-01-01T00:00:00Z"), Change("slot:970103", "2026-11-12T09:00:00Z"));

        Assert.That(ahead.Json!["clock_skew"]!.GetValue<bool>(), Is.True);
        Assert.That(ahead.Json["settings"]!["slot:970101"]!["updated_at"]!.GetValue<string>(), Is.EqualTo("2026-11-12T10:00:00.250Z"));
        Assert.That(ahead.Json["settings"]!["slot:970103"]!["updated_at"]!.GetValue<string>(), Is.EqualTo("2026-11-12T09:00:00.000Z"));
        Assert.That(await SettingRowsAsync($"user_id = {userIds[BothClasses]} and event_key = 'slot:970101' and client_updated_at = '2026-11-12 10:00:00.25+00'"), Is.EqualTo(1));
    }

    [Test]
    public async Task The_same_item_twice_in_one_batch_is_applied_in_order_and_answered_once_and_members_do_not_share_settings()
    {
        await SyncAsync(BothClasses, DeviceA, Change("slot:970101", "2026-11-12T09:30:00Z", muted: true));

        var reply = await SyncAsync(Student, DeviceA, Change("slot:970101", "2026-11-12T09:00:00Z", offset: "-5"), Change("slot:970101", "2026-11-12T09:10:00Z", offset: "-15"), Change("slot:970101", "2026-11-12T09:05:00Z", offset: "-30"));

        Assert.That(Keys(reply.Json!["settings"]), Is.EqualTo((string[])["slot:970101"]));
        Assert.That(reply.Json["settings"]!["slot:970101"]!["offset_minutes"]!.GetValue<int>(), Is.EqualTo(-15), "the third change is older than the second");
        Assert.That(await SettingRowsAsync(), Is.EqualTo(2));
        Assert.That(await SettingRowsAsync($"user_id = {userIds[Student]} and offset_minutes = -15 and muted = 0"), Is.EqualTo(1));
        var payload = await TextAsync($"select payload::text from platform.outbox where event_type = 'notifications.event_settings_synced' and payload::text like '%{Student}%'");
        Assert.That(JsonNode.Parse(payload)!["written"]!.GetValue<int>(), Is.EqualTo(2));
    }

    // ---- account deletion ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task Erasing_a_members_calendar_settings_deletes_only_theirs_and_must_run_inside_the_deletions_transaction()
    {
        await SyncAsync(Student, DeviceA, Change("slot:970101", "2026-11-12T09:00:00Z"));
        await SyncAsync(BothClasses, DeviceA, Change("slot:970101", "2026-11-12T09:00:00Z"), Change("slot:970103", "2026-11-12T09:00:00Z"));
        using var factory = TestApi.Create();
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<NotificationsContext>();

        Assert.That(async () => await NotificationsErasure.EraseEventSettingsAsync(db, BothClasses, CancellationToken.None), Throws.InstanceOf<InvalidOperationException>());
        await using (var transaction = await db.Database.BeginTransactionAsync())
        {
            Assert.That(await NotificationsErasure.EraseEventSettingsAsync(db, BothClasses, CancellationToken.None), Is.EqualTo(2));
            await transaction.CommitAsync();
        }

        Assert.That(await SettingRowsAsync(), Is.EqualTo(1));
        Assert.That(await SettingRowsAsync($"user_id = {userIds[Student]}"), Is.EqualTo(1));
    }
}
