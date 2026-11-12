using System.Collections.Concurrent;
using System.Globalization;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using NUnit.Framework;
using Tsr.Access.Api;
using Tsr.Notifications.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Notifications.Api.Workers;

namespace Tsr.Db.Tests;

/// <summary>
/// The scheduled class notification worker (PHP cli/run_due_class_notifications.php, ClassScheduledNotificationWorker) against a real database as the limited role, with a fixed clock: a tick is called
/// directly, never the timer loop. Nothing is sent here: the worker queues pushes for the push drain, so the tests read the queue and the ledgers.
/// World: class 9271 (active, teacher 927121) with students 927131 (devices dev-s1, dev-s1b), 927132 (enrolment removed, dev-s2), 927133 (demo member, dev-s3), 927134 (no device); class 9272 closed;
/// member 927122 teaches nothing (a creator who has lost the right). Class 9271 meets Thursday (4) 18:00 UTC (slot 927101). The clock starts on Thursday 2026-11-12 10:00 UTC.
/// </summary>
public sealed class TestClassScheduleWorkerTests
{
    private const int Teacher = 927121;
    private const int Outsider = 927122;
    private const int S1 = 927131;
    private const int S2 = 927132;
    private const int S3 = 927133;
    private const int S4 = 927134;
    private const int ClassId = 9271;
    private const int ClosedClass = 9272;
    private const int SlotId = 927101;
    private const string Title = "Sched Title Xylophone";
    private const string Body = "Sched body Zebra";

    private sealed class MovableClock(DateTimeOffset now) : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = now;

        public override DateTimeOffset GetUtcNow() => Now;
    }

    private sealed class CaptureLog : ILogger
    {
        public ConcurrentQueue<string> Lines { get; } = new();

        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            Lines.Enqueue(formatter(state, exception));
    }

    private static readonly DateTimeOffset T0 = DateTimeOffset.Parse("2026-11-12T10:00:00+00:00", CultureInfo.InvariantCulture);

    private MovableClock clock = null!;
    private CaptureLog log = null!;
    private WebApplicationFactory<Program> factory = null!;
    private int teacherUserId;
    private int outsiderUserId;

    [SetUp]
    public async Task SeedAsync()
    {
        clock = new MovableClock(T0);
        log = new CaptureLog();
        await MembershipTestKit.ResetAsync();
        await DropTriggersAsync();
        await TestDatabase.ExecuteAsync(
            "truncate access.user_roles, access.class_access_rule_conditions, access.class_access_rules restart identity cascade; "
            + "truncate platform.outbox, platform.outbound_messages, notifications.user_notifications, notifications.notifications, notifications.user_devices, "
            + "notifications.class_scheduled_notification_runs, notifications.class_scheduled_notifications, classes.class_schedules, classes.class_students, classes.classes restart identity cascade");
        teacherUserId = await MembershipTestKit.AddMemberAsync(Teacher, "Sw Teacher", "1");
        outsiderUserId = await MembershipTestKit.AddMemberAsync(Outsider, "Sw Outsider", "1");
        foreach (var token in new[] { S1, S2, S3, S4 })
        {
            await MembershipTestKit.AddMemberAsync(token, "Sw Student " + token, "1");
        }

        await TestDatabase.ExecuteAsync(
            $"update identity.users set email = 'm{S3}@demo.invalid' where token = {S3}; "
            + "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by, city) values "
            + $"({ClassId}, 'SW-1', 1, 'swl1', 'Sw One', 3, {Teacher}, 1, 'Offline', 'A', {Teacher}, 'Swville'), ({ClosedClass}, 'SW-2', 1, 'swl2', 'Sw Closed', 3, {Teacher}, 1, 'Offline', 'I', {Teacher}, 'Swville'); "
            + "insert into classes.class_students (class_id, token_no, joined_on, mcq_admin, status, removed_at) values "
            + $"({ClassId}, {S1}, current_date, 0, 'A', null), ({ClassId}, {S2}, current_date, 0, 'A', '2025-10-01'), ({ClassId}, {S3}, current_date, 0, 'A', null), ({ClassId}, {S4}, current_date, 0, 'A', null); "
            + $"insert into classes.class_schedules (id, class_id, day, hour, minute, timezone) values ({SlotId}, {ClassId}, 4, 18, 0, 'UTC'); "
            + "insert into notifications.user_devices (token, device_id) values "
            + $"({S1}, 'dev-s1'), ({S1}, 'dev-s1b'), ({S2}, 'dev-s2'), ({S3}, 'dev-s3')");
        factory = TestApi.Create().WithWebHostBuilder(builder => builder.ConfigureTestServices(services => services.AddSingleton<TimeProvider>(clock)));
    }

    [TearDown]
    public async Task StopAsync()
    {
        factory.Dispose();
        await DropTriggersAsync();
    }

    private static async Task DropTriggersAsync() =>
        await TestDatabase.ExecuteAsync(
            "drop trigger if exists tsr_test_fail on notifications.notifications; drop trigger if exists tsr_test_fail on platform.outbound_messages; "
            + "create or replace function public.tsr_test_fail() returns trigger language plpgsql as $$ begin raise exception 'test failure'; end $$");

    private static async Task FailOnInsertAsync(string table) =>
        await TestDatabase.ExecuteAsync($"create trigger tsr_test_fail before insert on {table} for each row execute function public.tsr_test_fail()");

    private static async Task StopFailingAsync(string table) =>
        await TestDatabase.ExecuteAsync($"drop trigger tsr_test_fail on {table}");

    private async Task<ScheduleReport> TickAsync()
    {
        await using var scope = factory.Services.CreateAsyncScope();
        return await ClassScheduleSend.TickAsync(
            scope.ServiceProvider.GetRequiredService<NotificationsContext>(), scope.ServiceProvider.GetRequiredService<Permissions>(), clock, log, CancellationToken.None);
    }

    private static string Quote(string? value) => value is null ? "null" : "'" + value.Replace("'", "''", StringComparison.Ordinal) + "'";

    private async Task<int> AddAsync(
        string kind,
        string? sendAt = null,
        string? weekdays = null,
        string? sendTime = null,
        string tz = "UTC",
        int? slot = null,
        int? offset = null,
        int repeat = 0,
        int classId = ClassId,
        int creator = Teacher,
        string createdAt = "2026-01-01T00:00:00+00:00") =>
        await TestDatabase.ScalarAsync<int>(
            "insert into notifications.class_scheduled_notifications (class_id, created_by, created_by_user_id, title, body, action_link, kind, send_at, weekdays, send_time, tz, class_schedule_id, offset_minutes, repeat_weekly, status, created_at) values "
            + $"({classId}, {creator}, {(creator == Teacher ? teacherUserId : outsiderUserId)}, {Quote(Title)}, {Quote(Body)}, null, {Quote(kind)}, {Quote(sendAt)}, {Quote(weekdays)}, {Quote(sendTime)}, {Quote(tz)}, {(slot is null ? "null" : slot.Value.ToString(CultureInfo.InvariantCulture))}, "
            + $"{(offset is null ? "null" : offset.Value.ToString(CultureInfo.InvariantCulture))}, {repeat}, 'active', '{createdAt}') returning id",
            TestDatabase.OwnerConnection);

    private Task<int> AddOnceAsync(string sendAt = "2026-11-12 09:30:00", int classId = ClassId, int creator = Teacher, string tz = "UTC") =>
        AddAsync("ONCE", sendAt: sendAt, classId: classId, creator: creator, tz: tz);

    private static async Task<string> TextAsync(string sql) => await TestDatabase.ScalarAsync<string>(sql, TestDatabase.OwnerConnection);

    private static Task<long> CountAsync(string table, string where = "true") => MembershipTestKit.CountAsync(table, where);

    private static Task<string> StatusAsync(int id) => TextAsync($"select status::text from notifications.class_scheduled_notifications where id = {id}");

    private static Task<string> ReasonsAsync(int id) =>
        TextAsync($"select coalesce(string_agg(coalesce(skipped_reason::text, 'sent'), ',' order by id), '') from notifications.class_scheduled_notification_runs where scheduled_id = {id}");

    private static Task<long> PushRowsAsync() => CountAsync("platform.outbound_messages", "channel = 'push'");

    // ---- firing ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task A_due_once_fires_one_push_per_device_of_the_current_students_and_is_done()
    {
        var id = await AddOnceAsync();

        var report = await TickAsync();

        Assert.That(report.Fired, Is.EqualTo(1));
        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
        Assert.That(await TextAsync($"select string_agg(recipient::text, ',' order by recipient) from platform.outbound_messages where channel = 'push'"), Is.EqualTo("dev-s1,dev-s1b"), "a removed student's and a demo member's device get nothing");
        var run = (await TestDatabase.RowAsync($"select student_count, device_count, success_count, failure_count, skipped_reason, notification_id is not null as has_notification from notifications.class_scheduled_notification_runs where scheduled_id = {id}"))!;
        Assert.That(run["student_count"], Is.EqualTo("3"), "enrolled students with a token: 927131, the demo member and 927134");
        Assert.That(run["device_count"], Is.EqualTo("2"));
        Assert.That(run["success_count"], Is.EqualTo("0"));
        Assert.That(run["failure_count"], Is.EqualTo("0"));
        Assert.That(run["skipped_reason"], Is.Null);
        Assert.That(run["has_notification"], Is.EqualTo("true"));
        var key = await TextAsync($"select last_run_key::text from notifications.class_scheduled_notifications where id = {id}");
        Assert.That(key, Is.EqualTo("once:" + DateTimeOffset.Parse("2026-11-12T09:30:00+00:00", CultureInfo.InvariantCulture).ToUnixTimeSeconds()));
    }

    [Test]
    public async Task The_inbox_copy_goes_to_every_enrolled_student_and_the_criteria_name_the_schedule_and_slot()
    {
        var id = await AddOnceAsync();

        await TickAsync();

        var notification = (await TestDatabase.RowAsync("select notification_id, created_by, device_count, success_count, failure_count, action_link::text as link, target_audience_criteria::text as criteria from notifications.notifications"))!;
        Assert.That(notification["created_by"], Is.EqualTo(Teacher.ToString(CultureInfo.InvariantCulture)));
        Assert.That(notification["device_count"], Is.EqualTo("2"));
        Assert.That(notification["success_count"], Is.EqualTo("0"));
        Assert.That(notification["link"], Is.EqualTo($"/classes/{ClassId}/dashboard"));
        var criteria = JsonElement.Parse(notification["criteria"]!);
        Assert.That(criteria.GetProperty("source").GetString(), Is.EqualTo("scheduled"));
        Assert.That(criteria.GetProperty("schedule_id").GetInt32(), Is.EqualTo(id));
        Assert.That(criteria.GetProperty("class_id").GetInt32(), Is.EqualTo(ClassId));
        Assert.That(await TextAsync($"select string_agg(user_token::text, ',' order by user_token) from notifications.user_notifications where notification_id = {notification["notification_id"]}"), Is.EqualTo($"{S1},{S3},{S4}"));
    }

    [Test]
    public async Task The_queued_rows_carry_the_slot_dedupe_key_and_a_deadline_two_hours_after_the_slot()
    {
        var id = await AddOnceAsync();

        await TickAsync();

        var slot = DateTimeOffset.Parse("2026-11-12T09:30:00+00:00", CultureInfo.InvariantCulture);
        Assert.That(await CountAsync("platform.outbound_messages", $"channel = 'push' and dedupe_key like 'class-sched-{id}-once:{slot.ToUnixTimeSeconds()}:%' and status = 'queued' and created_by = {Teacher}"), Is.EqualTo(2));
        var payload = JsonElement.Parse(await TextAsync("select payload::text from platform.outbound_messages order by id limit 1"));
        Assert.That(payload.GetProperty("title").GetString(), Is.EqualTo(Title));
        Assert.That(DateTimeOffset.Parse(payload.GetProperty("deadline").GetString()!, CultureInfo.InvariantCulture), Is.EqualTo(slot.AddHours(2)));
        var data = payload.GetProperty("data");
        Assert.That(data.GetProperty("type").GetString(), Is.EqualTo("class_announcement"));
        Assert.That(data.GetProperty("sent_at").GetString(), Is.EqualTo("2026-11-12T09:30:00"));
        Assert.That(data.GetProperty("class_id").GetString(), Is.EqualTo("9271"));
        Assert.That(data.GetProperty("action_link").GetString(), Is.Empty);
    }

    [Test]
    public async Task The_same_tick_twice_queues_nothing_more()
    {
        var id = await AddOnceAsync();
        await TickAsync();

        var second = await TickAsync();

        Assert.That(second.Fired, Is.Zero);
        Assert.That(await PushRowsAsync(), Is.EqualTo(2));
        Assert.That(await CountAsync("notifications.notifications"), Is.EqualTo(1));
        Assert.That(await ReasonsAsync(id), Is.EqualTo("sent"));
    }

    [Test]
    public async Task A_once_that_is_not_due_yet_is_left_alone()
    {
        var id = await AddOnceAsync("2026-11-12 10:30:00");

        var report = await TickAsync();

        Assert.That(report.Fired, Is.Zero);
        Assert.That(await StatusAsync(id), Is.EqualTo("active"));
        Assert.That(await PushRowsAsync(), Is.Zero);
    }

    [Test]
    public async Task A_once_is_read_in_its_own_zone()
    {
        // 15:30 in Asia/Kolkata (UTC+5:30) is 10:00 UTC.
        var id = await AddOnceAsync("2026-11-12 15:30:00", tz: "Asia/Kolkata");

        await TickAsync();

        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
    }

    [Test]
    public async Task A_weekly_slot_fires_and_stays_active_and_fires_again_next_week()
    {
        var id = await AddAsync("WEEKLY", weekdays: "4", sendTime: "09:30:00");

        await TickAsync();
        await TickAsync();

        Assert.That(await StatusAsync(id), Is.EqualTo("active"));
        Assert.That(await ReasonsAsync(id), Is.EqualTo("sent"));
        Assert.That(await PushRowsAsync(), Is.EqualTo(2));
        Assert.That(await CountAsync("platform.outbox", "event_type = 'notifications.sent'"), Is.EqualTo(1), "the second tick inside the grace window writes nothing");

        clock.Now = T0.AddDays(7);
        await TickAsync();

        Assert.That(await ReasonsAsync(id), Is.EqualTo("sent,sent"));
        Assert.That(await PushRowsAsync(), Is.EqualTo(4));
        Assert.That(await CountAsync("notifications.notifications"), Is.EqualTo(2));
    }

    [Test]
    public async Task A_reminder_follows_the_class_slot_and_its_offset_and_a_one_off_one_is_done()
    {
        // The class meets Thursday 18:00 UTC; 30 minutes before is 17:30.
        var id = await AddAsync("REMINDER", slot: SlotId, offset: -30, createdAt: "2026-11-12T00:00:00+00:00");

        clock.Now = DateTimeOffset.Parse("2026-11-12T17:00:00+00:00", CultureInfo.InvariantCulture);
        await TickAsync();
        Assert.That(await ReasonsAsync(id), Is.Empty, "not yet");

        clock.Now = DateTimeOffset.Parse("2026-11-12T17:45:00+00:00", CultureInfo.InvariantCulture);
        await TickAsync();

        Assert.That(await ReasonsAsync(id), Is.EqualTo("sent"));
        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
        var key = await TextAsync($"select last_run_key::text from notifications.class_scheduled_notifications where id = {id}");
        Assert.That(key, Is.EqualTo("rem:" + DateTimeOffset.Parse("2026-11-12T17:30:00+00:00", CultureInfo.InvariantCulture).ToUnixTimeSeconds()));
    }

    [Test]
    public async Task A_repeating_reminder_stays_active()
    {
        var id = await AddAsync("REMINDER", slot: SlotId, offset: -30, repeat: 1, createdAt: "2026-11-12T00:00:00+00:00");
        clock.Now = DateTimeOffset.Parse("2026-11-12T17:45:00+00:00", CultureInfo.InvariantCulture);

        await TickAsync();

        Assert.That(await StatusAsync(id), Is.EqualTo("active"));
        Assert.That(await ReasonsAsync(id), Is.EqualTo("sent"));
    }

    [Test]
    public async Task A_class_with_no_device_is_recorded_as_reached_nobody_and_a_once_is_done()
    {
        await TestDatabase.ExecuteAsync("truncate notifications.user_devices");
        var id = await AddOnceAsync();

        await TickAsync();

        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
        Assert.That(await ReasonsAsync(id), Is.EqualTo("sent"));
        Assert.That(await TextAsync($"select device_count::text || '/' || student_count::text from notifications.class_scheduled_notification_runs where scheduled_id = {id}"), Is.EqualTo("0/3"));
        Assert.That(await CountAsync("notifications.notifications"), Is.Zero);
        Assert.That(await PushRowsAsync(), Is.Zero);
    }

    // ---- missed -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task A_once_past_its_grace_is_finished_as_missed_window_and_sends_nothing()
    {
        var id = await AddOnceAsync("2026-11-12 07:59:00");

        await TickAsync();

        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
        Assert.That(await ReasonsAsync(id), Is.EqualTo("missed_window"));
        Assert.That(await PushRowsAsync(), Is.Zero);
    }

    [Test]
    public async Task A_lapsed_weekly_occurrence_records_one_missed_window_and_stays_active()
    {
        var id = await AddAsync("WEEKLY", weekdays: "4", sendTime: "06:00:00");

        await TickAsync();
        await TickAsync();

        Assert.That(await ReasonsAsync(id), Is.EqualTo("missed_window"));
        Assert.That(await StatusAsync(id), Is.EqualTo("active"));
        Assert.That(await PushRowsAsync(), Is.Zero);
    }

    [Test]
    public async Task A_lapsed_one_off_reminder_is_recorded_once_and_finished()
    {
        var id = await AddAsync("REMINDER", slot: SlotId, offset: 0);
        clock.Now = DateTimeOffset.Parse("2026-11-12T20:30:00+00:00", CultureInfo.InvariantCulture);

        await TickAsync();
        await TickAsync();

        Assert.That(await ReasonsAsync(id), Is.EqualTo("missed_window"));
        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
    }

    [Test]
    public async Task An_occurrence_before_the_row_was_created_is_not_missed()
    {
        var id = await AddAsync("WEEKLY", weekdays: "4", sendTime: "06:00:00", createdAt: "2026-11-12T07:00:00+00:00");

        await TickAsync();

        Assert.That(await ReasonsAsync(id), Is.Empty);
    }

    // ---- skips ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task A_reminder_whose_slot_is_gone_is_finished_as_schedule_missing()
    {
        var deleted = await AddAsync("REMINDER", slot: SlotId, offset: 0);
        var absent = await AddAsync("REMINDER", slot: 999999, offset: 0);
        await TestDatabase.ExecuteAsync($"update classes.class_schedules set deleted_at = now() where id = {SlotId}");

        await TickAsync();

        foreach (var id in new[] { deleted, absent })
        {
            Assert.That(await ReasonsAsync(id), Is.EqualTo("schedule_missing"));
            Assert.That(await StatusAsync(id), Is.EqualTo("done"));
        }
    }

    [Test]
    public async Task A_zone_that_does_not_exist_finishes_the_row_with_the_reason()
    {
        var once = await AddOnceAsync(tz: "Not/AZone");
        await TestDatabase.ExecuteAsync("insert into classes.class_schedules (id, class_id, day, hour, minute, timezone) values (927102, 9271, 4, 18, 0, 'Not/AZone')");
        var reminder = await AddAsync("REMINDER", slot: 927102, offset: 0);

        await TickAsync();

        Assert.That(await ReasonsAsync(once), Is.EqualTo("timezone_invalid"));
        Assert.That(await ReasonsAsync(reminder), Is.EqualTo("schedule_timezone_invalid"));
        Assert.That(await StatusAsync(once), Is.EqualTo("done"));
        Assert.That(await StatusAsync(reminder), Is.EqualTo("done"));
    }

    [Test]
    public async Task An_inactive_class_finishes_the_row_as_class_inactive()
    {
        var id = await AddOnceAsync(classId: ClosedClass);

        await TickAsync();

        Assert.That(await ReasonsAsync(id), Is.EqualTo("class_inactive"));
        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
        Assert.That(await PushRowsAsync(), Is.Zero);
    }

    [Test]
    public async Task A_creator_who_may_no_longer_send_for_the_class_finishes_the_row_as_creator_lost_permission()
    {
        var id = await AddOnceAsync(creator: Outsider);

        await TickAsync();

        Assert.That(await ReasonsAsync(id), Is.EqualTo("creator_lost_permission"));
        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
        Assert.That(await PushRowsAsync(), Is.Zero);
    }

    [Test]
    public async Task A_queue_that_refuses_is_recorded_once_and_retried_until_it_works()
    {
        var id = await AddOnceAsync();
        await FailOnInsertAsync("platform.outbound_messages");

        var first = await TickAsync();
        await TickAsync();

        Assert.That(first.Failed, Is.EqualTo(1));
        Assert.That(await ReasonsAsync(id), Is.EqualTo("queue_failed"), "one run row, not one a minute");
        Assert.That(await StatusAsync(id), Is.EqualTo("active"));

        await StopFailingAsync("platform.outbound_messages");
        await TickAsync();

        Assert.That(await ReasonsAsync(id), Is.EqualTo("queue_failed,sent"));
        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
        Assert.That(await PushRowsAsync(), Is.EqualTo(2));
    }

    // ---- crash recovery and concurrency --------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task A_failure_after_the_push_was_queued_leaves_no_duplicate_push_or_inbox_rows_after_the_retry()
    {
        var id = await AddOnceAsync();
        await FailOnInsertAsync("notifications.notifications");

        var first = await TickAsync();

        Assert.That(first.Failed, Is.EqualTo(1));
        Assert.That(await PushRowsAsync(), Is.EqualTo(2), "step 1 is done");
        Assert.That(await CountAsync("notifications.notifications"), Is.Zero);
        Assert.That(await ReasonsAsync(id), Is.EqualTo("dispatch_failed"));
        Assert.That(await StatusAsync(id), Is.EqualTo("active"));
        Assert.That(await TextAsync($"select coalesce((select last_run_key::text from notifications.class_scheduled_notifications where id = {id}), 'none')"), Is.EqualTo("none"));

        await StopFailingAsync("notifications.notifications");
        await TickAsync();

        Assert.That(await PushRowsAsync(), Is.EqualTo(2));
        Assert.That(await CountAsync("notifications.notifications"), Is.EqualTo(1));
        Assert.That(await CountAsync("notifications.user_notifications"), Is.EqualTo(3));
        Assert.That(await ReasonsAsync(id), Is.EqualTo("dispatch_failed,sent"));
        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
    }

    [Test]
    public async Task Two_ticks_at_once_fire_one_run()
    {
        var once = await AddOnceAsync();
        var weekly = await AddAsync("WEEKLY", weekdays: "4", sendTime: "09:30:00");

        await Task.WhenAll(TickAsync(), TickAsync());

        Assert.That(await ReasonsAsync(once), Is.EqualTo("sent"));
        Assert.That(await ReasonsAsync(weekly), Is.EqualTo("sent"));
        Assert.That(await PushRowsAsync(), Is.EqualTo(4));
        Assert.That(await CountAsync("notifications.notifications"), Is.EqualTo(2));
        Assert.That(await CountAsync("notifications.user_notifications"), Is.EqualTo(6));
    }

    // ---- limits ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    private static async Task AddRunsAsync(int count, string at) =>
        await TestDatabase.ExecuteAsync(
            "insert into notifications.class_scheduled_notification_runs (scheduled_id, class_id, run_at, device_count) "
            + $"select 0, {ClassId}, '{at}', 1 from generate_series(1, {count})");

    // The day limit (3) is lower than the hour limit (10), so the hour limit alone shows only across midnight: ten sends at 23:30, a slot at 00:00 with the clock at 00:15.
    [Test]
    public async Task Ten_sends_in_an_hour_hold_the_slot_and_it_goes_when_the_hour_passes()
    {
        var id = await AddOnceAsync("2026-11-12 00:00:00");
        await AddRunsAsync(10, "2026-11-11T23:30:00+00:00");
        clock.Now = DateTimeOffset.Parse("2026-11-12T00:15:00+00:00", CultureInfo.InvariantCulture);

        var held = await TickAsync();

        Assert.That(held.Held, Is.EqualTo(1));
        Assert.That(await StatusAsync(id), Is.EqualTo("active"));
        Assert.That(await PushRowsAsync(), Is.Zero);
        Assert.That(await CountAsync("notifications.class_scheduled_notification_runs"), Is.EqualTo(10), "a held slot writes nothing");

        clock.Now = DateTimeOffset.Parse("2026-11-12T00:45:00+00:00", CultureInfo.InvariantCulture);
        await TickAsync();

        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
        Assert.That(await PushRowsAsync(), Is.EqualTo(2));
    }

    [Test]
    public async Task Runs_that_sent_nothing_or_were_skipped_do_not_count_toward_the_limits()
    {
        var id = await AddOnceAsync();
        await TestDatabase.ExecuteAsync(
            "insert into notifications.class_scheduled_notification_runs (scheduled_id, class_id, run_at, device_count, skipped_reason) "
            + $"select 1, {ClassId}, '2026-11-12T09:45:00+00:00', 1, 'missed_window' from generate_series(1, 12); "
            + "insert into notifications.class_scheduled_notification_runs (scheduled_id, class_id, run_at, device_count) "
            + $"select 1, {ClassId}, '2026-11-12T09:45:00+00:00', 0 from generate_series(1, 12)");

        await TickAsync();

        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
    }

    [Test]
    public async Task Three_sends_in_a_day_hold_the_slot_and_it_goes_when_the_next_day_starts()
    {
        var id = await AddOnceAsync("2026-11-12 23:30:00");
        await AddRunsAsync(3, "2026-11-12T12:00:00+00:00");
        clock.Now = DateTimeOffset.Parse("2026-11-12T23:45:00+00:00", CultureInfo.InvariantCulture);

        var held = await TickAsync();

        Assert.That(held.Held, Is.EqualTo(1));
        Assert.That(await StatusAsync(id), Is.EqualTo("active"));
        Assert.That(await PushRowsAsync(), Is.Zero);

        clock.Now = DateTimeOffset.Parse("2026-11-13T00:10:00+00:00", CultureInfo.InvariantCulture);
        await TickAsync();

        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
        Assert.That(await PushRowsAsync(), Is.EqualTo(2));
    }

    [Test]
    public async Task A_held_slot_that_passes_its_grace_is_finished_as_missed()
    {
        var id = await AddOnceAsync("2026-11-12 00:00:00");
        await AddRunsAsync(10, "2026-11-11T23:30:00+00:00");
        clock.Now = DateTimeOffset.Parse("2026-11-12T00:15:00+00:00", CultureInfo.InvariantCulture);
        await TickAsync();
        Assert.That(await StatusAsync(id), Is.EqualTo("active"));

        clock.Now = DateTimeOffset.Parse("2026-11-12T02:01:00+00:00", CultureInfo.InvariantCulture);
        await TickAsync();

        Assert.That(await StatusAsync(id), Is.EqualTo("done"));
        Assert.That(await ReasonsAsync(id), Is.EqualTo("missed_window"));
    }

    // ---- bounds, logs, the writer ---------------------------------------------------------------------------------------------------------------------------------------------------------

    [Test]
    public async Task A_tick_reads_at_most_25_pages_of_200_rows()
    {
        await TestDatabase.ExecuteAsync(
            "insert into notifications.class_scheduled_notifications (class_id, created_by, created_by_user_id, title, body, kind, send_at, tz, status) "
            + $"select {ClassId}, {Teacher}, {teacherUserId}, 'bulk', 'bulk', 'ONCE', '2026-11-12 11:00:00', 'UTC', 'active' from generate_series(1, 5100)");

        var report = await TickAsync();

        Assert.That(report.Looked, Is.EqualTo(5000));
        Assert.That(await PushRowsAsync(), Is.Zero);
    }

    [Test]
    public async Task No_log_line_carries_a_title_a_body_or_a_device_token()
    {
        await AddOnceAsync();
        await AddAsync("REMINDER", slot: 999999, offset: 0);
        await FailOnInsertAsync("notifications.notifications");
        await AddOnceAsync("2026-11-12 09:40:00");
        await TickAsync();

        var lines = string.Join('\n', log.Lines);

        Assert.That(lines, Is.Not.Empty);
        Assert.That(lines, Does.Not.Contain("Xylophone").And.Not.Contain("Zebra").And.Not.Contain("dev-s1").And.Not.Contain("Sw Student").And.Not.Contain("test failure"));
    }

    [Test]
    public async Task A_notification_with_the_same_criteria_in_another_letter_case_is_reused()
    {
        const string stored = """{"type":"CLASS","class_id":9271,"source":"scheduled","schedule_id":1,"slot_key":"ONCE:1"}""";
        const string asked = """{"type":"CLASS","class_id":9271,"source":"scheduled","schedule_id":1,"slot_key":"once:1"}""";
        var existing = await TestDatabase.ScalarAsync<int>(
            $"insert into notifications.notifications (title, body, target_audience_criteria, created_by, device_count, success_count, failure_count, action_link) values ('t', 'b', '{stored}', {Teacher}, 0, 0, 0, '') returning notification_id",
            TestDatabase.OwnerConnection);

        await using var scope = factory.Services.CreateAsyncScope();
        var written = await NotificationWriter.WriteAsync(
            scope.ServiceProvider.GetRequiredService<NotificationsContext>(), clock, new NewNotification("t", "b", asked, 0, 0, 0, "", Teacher), [S1], "class", reuseSameCriteria: true, CancellationToken.None);

        Assert.That(written.NotificationId, Is.EqualTo(existing));
        Assert.That(await CountAsync("notifications.notifications"), Is.EqualTo(1));
    }
}
