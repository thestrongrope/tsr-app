using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Tsr.Db.Tests;

/// <summary>
/// The scenarios behind notifications' golden files (issue 103): each is a fixed list of requests on its own copy of the seeded database. <see cref="Routes"/> are the answers of the routes and
/// their refusals, with the rows and events after the writes (TC-NTF-R1-01); <see cref="Pushes"/> are the scenarios that push through the recording FCM handler (TC-NTF-R5-01).
/// A transcript is one request per block: the answer, then what it sent to an outside service, then (where a scenario writes) the rows of every table. The headers of a request are not in a
/// transcript, so the label of each request says who sent it. A scenario with many writes dumps the rows once at the end, not after each write.
/// </summary>
internal static class NotificationsGoldenScenarios
{
    private const int Admin = NotificationsSeed.Admin;
    private const int Sender = NotificationsSeed.Sender;
    private const int Plain = NotificationsSeed.Plain;
    private const int Student = NotificationsSeed.Student;
    private const int Student3 = NotificationsSeed.Student3;
    private const int Teacher2 = NotificationsSeed.Teacher2;
    private const int Ladies = NotificationsSeed.Ladies;
    private const int Taker = NotificationsSeed.Taker;
    private const int Removed = NotificationsSeed.Removed;
    private const string KeyA = "devicekey-aaaaaaaa1";
    private const string KeyB = "devicekey-bbbbbbbb2";
    private const string KeyLow = "devicekey-0000000000";
    private const string Odd = NotificationsSeed.Odd;

    private static readonly HttpMethod Get = HttpMethod.Get;
    private static readonly HttpMethod Post = HttpMethod.Post;
    private static readonly HttpMethod Put = HttpMethod.Put;
    private static readonly HttpMethod Patch = HttpMethod.Patch;
    private static readonly HttpMethod Delete = HttpMethod.Delete;

    public static IReadOnlyDictionary<string, Func<NotificationsRun, Task>> Routes { get; } = new Dictionary<string, Func<NotificationsRun, Task>>
    {
        ["devices-register"] = DevicesRegisterAsync,
        ["devices-register-refused"] = DevicesRegisterRefusedAsync,
        ["devices-register-trim"] = DevicesRegisterTrimAsync,
        ["devices-register-limit"] = DevicesRegisterLimitAsync,
        ["devices-remove"] = DevicesRemoveAsync,
        ["devices-remove-refused"] = DevicesRemoveRefusedAsync,
        ["inbox-list"] = InboxListAsync,
        ["inbox-list-refused"] = InboxListRefusedAsync,
        ["inbox-unread-count"] = InboxUnreadCountAsync,
        ["inbox-read-all"] = InboxReadAllAsync,
        ["inbox-read-one"] = InboxReadOneAsync,
        ["history"] = HistoryAsync,
        ["history-refused"] = HistoryRefusedAsync,
        ["stats"] = StatsAsync,
        ["stats-empty-table"] = StatsEmptyAsync,
        ["send-refused"] = SendRefusedAsync,
        ["cleanup-refused"] = CleanupRefusedAsync,
        ["class-send-refused"] = ClassSendRefusedAsync,
        ["class-send-limit"] = ClassSendLimitAsync,
        ["scheduled-list"] = ScheduledListAsync,
        ["scheduled-list-refused"] = ScheduledListRefusedAsync,
        ["scheduled-create"] = ScheduledCreateAsync,
        ["scheduled-create-refused"] = ScheduledCreateRefusedAsync,
        ["scheduled-create-cap"] = ScheduledCreateCapAsync,
        ["scheduled-create-limit"] = ScheduledCreateLimitAsync,
        ["scheduled-delete"] = ScheduledDeleteAsync,
        ["calendar-get"] = CalendarGetAsync,
        ["calendar-sync-writes"] = CalendarSyncWritesAsync,
        ["calendar-sync-refused"] = CalendarSyncRefusedAsync,
        ["calendar-sync-batch-refused"] = CalendarSyncBatchRefusedAsync,
        ["calendar-sync-200-changes"] = CalendarSync200Async,
        ["events-list"] = EventsListAsync,
        ["event-create"] = EventCreateAsync,
        ["event-create-refused"] = EventCreateRefusedAsync,
        ["event-create-cap"] = EventCreateCapAsync,
        ["event-update"] = EventUpdateAsync,
        ["event-update-refused"] = EventUpdateRefusedAsync,
        ["event-update-bad-zone"] = EventUpdateBadZoneAsync,
        ["event-delete"] = EventDeleteAsync,
    };

    public static IReadOnlyDictionary<string, Func<NotificationsRun, Task>> Pushes { get; } = new Dictionary<string, Func<NotificationsRun, Task>>
    {
        ["push-send-class-level"] = PushSendClassLevelAsync,
        ["push-send-gender"] = PushSendGenderAsync,
        ["push-send-teachers"] = PushSendTeachersAsync,
        ["push-send-all"] = PushSendAllAsync,
        ["push-send-no-devices"] = PushSendNoDevicesAsync,
        ["push-class-send"] = PushClassSendAsync,
        ["push-class-send-no-devices"] = PushClassSendNoDevicesAsync,
        ["push-cleanup"] = PushCleanupAsync,
        ["push-cleanup-no-tokens"] = PushCleanupNoTokensAsync,
    };

    private static string J(object value) => JsonSerializer.Serialize(value);

    private static string Token(string device) => J(new { fcmToken = device });

    private static string Announcement(string type, object? value, string title = "Nt title", string body = "Nt body", string? link = null)
    {
        var target = new JsonObject { ["type"] = type, ["value"] = value is null ? null : JsonSerializer.SerializeToNode(value) };
        var request = new JsonObject { ["title"] = title, ["body"] = body, ["target"] = target };
        if (link is not null)
        {
            request["action_link"] = link;
        }

        return request.ToJsonString();
    }

    private static string ClassPath(int classId, string tail = "notifications") => $"/classes/{classId}/{tail}";

    private static string Event(string message = "Event text", object? weekdays = null, string time = "07:30", string? timezone = "Asia/Kolkata", string? description = null, string? link = null)
    {
        var request = new JsonObject { ["message"] = message, ["weekdays"] = JsonSerializer.SerializeToNode(weekdays ?? (int[])[1, 3]), ["send_time"] = time };
        if (timezone is not null)
        {
            request["timezone"] = timezone;
        }

        if (description is not null)
        {
            request["description"] = description;
        }

        if (link is not null)
        {
            request["action_link"] = link;
        }

        return request.ToJsonString();
    }

    private static string Scheduled(string kind, string title = "Sched title", object? extra = null)
    {
        var request = new JsonObject { ["title"] = title, ["body"] = "Sched body", ["kind"] = kind, ["timezone"] = "Asia/Kolkata" };
        if (extra is not null)
        {
            foreach (var property in JsonSerializer.SerializeToNode(extra)!.AsObject())
            {
                request[property.Key] = property.Value?.DeepClone();
            }
        }

        return request.ToJsonString();
    }

    private static string Change(string key, string at, object? offset = null, bool muted = false, bool deleted = false)
    {
        var change = new JsonObject { ["event_key"] = key, ["muted"] = muted, ["deleted"] = deleted, ["client_updated_at"] = at };
        if (offset is not null)
        {
            change["offset_minutes"] = JsonSerializer.SerializeToNode(offset);
        }

        return change.ToJsonString();
    }

    private static string Batch(string deviceKey, params string[] changes) => $$"""{"device_key":"{{deviceKey}}","changes":[{{string.Join(",", changes)}}]}""";

    private static async Task Rows(NotificationsRun run, string label) => await run.RowsAsync(label);

    // ---- devices ----

    private static async Task DevicesRegisterAsync(NotificationsRun run)
    {
        await run.AsAsync(Plain, Post, "/devices", Token("dev-new-1"));
        await Rows(run, "a new device");
        await run.AsAsync(Plain, Post, "/devices", J(new { fcm_token = "  DEV-NEW-1  " }));
        await Rows(run, "the same device again, in another case");
        await run.AsAsync(Plain, Post, "/devices", """{"fcmToken":null,"fcm_token":"tok+en<&>é🙂"}""");
        await Rows(run, "an awkward token and the second name of the field");
        await run.AsAsync(Plain, Post, "/devices", Token("DEV-S3-BUSY"));
        await Rows(run, "a device another member held");
        await run.AsAsync(Student, Post, "/devices", Token("dev-plain-2"));
        await Rows(run, "a device the plain member held, taken back");
    }

    private static async Task DevicesRegisterRefusedAsync(NotificationsRun run)
    {
        await run.AsGuestAsync(Post, "/devices", Token("dev-guest"));
        await run.AsNobodyAsync(Post, "/devices", Token("dev-nobody"));
        foreach (var body in new[] { "nope", "[1]", "{}", """{"fcmToken":5}""", """{"fcmToken":"   "}""", J(new { fcmToken = new string('x', 501) }), """{"fcmToken":"a\u0000b"}""", string.Empty })
        {
            await run.AsAsync(Plain, Post, "/devices", body);
        }

        await Rows(run, "the refusals");
    }

    private static async Task DevicesRegisterTrimAsync(NotificationsRun run)
    {
        await run.AsAsync(NotificationsSeed.Crowd, Post, "/devices", Token("dev-crowd-new"));
        await Rows(run, "a 21st device");
        await run.AsAsync(NotificationsSeed.Crowd, Post, "/devices", Token("DEV-CROWD-05"));
        await Rows(run, "a device already held");
    }

    private static async Task DevicesRegisterLimitAsync(NotificationsRun run)
    {
        for (var n = 1; n <= 11; n++)
        {
            await run.AsAsync(Ladies, Post, "/devices", Token("dev-lim-" + n.ToString("00", CultureInfo.InvariantCulture)));
        }

        await run.AsAsync(Ladies, Post, "/devices", Token("dev-f1-ok"));
        await Rows(run, "ten new devices, the 11th refused, a held one allowed");
    }

    private static async Task DevicesRemoveAsync(NotificationsRun run)
    {
        await run.AsAsync(Plain, Delete, "/devices", Token("DEV-PLAIN-1"));
        await Rows(run, "a device removed in another case");
        await run.AsAsync(Plain, Delete, "/devices", Token("dev-plain-1"));
        await run.AsAsync(Plain, Delete, "/devices", Token("dev-s1-ok"));
        await Rows(run, "a device already gone, and another member's");
        await run.AsAsync(Plain, Delete, "/devices", J(new { fcm_token = "  dev-plain-2  " }));
        await Rows(run, "the second name of the field, padded");
    }

    private static async Task DevicesRemoveRefusedAsync(NotificationsRun run)
    {
        await run.AsGuestAsync(Delete, "/devices", Token("dev-guest"));
        await run.AsNobodyAsync(Delete, "/devices", Token("dev-nobody"));
        foreach (var body in new[] { "nope", "{}", """{"fcmToken":["x"]}""", J(new { fcmToken = new string('x', 501) }), string.Empty })
        {
            await run.AsAsync(Plain, Delete, "/devices", body);
        }

        await Rows(run, "the refusals");
    }

    // ---- the inbox ----

    private static async Task InboxListAsync(NotificationsRun run)
    {
        const string path = "/user/notifications";
        await run.AsAsync(Plain, Get, path);
        foreach (var query in (string[])["?limit=2", "?limit=2&offset=1", "?offset=-1", "?offset=2", "?limit=500", "?limit=0", "?limit=-5", "?limit=", "?limit=2&limit=1", "?offset=99&limit=2", "?limit=0002"])
        {
            await run.AsAsync(Plain, Get, path + query);
        }

        await run.AsAsync(Ladies, Get, path);
        await run.AsAsync(Admin, Get, path);
        await run.AsAsync(Student, Get, path);
    }

    private static async Task InboxListRefusedAsync(NotificationsRun run)
    {
        const string path = "/user/notifications";
        await run.AsGuestAsync(Get, path);
        await run.AsNobodyAsync(Get, path);
        foreach (var query in (string[])["?limit=x", "?offset=x", "?limit=1.5", "?limit=%202", "?limit=x&offset=y"])
        {
            await run.AsAsync(Plain, Get, path + query);
        }
    }

    private static async Task InboxUnreadCountAsync(NotificationsRun run)
    {
        const string path = "/user/notifications/unread-count";
        await run.AsAsync(Plain, Get, path);
        await run.AsAsync(Ladies, Get, path);
        await run.AsAsync(Admin, Get, path);
        await run.AsGuestAsync(Get, path);
        await run.AsNobodyAsync(Get, path);
    }

    private static async Task InboxReadAllAsync(NotificationsRun run)
    {
        const string path = "/user/notifications/read-all";
        await run.AsAsync(Plain, Post, path);
        await Rows(run, "read-all as the plain member");
        await run.AsAsync(Plain, Get, "/user/notifications/unread-count");
        await run.AsAsync(Plain, Post, path);
        await run.AsAsync(Admin, Post, path);
        await run.AsGuestAsync(Post, path);
        await run.AsNobodyAsync(Post, path);
        await Rows(run, "the repeats and the refusals");
    }

    private static async Task InboxReadOneAsync(NotificationsRun run)
    {
        await run.AsAsync(Plain, Post, "/user/notifications/2/read");
        await Rows(run, "row 2 read");
        await run.AsAsync(Plain, Post, "/user/notifications/2/read");
        foreach (var id in (string[])["4", "abc", "0", "99999", "99999999999", "-3", "3abc"])
        {
            await run.AsAsync(Plain, Post, $"/user/notifications/{id}/read");
        }

        await run.AsGuestAsync(Post, "/user/notifications/1/read");
        await run.AsNobodyAsync(Post, "/user/notifications/1/read");
        await Rows(run, "the other ids and the refusals");
    }

    // ---- history and stats ----

    private static async Task HistoryAsync(NotificationsRun run)
    {
        const string path = "/notifications/history";
        await run.AsAsync(Admin, Get, path);
        foreach (var query in (string[])["?limit=3", "?limit=3&offset=3", "?offset=-1&limit=1", "?limit=500", "?limit=0&offset=8", "?offset=99"])
        {
            await run.AsAsync(Admin, Get, path + query);
        }

        await Rows(run, "the audit rows");
    }

    private static async Task HistoryRefusedAsync(NotificationsRun run)
    {
        const string path = "/notifications/history";
        await run.AsAsync(Plain, Get, path);
        await run.AsGuestAsync(Get, path);
        await run.AsNobodyAsync(Get, path);
        await run.AsAsync(Admin, Get, path + "?limit=x");
        await run.AsAsync(Admin, Get, path + "?offset=x");
        await Rows(run, "the audit rows");
    }

    private static async Task StatsAsync(NotificationsRun run)
    {
        await run.AsAsync(Admin, Get, "/notifications/stats");
        await run.AsAsync(Plain, Get, "/notifications/stats");
        await run.AsGuestAsync(Get, "/notifications/stats");
        await run.AsNobodyAsync(Get, "/notifications/stats");
        await Rows(run, "the audit rows");
    }

    private static async Task StatsEmptyAsync(NotificationsRun run)
    {
        await run.Run.ExecuteAsync("delete from notifications.notifications");
        await run.AsAsync(Admin, Get, "/notifications/stats");
        await run.AsAsync(Admin, Get, "/notifications/history");
    }

    // ---- refusals of the push routes (nothing is pushed or stored) ----

    private static async Task SendRefusedAsync(NotificationsRun run)
    {
        const string path = "/notifications/send";
        var good = Announcement("CLASS_LEVEL", (int[])[2]);
        await run.AsAsync(Plain, Post, path, "nope");
        await run.AsAsync(Plain, Post, path, good);
        await run.AsGuestAsync(Post, path, good);
        await run.AsNobodyAsync(Post, path, good);
        var cases = new[]
        {
            "nope", "[1]", "{}", Announcement("ALL_USERS", null, title: string.Empty), Announcement("ALL_USERS", null, title: new string('t', 256)), Announcement("ALL_USERS", null, body: string.Empty),
            Announcement("ALL_USERS", null, body: new string('b', 2001)), Announcement("ALL_USERS", null, title: "a\0b"), """{"title":"T","body":"B"}""", """{"title":"T","body":"B","target":"x"}""",
            """{"title":"T","body":"B","target":{"type":"NOBODY","value":[1]}}""", """{"title":"T","body":"B","target":{"type":"GENDER","value":"1"}}""",
            Announcement("ALL_USERS", null, link: new string('l', 501)), Announcement("ALL_USERS", null, link: "javascript:alert(1)"), Announcement("ALL_USERS", null, link: "http://plain.invalid/a"),
        };
        foreach (var body in cases)
        {
            await run.AsAsync(Admin, Post, path, body);
        }

        await Rows(run, "the audit rows of the refusals");
    }

    private static async Task CleanupRefusedAsync(NotificationsRun run)
    {
        const string path = "/notifications/cleanup-invalid-tokens";
        await run.AsAsync(Plain, Post, path);
        await run.AsGuestAsync(Post, path);
        await run.AsNobodyAsync(Post, path);
        await Rows(run, "no audit row");
    }

    private static async Task ClassSendRefusedAsync(NotificationsRun run)
    {
        var good = J(new { title = "T", body = "B" });
        await run.AsAsync(Sender, Post, ClassPath(99999), good);
        await run.AsAsync(Sender, Post, ClassPath(0), good);
        await run.AsAsync(Sender, Post, "/classes/abc/notifications", good);
        await run.AsAsync(Sender, Post, ClassPath(NotificationsSeed.ClassClosed), good);
        await run.AsAsync(Plain, Post, ClassPath(NotificationsSeed.ClassOne), good);
        await run.AsAsync(Teacher2, Post, ClassPath(NotificationsSeed.ClassOne), good);
        await run.AsGuestAsync(Post, ClassPath(NotificationsSeed.ClassOne), good);
        await run.AsNobodyAsync(Post, ClassPath(NotificationsSeed.ClassOne), good);
        var cases = new[]
        {
            "nope", "[1]", "{}", J(new { title = "   ", body = "B" }), J(new { title = new string('t', 256), body = "B" }), J(new { title = "T", body = " " }), J(new { title = "T", body = new string('b', 2001) }),
            J(new { title = "T", body = "B", action_link = new string('l', 501) }), J(new { title = "T", body = "B", action_link = "ftp://x.invalid/a" }), """{"title":"a\u0000b","body":"B"}""",
        };
        foreach (var body in cases)
        {
            await run.AsAsync(Sender, Post, ClassPath(NotificationsSeed.ClassBare), body);
        }

        await Rows(run, "nothing stored");
    }

    // The call counts against the limit even when nothing is sent: class four has a student with no device.
    private static async Task ClassSendLimitAsync(NotificationsRun run)
    {
        var body = J(new { title = "T", body = "B" });
        for (var n = 1; n <= 11; n++)
        {
            await run.AsAsync(Sender, Post, ClassPath(NotificationsSeed.ClassBare), body);
        }

        await Rows(run, "ten answers and a 429");
    }

    // ---- scheduled class notifications ----

    private static async Task ScheduledListAsync(NotificationsRun run)
    {
        var path = ClassPath(NotificationsSeed.ClassOne, "notifications/scheduled");
        await run.AsAsync(Sender, Get, path);
        await run.AsAsync(Admin, Get, path);
        await run.AsAsync(Teacher2, Get, ClassPath(NotificationsSeed.ClassTwo, "notifications/scheduled"));
        await run.AsAsync(Sender, Get, ClassPath(NotificationsSeed.ClassBare, "notifications/scheduled"));
    }

    private static async Task ScheduledListRefusedAsync(NotificationsRun run)
    {
        var path = ClassPath(NotificationsSeed.ClassOne, "notifications/scheduled");
        await run.AsAsync(Plain, Get, path);
        await run.AsAsync(Teacher2, Get, path);
        await run.AsGuestAsync(Get, path);
        await run.AsNobodyAsync(Get, path);
        await run.AsAsync(Sender, Get, ClassPath(99999, "notifications/scheduled"));
        await run.AsAsync(Sender, Get, ClassPath(NotificationsSeed.ClassClosed, "notifications/scheduled"));
        await run.AsAsync(Sender, Get, "/classes/abc/notifications/scheduled");
    }

    private static async Task ScheduledCreateAsync(NotificationsRun run)
    {
        var path = ClassPath(NotificationsSeed.ClassOne, "notifications/scheduled");
        await run.AsAsync(Sender, Post, path, Scheduled("ONCE", Odd, new { send_at = "2026-03-01T10:00", action_link = "https://www.thestrongrope.com/articles/an-article/" }));
        await Rows(run, "a ONCE");
        await run.AsAsync(Sender, Post, path, Scheduled("once", "Once in a skipped hour", new { send_at = "2026-03-29 01:30:00", timezone = "Europe/London" }));
        await run.AsAsync(Sender, Post, path, Scheduled("WEEKLY", "Weekly", new { weekdays = (int[])[7, 1, 1, 3], send_time = "06:45", timezone = "Asia/Calcutta" }));
        await run.AsAsync(Sender, Post, path, Scheduled("WEEKLY", "Weekly object", new { weekdays = new { a = 2, b = 4 }, send_time = "23:59", timezone = "Europe/London" }));
        await run.AsAsync(Sender, Post, path, Scheduled("REMINDER", "Reminder", new { class_schedule_id = NotificationsSeed.SlotLive, offset_minutes = -45, repeat_weekly = true }));
        await run.AsAsync(Sender, Post, path, Scheduled("REMINDER", "Reminder text offset", new { class_schedule_id = NotificationsSeed.SlotOther, offset_minutes = "30.9", repeat_weekly = "0" }));
        await run.AsAsync(Sender, Post, path, Scheduled("REMINDER", "Reminder at the limit", new { class_schedule_id = NotificationsSeed.SlotOther, offset_minutes = -10080 }));
        await run.AsAsync(Admin, Post, path, Scheduled("ONCE", "Admin once", new { send_at = "2026-12-31T23:59:59" }));
        await Rows(run, "every kind");
    }

    private static async Task ScheduledCreateRefusedAsync(NotificationsRun run)
    {
        var path = ClassPath(NotificationsSeed.ClassOne, "notifications/scheduled");
        await run.AsAsync(Plain, Post, path, Scheduled("ONCE", extra: new { send_at = "2026-03-01T10:00" }));
        await run.AsAsync(Teacher2, Post, path, Scheduled("ONCE", extra: new { send_at = "2026-03-01T10:00" }));
        await run.AsGuestAsync(Post, path, Scheduled("ONCE"));
        await run.AsNobodyAsync(Post, path, Scheduled("ONCE"));
        await run.AsAsync(Sender, Post, ClassPath(99999, "notifications/scheduled"), Scheduled("ONCE"));
        var cases = new[]
        {
            "nope", "[1]", "{}", Scheduled("ONCE", title: " "), Scheduled("ONCE", title: new string('t', 256)), Scheduled("NEVER"), Scheduled(string.Empty), Scheduled("ONCE"),
            Scheduled("ONCE", extra: new { send_at = "tomorrow" }), Scheduled("ONCE", extra: new { send_at = "2020-01-01T10:00" }), Scheduled("ONCE", extra: new { send_at = "2026-02-31T10:00" }),
            Scheduled("ONCE", extra: new { send_at = "2026-03-01T10:00", timezone = "Mars/Phobos" }), Scheduled("ONCE", extra: new { send_at = "2026-03-01T10:00", timezone = 5 }),
            Scheduled("ONCE", extra: new { send_at = "2026-03-01T10:00", action_link = "javascript:x" }), Scheduled("ONCE", extra: new { send_at = "2026-03-01T10:00", action_link = new string('l', 501) }),
            Scheduled("WEEKLY"), Scheduled("WEEKLY", extra: new { weekdays = (int[])[], send_time = "10:00" }), Scheduled("WEEKLY", extra: new { weekdays = (int[])[0], send_time = "10:00" }),
            Scheduled("WEEKLY", extra: new { weekdays = (int[])[8], send_time = "10:00" }), Scheduled("WEEKLY", extra: new { weekdays = (int[])[1], send_time = "25:00" }), Scheduled("WEEKLY", extra: new { weekdays = (int[])[1] }),
            Scheduled("REMINDER"), Scheduled("REMINDER", extra: new { class_schedule_id = NotificationsSeed.SlotDeleted, offset_minutes = 5 }), Scheduled("REMINDER", extra: new { class_schedule_id = 1, offset_minutes = 5 }),
            Scheduled("REMINDER", extra: new { class_schedule_id = NotificationsSeed.SlotLive }), Scheduled("REMINDER", extra: new { class_schedule_id = NotificationsSeed.SlotLive, offset_minutes = "abc" }),
            Scheduled("REMINDER", extra: new { class_schedule_id = NotificationsSeed.SlotLive, offset_minutes = 10081 }), Scheduled("REMINDER", extra: new { class_schedule_id = NotificationsSeed.SlotLive, offset_minutes = -10081 }),
        };
        foreach (var body in cases)
        {
            await run.AsAsync(Sender, Post, path, body);
        }

        await Rows(run, "nothing stored");
    }

    // Twenty active notifications in a class is the most; the class is filled on this copy, so the file shows the answer and the count, not twenty rows.
    private static async Task ScheduledCreateCapAsync(NotificationsRun run)
    {
        await run.Run.ExecuteAsync(
            "insert into notifications.class_scheduled_notifications (class_id, created_by, created_by_user_id, title, body, kind, send_at, tz, status, created_at, updated_at) "
            + $"select {NotificationsSeed.ClassBare}, {Sender}, (select id from identity.users where token = {Sender}), 'Filler ' || n, 'Body', 'ONCE', timestamp '2026-06-01 10:00:00', 'UTC', 'active', "
            + "timestamptz '2025-12-20 08:00:00+00', timestamptz '2025-12-20 08:00:00+00' from generate_series(1, 20) n");
        var path = ClassPath(NotificationsSeed.ClassBare, "notifications/scheduled");
        await run.AsAsync(Sender, Post, path, Scheduled("ONCE", extra: new { send_at = "2026-03-01T10:00" }));
        await run.AsAsync(Sender, Delete, path + "/" + (await run.Run.QueryAsync($"select min(id) from notifications.class_scheduled_notifications where class_id = {NotificationsSeed.ClassBare}"))[0]);
        await run.AsAsync(Sender, Post, path, Scheduled("ONCE", extra: new { send_at = "2026-03-01T10:00" }));
        run.Run.Note("active in the class: " + (await run.Run.QueryAsync($"select count(*) from notifications.class_scheduled_notifications where class_id = {NotificationsSeed.ClassBare} and status = 'active'"))[0]);
    }

    // Twenty creates an hour per member: the class of the seed holds six, so twelve more fit, and twelve go to class four.
    private static async Task ScheduledCreateLimitAsync(NotificationsRun run)
    {
        for (var n = 1; n <= 12; n++)
        {
            await run.AsAsync(Sender, Post, ClassPath(NotificationsSeed.ClassOne, "notifications/scheduled"), Scheduled("ONCE", "Limit " + n, new { send_at = "2026-03-01T10:00" }));
        }

        for (var n = 1; n <= 9; n++)
        {
            await run.AsAsync(Sender, Post, ClassPath(NotificationsSeed.ClassBare, "notifications/scheduled"), Scheduled("ONCE", "Limit bare " + n, new { send_at = "2026-03-01T10:00" }));
        }

        await Rows(run, "twenty created, the 21st refused");
    }

    private static async Task ScheduledDeleteAsync(NotificationsRun run)
    {
        var one = ClassPath(NotificationsSeed.ClassOne, "notifications/scheduled");
        await run.AsAsync(Sender, Delete, one + "/2");
        await Rows(run, "scheduled 2 deleted");
        await run.AsAsync(Sender, Delete, one + "/2");
        await run.AsAsync(Sender, Delete, one + "/7");
        await run.AsAsync(Sender, Delete, one + "/abc");
        await run.AsAsync(Sender, Delete, one + "/0");
        await run.AsAsync(Plain, Delete, one + "/3");
        await run.AsAsync(Teacher2, Delete, one + "/3");
        await run.AsGuestAsync(Delete, one + "/3");
        await run.AsNobodyAsync(Delete, one + "/3");
        await run.AsAsync(Sender, Delete, ClassPath(99999, "notifications/scheduled/3"));
        await run.AsAsync(Admin, Delete, one + "/1");
        await Rows(run, "the refusals, and scheduled 1 deleted by the administrator");
    }

    // ---- the calendar ----

    private static async Task CalendarGetAsync(NotificationsRun run)
    {
        foreach (var member in (int[])[Student, Student3, Plain, Ladies, Removed, Admin])
        {
            await run.AsAsync(member, Get, "/me/calendar");
        }

        await run.AsGuestAsync(Get, "/me/calendar");
        await run.AsNobodyAsync(Get, "/me/calendar");
    }

    private static async Task CalendarSyncWritesAsync(NotificationsRun run)
    {
        const string path = "/me/calendar/settings";
        await run.AsAsync(Student, Put, path, Batch(KeyA, Change("event:1", "2026-01-01T00:00:00Z", -30)));
        await Rows(run, "event:1 changed by a newer client time");
        await run.AsAsync(Student, Put, path, Batch(KeyB, Change("event:1", "2019-01-01T00:00:00.5Z", -5)));
        await run.AsAsync(Student, Put, path, Batch(KeyA, Change("event:2", "2026-06-01T10:00:00Z", deleted: false, muted: true)));
        await Rows(run, "a tombstone never cleared, an older change lost");
        await run.AsAsync(Student, Put, path, Batch(KeyB, Change($"slot:{NotificationsSeed.SlotLive}", "2025-12-22T10:00:00Z", -15)));
        await run.AsAsync(Student, Put, path, Batch(KeyLow, Change($"slot:{NotificationsSeed.SlotLive}", "2025-12-22T10:00:00Z", -15)));
        await run.AsAsync(Student, Put, path, Batch(KeyB, Change($"slot:{NotificationsSeed.SlotOther}", "2026-01-01T00:10:00Z", 0, deleted: true)));
        await run.AsAsync(Student, Put, path, Batch(KeyA, Change("event:1", "2026-01-01T00:04:59.999Z", -60), Change("event:99", "2026-01-01T00:00:00Z"), Change($"slot:{NotificationsSeed.SlotDeleted}", "2026-01-01T00:00:00Z")));
        await run.AsAsync(Student, Put, path, Batch(KeyA, Change("event:3", "2026-01-01T00:00:00Z"), Change("event:4", "2026-01-01T00:00:00Z")));
        await run.AsAsync(Student3, Put, path, Batch(KeyB, Change("event:4", "2026-01-01T00:00:00.123Z", -1440, muted: true)));
        await run.AsAsync(Plain, Put, path, Batch(KeyA, Change("event:1", "2026-01-01T00:00:00Z")));
        await run.AsAsync(Student, Get, "/me/calendar");
        await Rows(run, "the rest");
    }

    private static async Task CalendarSyncRefusedAsync(NotificationsRun run)
    {
        const string path = "/me/calendar/settings";
        await run.AsNobodyAsync(Put, path, Batch(KeyA));
        var good = Change("event:1", "2026-01-01T00:00:00Z", -5);
        var cases = new[]
        {
            "nope", "[1]", "{}", """{"device_key":"short","changes":[]}""", """{"device_key":5,"changes":[]}""", $$"""{"device_key":"{{KeyA}}"}""", $$"""{"device_key":"{{KeyA}}","changes":null}""",
            $$"""{"device_key":"{{KeyA}}","changes":"x"}""", $$$$"""{"device_key":"{{{{KeyA}}}}","changes":{"0":{}}}""", $$$"""{"device_key":"{{{KeyA}}}","changes":{}}""", Batch(KeyA), Batch(KeyA, "5"), Batch(KeyA, "[1]"),
            Batch(KeyA, """{"muted":false,"deleted":false,"client_updated_at":"2026-01-01T00:00:00Z"}"""), Batch(KeyA, """{"event_key":5}"""), Batch(KeyA, Change("Event:1", "2026-01-01T00:00:00Z")),
            Batch(KeyA, Change("event:01", "2026-01-01T00:00:00Z")), Batch(KeyA, Change("event:1", "2026-01-01T00:00:00Z", 7)), Batch(KeyA, Change("event:1", "2026-01-01T00:00:00Z", "5")),
            Batch(KeyA, """{"event_key":"event:1","muted":"yes","deleted":false,"client_updated_at":"2026-01-01T00:00:00Z"}"""), Batch(KeyA, """{"event_key":"event:1","muted":false,"client_updated_at":"2026-01-01T00:00:00Z"}"""),
            Batch(KeyA, Change("event:1", "yesterday")), Batch(KeyA, Change("event:1", "2026-02-31T00:00:00Z")), Batch(KeyA, Change("event:1", "0000-01-01T00:00:00Z")), Batch(KeyA, Change("event:1", "2026-01-01T00:00:00+05:30")),
            Batch(KeyA, good, "7"),
        };
        foreach (var body in cases)
        {
            await run.AsAsync(Student, Put, path, body);
        }

        await Rows(run, "nothing stored");
    }

    // A good change followed by a bad one: the whole batch is refused and the first is not kept.
    private static async Task CalendarSyncBatchRefusedAsync(NotificationsRun run)
    {
        await run.AsAsync(Student, Put, "/me/calendar/settings", Batch(KeyA, Change("event:1", "2026-01-01T00:00:00Z", -60), Change("event:1", "bad")));
        await Rows(run, "nothing of the batch kept");
    }

    private static async Task CalendarSync200Async(NotificationsRun run)
    {
        var change = Change("event:99", "2026-01-01T00:00:00Z");
        await run.AsAsync(Student, Put, "/me/calendar/settings", Batch(KeyA, Enumerable.Repeat(change, 200).ToArray()));
        await run.AsAsync(Student, Put, "/me/calendar/settings", Batch(KeyA, Enumerable.Repeat(change, 201).ToArray()));
    }

    private static async Task EventsListAsync(NotificationsRun run)
    {
        var one = ClassPath(NotificationsSeed.ClassOne, "scheduled-events");
        await run.AsAsync(Sender, Get, one);
        await run.AsAsync(Admin, Get, one);
        await run.AsAsync(Teacher2, Get, ClassPath(NotificationsSeed.ClassTwo, "scheduled-events"));
        await run.AsAsync(Sender, Get, ClassPath(NotificationsSeed.ClassBare, "scheduled-events"));
        await run.AsAsync(Taker, Get, one);
        await run.AsAsync(Plain, Get, one);
        await run.AsGuestAsync(Get, one);
        await run.AsNobodyAsync(Get, one);
        await run.AsAsync(Sender, Get, ClassPath(99999, "scheduled-events"));
        await run.AsAsync(Sender, Get, "/classes/abc/scheduled-events");
    }

    private static async Task EventCreateAsync(NotificationsRun run)
    {
        var path = ClassPath(NotificationsSeed.ClassOne, "scheduled-events");
        await run.AsAsync(Sender, Post, path, Event(Odd, description: "Described " + Odd, link: "https://youtu.be/abc_DEF-1?t=5"));
        await Rows(run, "an event");
        await run.AsAsync(Sender, Post, path, Event("  Padded  ", (int[])[5, 1, 3, 1], "07:05", "Asia/Calcutta"));
        await run.AsAsync(Sender, Post, path, Event("Object weekdays", new { a = 2, b = 6 }, "23:59", "Europe/London"));
        await run.AsAsync(Admin, Post, path, Event("Admin event", (int[])[7], "00:00", "UTC"));
        await Rows(run, "the rest");
    }

    private static async Task EventCreateRefusedAsync(NotificationsRun run)
    {
        var path = ClassPath(NotificationsSeed.ClassOne, "scheduled-events");
        await run.AsAsync(Plain, Post, path, Event());
        await run.AsAsync(Teacher2, Post, path, Event());
        await run.AsAsync(Taker, Post, path, Event());
        await run.AsGuestAsync(Post, path, Event());
        await run.AsNobodyAsync(Post, path, Event());
        await run.AsAsync(Sender, Post, ClassPath(99999, "scheduled-events"), Event());
        await run.AsAsync(Sender, Post, "/classes/abc/scheduled-events", Event());
        var cases = new[]
        {
            "nope", "[1]", "{}", Event(" "), Event(new string('m', 501)), Event("a\0b"), Event(description: new string('d', 2001)), Event(time: "7:30"), Event(time: "24:00"), Event(link: "javascript:x"),
            Event(weekdays: (int[])[]), Event(weekdays: (int[])[0]), Event(weekdays: (int[])[8]), Event(weekdays: (int[])[1, 2, 3, 4, 5, 6, 7, 1]), Event(weekdays: (string[])["1"]), Event(timezone: null), Event(timezone: "Mars/Phobos"),
            """{"message":"M","weekdays":[1],"send_time":"07:30","timezone":5}""", """{"message":"M","description":5,"weekdays":[1],"send_time":"07:30","timezone":"UTC"}""",
        };
        foreach (var body in cases)
        {
            await run.AsAsync(Sender, Post, path, body);
        }

        await Rows(run, "nothing stored");
    }

    // The most events a class holds is 500: the class is filled on this copy, so the file shows the answer and the count, not 500 rows.
    private static async Task EventCreateCapAsync(NotificationsRun run)
    {
        await run.Run.ExecuteAsync(
            "insert into notifications.class_scheduled_events (class_id, created_by, created_by_user_id, message, weekdays, send_time, tz, status, created_at, updated_at) "
            + $"select {NotificationsSeed.ClassTwo}, {Teacher2}, (select id from identity.users where token = {Teacher2}), 'Filler ' || n, '1', time '07:00', 'UTC', 'active', "
            + "timestamptz '2025-12-15 08:00:00+00', timestamptz '2025-12-15 08:00:00+00' from generate_series(1, 498) n");
        var path = ClassPath(NotificationsSeed.ClassTwo, "scheduled-events");
        await run.AsAsync(Teacher2, Post, path, Event("The 500th, one still free"));
        await run.AsAsync(Teacher2, Post, path, Event("The 501st"));
        run.Run.Note("active in the class: " + (await run.Run.QueryAsync($"select count(*) from notifications.class_scheduled_events where class_id = {NotificationsSeed.ClassTwo} and status = 'active'"))[0]);
    }

    private static async Task EventUpdateAsync(NotificationsRun run)
    {
        var one = ClassPath(NotificationsSeed.ClassOne, "scheduled-events");
        await run.AsAsync(Sender, Patch, one + "/1", J(new { message = "Changed " + Odd }));
        await Rows(run, "event 1, the message");
        await run.AsAsync(Sender, Patch, one + "/1", """{"description":null,"action_link":null}""");
        await run.AsAsync(Sender, Patch, one + "/1", J(new { weekdays = (int[])[6, 2], send_time = "21:15", timezone = "UTC" }));
        await run.AsAsync(Sender, Patch, one + "/1", "{}");
        await run.AsAsync(Sender, Patch, one + "/1", "[1]");
        await run.AsAsync(Admin, Patch, one + "/2", J(new { message = "Taken over", action_link = "https://www.thestrongrope.com/articles/abc" }));
        await run.AsAsync(Sender, Patch, one + "/2", J(new { description = "Taken over by the teacher" }));
        await Rows(run, "the rest");
    }

    private static async Task EventUpdateRefusedAsync(NotificationsRun run)
    {
        var one = ClassPath(NotificationsSeed.ClassOne, "scheduled-events");
        await run.AsAsync(Admin, Patch, one + "/1", J(new { message = "Not yours" }));
        await run.AsAsync(Plain, Patch, one + "/1", J(new { message = "x" }));
        await run.AsAsync(Teacher2, Patch, one + "/1", J(new { message = "x" }));
        await run.AsGuestAsync(Patch, one + "/1", J(new { message = "x" }));
        await run.AsNobodyAsync(Patch, one + "/1", J(new { message = "x" }));
        await run.AsAsync(Sender, Patch, one + "/3", J(new { message = "deleted event" }));
        await run.AsAsync(Sender, Patch, one + "/4", J(new { message = "another class" }));
        await run.AsAsync(Sender, Patch, one + "/99", J(new { message = "unknown" }));
        await run.AsAsync(Sender, Patch, one + "/abc", J(new { message = "no id" }));
        foreach (var body in new[] { "nope", """{"message":null}""", """{"message":" "}""", """{"description":5}""", """{"send_time":"99:99"}""", """{"weekdays":[]}""", """{"weekdays":[9]}""", """{"action_link":"javascript:x"}""" })
        {
            await run.AsAsync(Sender, Patch, one + "/1", body);
        }

        await Rows(run, "nothing stored");
    }

    private static async Task EventUpdateBadZoneAsync(NotificationsRun run)
    {
        await run.Run.ExecuteAsync("update notifications.class_scheduled_events set tz = 'Bad/Zone' where id = 1");
        await run.AsAsync(Sender, Patch, ClassPath(NotificationsSeed.ClassOne, "scheduled-events/1"), J(new { message = "x" }));
        await Rows(run, "nothing stored");
    }

    private static async Task EventDeleteAsync(NotificationsRun run)
    {
        var one = ClassPath(NotificationsSeed.ClassOne, "scheduled-events");
        await run.AsAsync(Admin, Delete, one + "/1");
        await run.AsAsync(Plain, Delete, one + "/1");
        await run.AsAsync(Teacher2, Delete, one + "/1");
        await run.AsGuestAsync(Delete, one + "/1");
        await run.AsNobodyAsync(Delete, one + "/1");
        await run.AsAsync(Sender, Delete, one + "/4");
        await run.AsAsync(Sender, Delete, one + "/3");
        await run.AsAsync(Sender, Delete, one + "/abc");
        await run.AsAsync(Sender, Delete, one + "/1");
        await Rows(run, "event 1 deleted by its owner");
        await run.AsAsync(Sender, Delete, one + "/1");
        await run.AsAsync(Admin, Delete, one + "/2");
        await Rows(run, "event 2 taken over and deleted");
    }

    // ---- the pushes ----

    private static async Task PushSendClassLevelAsync(NotificationsRun run)
    {
        await run.AsAsync(Admin, Post, "/notifications/send", Announcement("CLASS_LEVEL", (int[])[2, 99], Odd, "Body " + Odd, "https://www.thestrongrope.com/articles/a-pasted-article"));
        await Rows(run, "a CLASS_LEVEL announcement");
        await run.AsAsync(Admin, Post, "/notifications/send", Announcement("CLASS_LEVEL", new { a = 3 }, "Object value", "Level three", string.Empty));
        await Rows(run, "an object of levels and an empty link");
    }

    private static async Task PushSendGenderAsync(NotificationsRun run)
    {
        await run.AsAsync(Admin, Post, "/notifications/send", Announcement("GENDER", (string[])["1"], "Gents", "For gents"));
        await run.AsAsync(Admin, Post, "/notifications/send", Announcement("GENDER", (int[])[2], "Ladies", "For ladies", "/classes/98505/syllabus"));
        await run.AsAsync(Admin, Post, "/notifications/send", Announcement("GENDER", (string[])["x"], "Nobody", "No such gender"));
        await run.AsAsync(Admin, Post, "/notifications/send", Announcement("GENDER", (int[])[3], "Nobody", "Gender three"));
        await Rows(run, "gender announcements");
    }

    private static async Task PushSendTeachersAsync(NotificationsRun run)
    {
        await run.AsAsync(Admin, Post, "/notifications/send", Announcement("TEACHERS", (int[])[NotificationsSeed.ClassOne], "Teachers", "Of a class"));
        await run.AsAsync(Admin, Post, "/notifications/send", Announcement("TEACHERS", (int[])[], "Every teacher", "Of every active class"));
        await Rows(run, "teacher announcements");
    }

    // Every device, the dead (-gone) and the busy (-busy) ones included, and a body of 600 characters with an emoji across the cut at 500.
    private static async Task PushSendAllAsync(NotificationsRun run)
    {
        var longBody = new string('b', 499) + "🙂" + new string('c', 100);
        await run.AsAsync(Admin, Post, "/notifications/send", Announcement("ALL_USERS", null, Odd, longBody));
        await Rows(run, "ALL_USERS with a long body");
    }

    private static async Task PushSendNoDevicesAsync(NotificationsRun run)
    {
        await run.AsAsync(Admin, Post, "/notifications/send", Announcement("CLASS_LEVEL", (int[])[77]));
        await run.AsAsync(Admin, Post, "/notifications/send", Announcement("TEACHERS", (int[])[NotificationsSeed.ClassBare]));
        await Rows(run, "no devices: nothing stored");
    }

    private static async Task PushClassSendAsync(NotificationsRun run)
    {
        await run.AsAsync(Sender, Post, ClassPath(NotificationsSeed.ClassOne), J(new { title = " Padded " + Odd + " ", body = "Body " + Odd }));
        await Rows(run, "a class send, the link left to the default");
        await run.AsAsync(Sender, Post, ClassPath(NotificationsSeed.ClassOne), J(new { title = "With link", body = "Body", action_link = "/classes/98501/syllabus" }));
        await run.AsAsync(Teacher2, Post, ClassPath(NotificationsSeed.ClassTwo), J(new { title = "Busy device", body = "A device that fails" }));
        await run.AsAsync(Admin, Post, ClassPath(NotificationsSeed.ClassOne), J(new { title = "By the administrator", body = "Any class" }));
        // A NUL at the end of the title is trimmed away before the NUL check (PhpText.Trim strips it, as PHP's trim does), so this is accepted and pushed as "Trailing".
        await run.AsAsync(Sender, Post, ClassPath(NotificationsSeed.ClassOne), """{"title":"Trailing\u0000","body":"B"}""");
        await Rows(run, "the rest");
    }

    private static async Task PushClassSendNoDevicesAsync(NotificationsRun run)
    {
        await run.AsAsync(Sender, Post, ClassPath(NotificationsSeed.ClassBare), J(new { title = "T", body = "B" }));
        await Rows(run, "nothing stored");
    }

    private static async Task PushCleanupAsync(NotificationsRun run)
    {
        await run.AsAsync(Admin, Post, "/notifications/cleanup-invalid-tokens");
        await Rows(run, "the dead token removed, the busy one kept");
        await run.AsAsync(Admin, Post, "/notifications/cleanup-invalid-tokens");
        await Rows(run, "a second cleanup");
    }

    private static async Task PushCleanupNoTokensAsync(NotificationsRun run)
    {
        await run.Run.ExecuteAsync("delete from notifications.user_devices");
        await run.AsAsync(Admin, Post, "/notifications/cleanup-invalid-tokens");
        await Rows(run, "no devices");
    }
}
