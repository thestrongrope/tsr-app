using System.Collections.Concurrent;
using System.Globalization;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Npgsql;
using NUnit.Framework;
using Tsr.Notifications.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Notifications.Api.Workers;
using Tsr.Platform.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// The push drain (PHP drain_push.php) and platform's queue commands against a real database as the limited role, with a FAKE push sender and a fixed clock: a tick is called directly, never the timer loop.
/// Each row is inserted by the test and read back with the owner's connection.
/// </summary>
public sealed class TestPushDrainTests
{
    private const string Good = """{"title":"Hello","body":"World","data":{"type":"quiz","n":5,"flag":true}}""";

    private sealed class FakeSender : IPushSender
    {
        private int calls;
        private int active;
        private int peak;

        public bool IsConfigured { get; set; } = true;

        public Func<string, PushResult> Decide { get; set; } = _ => PushResult.Sent;

        public TimeSpan Pause { get; set; } = TimeSpan.Zero;

        /// <summary>A device token whose send throws an exception the real sender does not catch.</summary>
        public string? ThrowFor { get; set; }

        /// <summary>Called when a send has started (a test stops the host from here).</summary>
        public Action? Started { get; set; }

        public ConcurrentBag<(PushMessage Message, string Token)> Sent { get; } = [];

        public int Calls => Volatile.Read(ref calls);

        public int Peak => Volatile.Read(ref peak);

        public async Task<PushResult> SendAsync(PushMessage message, string deviceToken, CancellationToken ct)
        {
            Interlocked.Increment(ref calls);
            var now = Interlocked.Increment(ref active);
            int seen;
            while (now > (seen = Volatile.Read(ref peak)) && Interlocked.CompareExchange(ref peak, now, seen) != seen)
            {
            }

            Sent.Add((message, deviceToken));
            Started?.Invoke();
            try
            {
                if (Pause > TimeSpan.Zero)
                {
                    await Task.Delay(Pause, ct);
                }
            }
            finally
            {
                Interlocked.Decrement(ref active);
            }

            if (deviceToken == ThrowFor)
            {
                throw new InvalidOperationException("the fake sender threw for device-token-SECRET");
            }

            return Decide(deviceToken);
        }
    }

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

    private static readonly DateTimeOffset T0 = DateTimeOffset.Parse("2026-12-02T06:30:00+00:00", CultureInfo.InvariantCulture);

    private FakeSender fake = null!;
    private MovableClock clock = null!;
    private CaptureLog log = null!;
    private WebApplicationFactory<Program> factory = null!;

    [SetUp]
    public async Task StartAsync()
    {
        fake = new FakeSender();
        clock = new MovableClock(T0);
        log = new CaptureLog();
        await TestDatabase.ExecuteAsync("truncate platform.outbound_messages restart identity cascade");
        factory = TestApi.Create().WithWebHostBuilder(builder => builder.ConfigureTestServices(services =>
        {
            services.AddSingleton<IPushSender>(fake);
            services.AddSingleton<TimeProvider>(clock);
        }));
    }

    [TearDown]
    public async Task StopAsync()
    {
        factory.Dispose();
        await TestDatabase.ExecuteAsync("drop trigger if exists tsr_test_refuse_sent on platform.outbound_messages");
    }

    private async Task<DrainReport> TickAsync(CancellationToken ct = default)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        return await PushDrain.TickAsync(scope.ServiceProvider.GetRequiredService<NotificationsContext>(), fake, clock, log, ct);
    }

    private async Task<long[]> ClaimAsync(DateTimeOffset now, CancellationToken ct = default)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var rows = await PlatformCommands.ClaimMessagesAsync(scope.ServiceProvider.GetRequiredService<NotificationsContext>(), PushDrain.Channel, PushDrain.MaxRows, now, ct);
        return [.. rows.Select(r => r.Id)];
    }

    private static string Quote(string? value) => value is null ? "null" : "'" + value.Replace("'", "''", StringComparison.Ordinal) + "'";

    private static string At(DateTimeOffset? value) => value is null ? "null" : "'" + value.Value.ToString("O", CultureInfo.InvariantCulture) + "'";

    private static async Task<long> AddAsync(string recipient, string? payload = Good, string status = "queued", int attempts = 0, DateTimeOffset? next = null, DateTimeOffset? claimed = null, string channel = "push") =>
        await TestDatabase.ScalarAsync<long>(
            "insert into platform.outbound_messages (channel, recipient, payload, status, attempts, next_attempt_at, claimed_at) values "
            + $"({Quote(channel)}, {Quote(recipient)}, {Quote(payload)}, {Quote(status)}, {attempts}, {At(next)}, {At(claimed)}) returning id",
            TestDatabase.OwnerConnection);

    private static async Task<Dictionary<string, string?>> RowAsync(long id) =>
        (await TestDatabase.RowAsync($"select status::text as status, attempts, error::text as error, extract(epoch from next_attempt_at)::bigint as next, sent_at is not null as sent from platform.outbound_messages where id = {id}"))!;

    [Test]
    public async Task A_queued_row_is_sent_and_marked()
    {
        var id = await AddAsync("device-1");

        var report = await TickAsync();

        var row = await RowAsync(id);
        Assert.That(row["status"], Is.EqualTo("sent"));
        Assert.That(row["sent"], Is.EqualTo("true"));
        Assert.That(row["attempts"], Is.EqualTo("1"));
        Assert.That(row["error"], Is.Null);
        Assert.That(report.Sent, Is.EqualTo(1));
        var (message, token) = fake.Sent.Single();
        Assert.That(token, Is.EqualTo("device-1"));
        Assert.That(message.Title, Is.EqualTo("Hello"));
        Assert.That(message.Body, Is.EqualTo("World"));
        Assert.That(
            message.Data,
            Is.EquivalentTo(new Dictionary<string, string> { ["type"] = "quiz", ["n"] = "5", ["flag"] = "1", ["click_action"] = "FLUTTER_NOTIFICATION_CLICK" }));
    }

    [Test]
    public async Task Only_the_push_channel_is_drained_and_a_sent_row_is_not_sent_again()
    {
        var whatsapp = await AddAsync("+10000000000", channel: "whatsapp");
        await AddAsync("device-1");

        await TickAsync();
        await TickAsync();

        Assert.That(fake.Calls, Is.EqualTo(1));
        Assert.That((await RowAsync(whatsapp))["status"], Is.EqualTo("queued"));
    }

    [Test]
    public async Task A_row_that_is_not_due_yet_is_left_alone_and_a_due_one_goes()
    {
        var later = await AddAsync("device-later", next: T0.AddSeconds(30));
        var due = await AddAsync("device-due", next: T0.AddSeconds(-1));

        await TickAsync();

        Assert.That((await RowAsync(later))["status"], Is.EqualTo("queued"));
        Assert.That((await RowAsync(later))["attempts"], Is.EqualTo("0"));
        Assert.That((await RowAsync(due))["status"], Is.EqualTo("sent"));

        clock.Now = T0.AddSeconds(30);
        await TickAsync();
        Assert.That((await RowAsync(later))["status"], Is.EqualTo("sent"));
    }

    [Test]
    public async Task A_failing_row_backs_off_60_300_900_3600_seconds_and_is_dead_on_the_fifth_failure()
    {
        fake.Decide = _ => PushResult.Failed;
        var id = await AddAsync("device-1");
        long[] delays = [60, 300, 900, 3600];

        for (var attempt = 1; attempt <= delays.Length; attempt++)
        {
            await TickAsync();
            var row = await RowAsync(id);
            Assert.That(row["status"], Is.EqualTo("queued"), "attempt " + attempt);
            Assert.That(row["attempts"], Is.EqualTo(attempt.ToString(CultureInfo.InvariantCulture)));
            Assert.That(row["next"], Is.EqualTo((clock.Now.ToUnixTimeSeconds() + delays[attempt - 1]).ToString(CultureInfo.InvariantCulture)));
            Assert.That(row["error"], Is.EqualTo("send_failed"));

            var before = fake.Calls;
            clock.Now = clock.Now.AddSeconds(delays[attempt - 1] - 1);
            await TickAsync();
            Assert.That(fake.Calls, Is.EqualTo(before), "one second before it is due nothing is sent");
            clock.Now = clock.Now.AddSeconds(1);
        }

        await TickAsync();

        var last = await RowAsync(id);
        Assert.That(last["status"], Is.EqualTo("dead"));
        Assert.That(last["attempts"], Is.EqualTo("5"));
        Assert.That(last["error"], Is.EqualTo("send_failed"));
        var calls = fake.Calls;
        clock.Now = clock.Now.AddDays(1);
        await TickAsync();
        Assert.That(fake.Calls, Is.EqualTo(calls), "a dead row is never claimed");
    }

    [Test]
    public async Task A_token_FCM_calls_dead_burns_an_attempt_and_keeps_the_device_row()
    {
        fake.Decide = _ => PushResult.TokenInvalid;
        var id = await AddAsync("device-1");

        var report = await TickAsync();

        var row = await RowAsync(id);
        Assert.That(row["status"], Is.EqualTo("queued"));
        Assert.That(row["attempts"], Is.EqualTo("1"));
        Assert.That(row["error"], Is.EqualTo("token_invalid"));
        Assert.That(report.InvalidTokens, Is.EqualTo(1));
    }

    [Test]
    public async Task A_sender_mismatch_is_dead_at_once()
    {
        fake.Decide = _ => PushResult.SenderMismatch;
        var id = await AddAsync("device-1");

        await TickAsync();

        var row = await RowAsync(id);
        Assert.That(row["status"], Is.EqualTo("dead"));
        Assert.That(row["attempts"], Is.EqualTo("1"));
        Assert.That(row["error"], Is.EqualTo("sender_mismatch"));
    }

    [Test]
    public async Task A_past_deadline_is_dead_without_a_send_and_a_future_or_unreadable_one_is_sent()
    {
        var past = await AddAsync("device-past", """{"title":"t","body":"b","deadline":"2026-12-02T06:29:59Z"}""");
        var future = await AddAsync("device-future", """{"title":"t","body":"b","deadline":"2026-12-02T06:30:01Z"}""");
        var unreadable = await AddAsync("device-unreadable", """{"title":"t","body":"b","deadline":"next tuesday-ish"}""");

        await TickAsync();

        Assert.That((await RowAsync(past))["status"], Is.EqualTo("dead"));
        Assert.That((await RowAsync(past))["error"], Is.EqualTo("past_deadline"));
        Assert.That(fake.Sent.Select(s => s.Token), Is.EquivalentTo(["device-future", "device-unreadable"]));
        Assert.That((await RowAsync(future))["status"], Is.EqualTo("sent"));
        Assert.That((await RowAsync(unreadable))["status"], Is.EqualTo("sent"));
    }

    [TestCase(null)]
    [TestCase("[1,2]")]
    [TestCase("\"just text\"")]
    [TestCase("""{"body":"no title"}""")]
    [TestCase("""{"title":"  ","body":"blank title"}""")]
    [TestCase("""{"title":5,"body":"title is not text"}""")]
    public async Task A_payload_that_cannot_be_used_is_dead_and_not_retried(string? payload)
    {
        // The column only accepts valid JSON (a check constraint), so "cannot be parsed" means: not an object, empty, or without a usable title and body.
        var id = await AddAsync("device-1", payload);

        await TickAsync();

        var row = await RowAsync(id);
        Assert.That(row["status"], Is.EqualTo("dead"));
        Assert.That(row["error"], Is.EqualTo("payload_invalid"));
        Assert.That(fake.Calls, Is.Zero);
    }

    [Test]
    public async Task An_unconfigured_sender_claims_nothing()
    {
        fake.IsConfigured = false;
        var id = await AddAsync("device-1");

        var report = await TickAsync();

        var row = await RowAsync(id);
        Assert.That(row["status"], Is.EqualTo("queued"));
        Assert.That(row["attempts"], Is.EqualTo("0"));
        Assert.That(fake.Calls, Is.Zero);
        Assert.That(report.Claimed, Is.Zero);

        fake.IsConfigured = true;
        await TickAsync();
        Assert.That((await RowAsync(id))["status"], Is.EqualTo("sent"), "the row was only waiting for a configured sender");
    }

    [Test]
    public async Task An_unavailable_service_releases_every_row_with_its_attempt_given_back_and_stops_the_tick()
    {
        fake.Decide = _ => PushResult.Unavailable;
        var ids = new List<long>();
        for (var i = 0; i < 40; i++)
        {
            ids.Add(await AddAsync("device-" + i));
        }

        var report = await TickAsync();

        foreach (var id in ids)
        {
            var row = await RowAsync(id);
            Assert.That(row["status"], Is.EqualTo("queued"));
            Assert.That(row["attempts"], Is.EqualTo("0"));
            Assert.That(row["error"], Is.Null);
        }

        Assert.That(report.Released, Is.EqualTo(40));
        Assert.That(fake.Calls, Is.LessThanOrEqualTo(16), "the sends already running finish; no row starts after the first unavailable answer");
    }

    [Test]
    public async Task A_row_sent_before_the_service_went_away_stays_sent_and_the_rest_are_released()
    {
        fake.Decide = token => token == "device-bad" ? PushResult.Unavailable : PushResult.Sent;
        var good = await AddAsync("device-good");
        var bad = await AddAsync("device-bad");
        var tail = await AddAsync("device-tail");

        var report = await TickAsync();

        Assert.That(report.Claimed, Is.EqualTo(3));
        Assert.That(fake.Sent.Select(s => s.Token), Does.Contain("device-bad"));
        var states = new[] { good, bad, tail }.ToDictionary(id => id, id => RowAsync(id).Result);
        Assert.That(states[bad]["status"], Is.EqualTo("queued"));
        Assert.That(states[bad]["attempts"], Is.EqualTo("0"));
        foreach (var token in fake.Sent.Where(s => s.Token != "device-bad").Select(s => s.Token))
        {
            var id = token == "device-good" ? good : tail;
            Assert.That(states[id]["status"], Is.EqualTo("sent"), token + " was sent, so it is recorded as sent");
        }

        foreach (var id in states.Keys.Where(id => states[id]["status"] != "sent"))
        {
            Assert.That(states[id]["status"], Is.EqualTo("queued"));
            Assert.That(states[id]["attempts"], Is.EqualTo("0"));
        }
    }

    [Test]
    public async Task A_row_left_sending_for_eleven_minutes_is_reclaimed_and_one_left_for_nine_is_not()
    {
        var stale = await AddAsync("device-stale", status: "sending", attempts: 1, claimed: T0.AddMinutes(-11));
        var fresh = await AddAsync("device-fresh", status: "sending", attempts: 1, claimed: T0.AddMinutes(-9));

        await TickAsync();

        Assert.That((await RowAsync(stale))["status"], Is.EqualTo("sent"));
        Assert.That((await RowAsync(stale))["attempts"], Is.EqualTo("2"));
        Assert.That((await RowAsync(fresh))["status"], Is.EqualTo("sending"));
        Assert.That(fake.Sent.Select(s => s.Token), Is.EqualTo(["device-stale"]));
    }

    [Test]
    public async Task A_result_for_a_claim_another_worker_has_since_taken_over_does_not_overwrite_it()
    {
        var id = await AddAsync("device-1", status: "sending", attempts: 2, claimed: T0.AddMinutes(-1));
        await using var scope = factory.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<NotificationsContext>();

        var sent = await PlatformCommands.MarkSentAsync(db, id, attempts: 1, clock.GetUtcNow(), CancellationToken.None);
        var failed = await PlatformCommands.MarkFailedAsync(db, id, attempts: 1, "late", clock.GetUtcNow(), CancellationToken.None);
        var released = await PlatformCommands.ReleaseMessageAsync(db, id, attempts: 1, CancellationToken.None);
        var dead = await PlatformCommands.MarkDeadAsync(db, id, attempts: 1, "late", CancellationToken.None);

        Assert.That((sent, failed, released, dead), Is.EqualTo((false, null as string, false, false)));
        var row = await RowAsync(id);
        Assert.That(row["status"], Is.EqualTo("sending"));
        Assert.That(row["attempts"], Is.EqualTo("2"));
    }

    [Test]
    public async Task A_claim_skips_the_rows_another_claim_holds_locked_and_takes_only_the_others()
    {
        var first = await AddAsync("device-1");
        var second = await AddAsync("device-2");
        var third = await AddAsync("device-3");
        var fourth = await AddAsync("device-4");
        await using var other = new NpgsqlConnection(TestDatabase.OwnerConnection);
        await other.OpenAsync();
        await using var held = await other.BeginTransactionAsync();
        await using (var lockRows = new NpgsqlCommand($"select id from platform.outbound_messages where id in ({first}, {second}) for update", other, held))
        {
            await lockRows.ExecuteNonQueryAsync();
        }

        using var limit = new CancellationTokenSource(TimeSpan.FromSeconds(4));
        var whileLocked = await ClaimAsync(T0, limit.Token);
        await held.RollbackAsync();
        var afterwards = await ClaimAsync(T0);

        Assert.That(whileLocked, Is.EqualTo(new[] { third, fourth }), "the locked rows are skipped, not waited for");
        Assert.That(afterwards, Is.EqualTo(new[] { first, second }), "each row is claimed exactly once");
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "status = 'sending' and attempts = 1"), Is.EqualTo(4));
    }

    [Test]
    public async Task A_claim_stamps_the_time_so_a_claim_that_never_recorded_is_taken_over_after_the_lease()
    {
        var id = await AddAsync("device-1");

        var claimed = await ClaimAsync(T0);

        Assert.That(claimed, Is.EqualTo(new[] { id }));
        var stamp = await TestDatabase.RowAsync($"select extract(epoch from claimed_at)::bigint as at from platform.outbound_messages where id = {id}");
        Assert.That(stamp!["at"], Is.EqualTo(T0.ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture)));

        clock.Now = T0.AddMinutes(9);
        await TickAsync();
        Assert.That((await RowAsync(id))["status"], Is.EqualTo("sending"), "inside the lease the claim is left alone");

        clock.Now = T0.AddMinutes(11);
        await TickAsync();
        var row = await RowAsync(id);
        Assert.That(row["status"], Is.EqualTo("sent"));
        Assert.That(row["attempts"], Is.EqualTo("2"));
    }

    [Test]
    public async Task A_stale_claim_that_has_used_its_five_attempts_is_dead_and_not_sent_again()
    {
        var spent = await AddAsync("device-spent", status: "sending", attempts: 5, claimed: T0.AddMinutes(-11));
        var last = await AddAsync("device-last", status: "sending", attempts: 4, claimed: T0.AddMinutes(-11));
        var running = await AddAsync("device-running", status: "sending", attempts: 5, claimed: T0.AddMinutes(-9));

        await TickAsync();

        var row = await RowAsync(spent);
        Assert.That(row["status"], Is.EqualTo("dead"));
        Assert.That(row["attempts"], Is.EqualTo("5"));
        Assert.That(row["error"], Is.EqualTo("reclaim_exhausted"));
        Assert.That(fake.Sent.Select(s => s.Token), Is.EqualTo(["device-last"]), "the fifth attempt is still made; a sixth never");
        Assert.That((await RowAsync(last))["attempts"], Is.EqualTo("5"));
        Assert.That((await RowAsync(running))["status"], Is.EqualTo("sending"), "a claim inside its lease is not touched");
    }

    [Test]
    public async Task A_result_that_cannot_be_recorded_does_not_stop_the_other_rows_from_being_recorded()
    {
        await TestDatabase.ExecuteAsync(
            "create or replace function public.tsr_test_refuse_sent() returns trigger language plpgsql as $$ begin "
            + "if new.recipient = 'device-boom' and new.status = 'sent' then raise exception 'test failure'; end if; return new; end $$; "
            + "create trigger tsr_test_refuse_sent before update on platform.outbound_messages for each row execute function public.tsr_test_refuse_sent()");
        var boom = await AddAsync("device-boom");
        var second = await AddAsync("device-2");
        var third = await AddAsync("device-3");

        var report = await TickAsync();

        Assert.That((await RowAsync(boom))["status"], Is.EqualTo("sending"), "its result could not be written; the lease takes it over later");
        Assert.That((await RowAsync(second))["status"], Is.EqualTo("sent"));
        Assert.That((await RowAsync(third))["status"], Is.EqualTo("sent"));
        Assert.That((report.Sent, report.Unrecorded), Is.EqualTo((2, 1)));
        Assert.That(string.Join('\n', log.Lines), Does.Contain("PostgresException"));
    }

    [Test]
    public async Task A_sender_that_throws_for_one_row_burns_that_attempt_and_the_other_rows_are_still_recorded()
    {
        fake.ThrowFor = "device-bad";
        var good = await AddAsync("device-good");
        var bad = await AddAsync("device-bad");
        var tail = await AddAsync("device-tail");

        var report = await TickAsync();

        Assert.That((await RowAsync(good))["status"], Is.EqualTo("sent"));
        Assert.That((await RowAsync(tail))["status"], Is.EqualTo("sent"));
        var row = await RowAsync(bad);
        Assert.That(row["status"], Is.EqualTo("queued"));
        Assert.That(row["attempts"], Is.EqualTo("1"));
        Assert.That(row["error"], Is.EqualTo("send_failed"));
        Assert.That((report.Sent, report.Retrying), Is.EqualTo((2, 1)));
        var lines = string.Join('\n', log.Lines);
        Assert.That(lines, Does.Contain("InvalidOperationException").And.Not.Contain("SECRET"), "the exception's type is logged, never its message");
    }

    [Test]
    public async Task Stopping_the_host_starts_no_new_send_and_the_sends_in_flight_finish_and_are_recorded()
    {
        fake.Pause = TimeSpan.FromMilliseconds(200);
        using var host = new CancellationTokenSource();
        fake.Started = host.Cancel;
        for (var i = 0; i < 40; i++)
        {
            await AddAsync("device-" + i);
        }

        var report = await TickAsync(host.Token);

        Assert.That(fake.Calls, Is.InRange(1, 16), "no send starts after the stop");
        Assert.That(report.Sent, Is.EqualTo(fake.Calls), "a send in flight finishes and its result is written");
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "status = 'sent' and attempts = 1"), Is.EqualTo(fake.Calls));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "status = 'queued' and attempts = 0"), Is.EqualTo(40 - fake.Calls), "a row never started is released with its attempt given back");
    }

    [Test]
    public async Task A_tick_takes_at_most_fifty_rows_and_sends_at_most_sixteen_at_a_time()
    {
        fake.Pause = TimeSpan.FromMilliseconds(30);
        for (var i = 0; i < 60; i++)
        {
            await AddAsync("device-" + i);
        }

        await TickAsync();

        Assert.That(fake.Calls, Is.EqualTo(50));
        Assert.That(fake.Peak, Is.LessThanOrEqualTo(16));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "status = 'queued'"), Is.EqualTo(10));
    }

    [Test]
    public async Task Nothing_in_the_error_column_or_a_log_line_holds_the_recipient_the_title_or_the_body()
    {
        var recipient = "device-token-SECRET-123";
        fake.Decide = _ => PushResult.Failed;
        var id = await AddAsync(recipient, """{"title":"TitleSecret","body":"BodySecret"}""");
        var bad = await AddAsync(recipient + "-2", "[1]");
        var past = await AddAsync(recipient + "-3", """{"title":"TitleSecret","body":"BodySecret","deadline":"2020-01-01T00:00:00Z"}""");

        await TickAsync();

        foreach (var row in new[] { id, bad, past })
        {
            var error = (await RowAsync(row))["error"] ?? string.Empty;
            Assert.That(error, Does.Not.Contain("SECRET"));
        }

        Assert.That(log.Lines, Is.Not.Empty);
        Assert.That(string.Join('\n', log.Lines), Does.Not.Contain("Secret").And.Not.Contain("SECRET"));
    }
}
