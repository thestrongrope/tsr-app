using System.Collections.Concurrent;
using System.Net;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using NUnit.Framework;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>
/// The ten /admin/whatsapp/* proxy routes of the edge lane, against a FAKE notifier at the <see cref="INotifier"/> boundary (no notifier exists in any test stack).
/// What the fake received is the proof: a refused call reaches it with nothing, an id is only an integer, dryRun is true unless the JSON literal false.
/// Members: 927001 super admin (whatsapp:manage), 927002 gents admin (role 3, no whatsapp:manage), 927003 plain member. Each rate-limit test uses its own token (the limit is in memory per host).
/// </summary>
public sealed class TestEdgeWhatsappTests
{
    private const int Super = 927001;
    private const int GentsAdmin = 927002;
    private const int Plain = 927003;
    private const string Denied = "You do not have permission to do that";

    private sealed class FakeNotifier : INotifier
    {
        public ConcurrentQueue<string> Calls { get; } = new();

        public NotifierAnswer Answer { get; set; } = new(200, "{}");

        private Task<NotifierAnswer> Record(string call)
        {
            Calls.Enqueue(call);
            return Task.FromResult(Answer);
        }

        public Task<NotifierAnswer> StatusAsync(CancellationToken ct) => Record("status");

        public Task<NotifierAnswer> QrAsync(CancellationToken ct) => Record("qr");

        public Task<NotifierAnswer> RemindersAsync(CancellationToken ct) => Record("reminders");

        public Task<NotifierAnswer> RecentRunsAsync(string? limit, string? reminderId, CancellationToken ct) => Record($"recent limit={limit ?? "-"} reminder={reminderId ?? "-"}");

        public Task<NotifierAnswer> RunAsync(long id, CancellationToken ct) => Record($"run {id}");

        public Task<NotifierAnswer> RunMessagesAsync(long id, CancellationToken ct) => Record($"messages {id}");

        public Task<NotifierAnswer> RelinkAsync(CancellationToken ct) => Record("relink");

        public Task<NotifierAnswer> LogoutAsync(CancellationToken ct) => Record("logout");

        public Task<NotifierAnswer> UpdateReminderAsync(long id, IReadOnlyDictionary<string, JsonElement> fields, int token, CancellationToken ct) =>
            Record($"update {id} {JsonSerializer.Serialize(fields)} by={token}");

        public Task<NotifierAnswer> RunWeeklyAsync(long reminderId, bool dryRun, int token, CancellationToken ct) => Record($"runweekly {reminderId} dry={dryRun} by={token}");

        public Task<NotifierAnswer> SendTestAsync(string mobile, string message, int token, CancellationToken ct) => Record($"sendtest by={token}");
    }

    private sealed class CaptureLogs : ILoggerProvider
    {
        public ConcurrentQueue<string> Lines { get; } = new();

        public ILogger CreateLogger(string categoryName) => new Capture(Lines);

        public void Dispose()
        {
        }

        private sealed class Capture(ConcurrentQueue<string> lines) : ILogger
        {
            public IDisposable? BeginScope<TState>(TState state)
                where TState : notnull => null;

            public bool IsEnabled(LogLevel logLevel) => true;

            public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
                lines.Enqueue(formatter(state, exception) + exception);
        }
    }

    private readonly FakeNotifier fake = new();
    private readonly CaptureLogs logs = new();
    private MembershipTestKit kit = null!;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit(services =>
    {
        services.AddSingleton<INotifier>(fake);
        services.AddLogging(builder => builder.AddProvider(logs));
    });

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync("truncate platform.admin_access_log restart identity");
        foreach (var token in new[] { Super, GentsAdmin, Plain, 927010, 927011, 927012, 927013, 927014, 927015 })
        {
            var id = await MembershipTestKit.AddMemberAsync(token, "Edge Member " + token, "1");
            var role = token == GentsAdmin ? 3 : (token == Plain ? 0 : 1);
            if (role != 0)
            {
                await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({id}, {role})");
            }
        }

        fake.Calls.Clear();
        fake.Answer = new NotifierAnswer(200, "{}");
    }

    private static readonly (string Method, string Path, string? Body)[] AllRoutes =
    [
        ("GET", "/admin/whatsapp/reminders", null),
        ("PUT", "/admin/whatsapp/reminders/5", """{"enabled":true}"""),
        ("POST", "/admin/whatsapp/reminders/5/run", "{}"),
        ("GET", "/admin/whatsapp/runs", null),
        ("GET", "/admin/whatsapp/runs/5", null),
        ("POST", "/admin/whatsapp/test", """{"mobile":"+910000000000","message":"hello"}"""),
        ("GET", "/admin/whatsapp/link", null),
        ("GET", "/admin/whatsapp/link/qr", null),
        ("POST", "/admin/whatsapp/link/relink", "{}"),
        ("POST", "/admin/whatsapp/link/logout", "{}"),
    ];

    private Task<MembershipTestKit.Reply> As(int token, string method, string path, string? body = null) =>
        kit.SendAsync(token, new HttpMethod(method), path, body);

    [Test]
    public async Task Every_route_refuses_a_member_without_whatsapp_manage_with_403_and_never_reaches_the_notifier()
    {
        foreach (var (method, path, body) in AllRoutes)
        {
            foreach (var caller in new[] { Plain, GentsAdmin })
            {
                var reply = await As(caller, method, path, body);
                Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Forbidden), $"{method} {path} as {caller}: {reply.Body}");
                Assert.That(reply.Detail, Is.EqualTo(Denied), $"{method} {path}");
            }
        }

        Assert.That(fake.Calls, Is.Empty);
        Assert.That(await MembershipTestKit.CountAsync("platform.admin_access_log"), Is.Zero);
    }

    [Test]
    public async Task Every_route_refuses_nobody_with_401_and_never_reaches_the_notifier()
    {
        foreach (var (method, path, body) in AllRoutes)
        {
            var reply = await kit.SendUnsignedAsync(new HttpMethod(method), path, body);
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Unauthorized), $"{method} {path}: {reply.Body}");
        }

        Assert.That(fake.Calls, Is.Empty);
    }

    [TestCase("""{}""", true)]
    [TestCase("""{"dryRun":null}""", true)]
    [TestCase("""{"dryRun":"false"}""", true)]
    [TestCase("""{"dryRun":0}""", true)]
    [TestCase("""{"dryRun":[false]}""", true)]
    [TestCase("""{"dryRun":{"a":false}}""", true)]
    [TestCase("""{"dryRun":"true"}""", true)]
    [TestCase("""{"dryRun":true}""", true)]
    [TestCase("""{"dryRun":false}""", false)]
    public async Task A_run_is_a_dry_run_unless_dryRun_is_the_json_literal_false(string body, bool dry)
    {
        fake.Answer = new NotifierAnswer(200, """{"run_id": 77}""");

        var reply = await As(Super, "POST", "/admin/whatsapp/reminders/5/run", body);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Accepted), reply.Body);
        Assert.That(reply.Json!["dryRun"]!.GetValue<bool>(), Is.EqualTo(dry));
        Assert.That(reply.Json["runId"]!.GetValue<int>(), Is.EqualTo(77));
        Assert.That(fake.Calls.Single(), Is.EqualTo($"runweekly 5 dry={dry} by={Super}"));
    }

    [TestCase("not json")]
    [TestCase("""{"dryRun":false""")]
    public async Task A_run_with_invalid_json_is_422_and_sends_nothing(string body)
    {
        var reply = await As(Super, "POST", "/admin/whatsapp/reminders/5/run", body);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), reply.Body);
        Assert.That(fake.Calls, Is.Empty);
    }

    [Test]
    public async Task A_missing_body_is_a_dry_run()
    {
        fake.Answer = new NotifierAnswer(200, """{"run_id": 1}""");

        var reply = await As(Super, "POST", "/admin/whatsapp/reminders/5/run");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Accepted), reply.Body);
        Assert.That(fake.Calls.Single(), Does.Contain("dry=True"));
    }

    [TestCase("12", "run 12")]
    [TestCase("12abc", "run 12")]
    [TestCase("12%2F..%2F..%2Fsend", "run 12")]
    [TestCase("1%3Fx%3Dy", "run 1")]
    [TestCase("%2e%2e", "-")]
    [TestCase("..", "-")]
    [TestCase("abc", "-")]
    [TestCase("0", "-")]
    [TestCase("-5", "-")]
    [TestCase("99999999999999999999999999999999999999999999999999999999999999999999999999999999", "run 9223372036854775807")]
    public async Task A_run_id_is_only_ever_an_integer_in_the_notifier_path(string segment, string expectedCall)
    {
        var reply = await As(Super, "GET", "/admin/whatsapp/runs/" + segment);

        Assert.That((int)reply.Status, Is.LessThan(500), segment + " " + reply.Body);
        var first = fake.Calls.FirstOrDefault() ?? "-";
        Assert.That(first, Is.EqualTo(expectedCall), segment);
        Assert.That(fake.Calls.Where(c => !c.StartsWith("run ", StringComparison.Ordinal) && !c.StartsWith("messages ", StringComparison.Ordinal)), Is.Empty);
    }

    [TestCase("12", "runweekly 12 dry=True by=927001")]
    [TestCase("1%3Fx%3Dy", "runweekly 1 dry=True by=927001")]
    [TestCase("12%2F..%2Flink%2Flogout", "runweekly 12 dry=True by=927001")]
    [TestCase("..", "runweekly 0 dry=True by=927001")]
    [TestCase("99999999999999999999999999999999999999999999999999999999999999999999999999999999", "runweekly 9223372036854775807 dry=True by=927001")]
    public async Task A_reminder_id_is_only_ever_an_integer_in_the_notifier_call(string segment, string expectedCall)
    {
        fake.Answer = new NotifierAnswer(200, """{"run_id": 1}""");

        var reply = await As(Super, "POST", "/admin/whatsapp/reminders/" + segment + "/run", "{}");

        Assert.That((int)reply.Status, Is.LessThan(500), segment + " " + reply.Body);
        if (reply.Status == HttpStatusCode.Accepted)
        {
            Assert.That(fake.Calls.Single(), Is.EqualTo(expectedCall));
        }
        else
        {
            Assert.That(fake.Calls, Is.Empty);
        }
    }

    [Test]
    public async Task Updating_a_reminder_with_a_non_positive_id_is_400_and_sends_nothing()
    {
        foreach (var segment in new[] { "0", "abc", "-3" })
        {
            var reply = await As(Super, "PUT", "/admin/whatsapp/reminders/" + segment, """{"enabled":true}""");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.BadRequest), segment + " " + reply.Body);
            Assert.That(reply.Detail, Is.EqualTo("missing or invalid id"));
        }

        Assert.That(fake.Calls, Is.Empty);
    }

    [Test]
    public async Task Updating_a_reminder_forwards_only_the_present_keys_in_snake_case_and_the_actors_token()
    {
        fake.Answer = new NotifierAnswer(200, """{"id":5,"name":"R","enabled":1}""");

        var reply = await As(Super, "PUT", "/admin/whatsapp/reminders/5", """{"leewayDays":3,"city":null,"unknown":1,"sendTime":"09:30"}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(fake.Calls.Single(), Is.EqualTo($$"""update 5 {"city":null,"leeway_days":3,"send_time":"09:30"} by={{Super}}"""));
    }

    [Test]
    public async Task Updating_with_a_nul_byte_or_over_long_text_is_422_never_500()
    {
        var nul = await As(Super, "PUT", "/admin/whatsapp/reminders/5", """{"city":"a\u0000b"}""");
        var longText = await As(Super, "PUT", "/admin/whatsapp/reminders/5", "{\"city\":\"" + new string('x', 501) + "\"}");

        Assert.That(nul.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), nul.Body);
        Assert.That(longText.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), longText.Body);
        Assert.That(fake.Calls, Is.Empty);
    }

    [Test]
    public async Task The_runs_list_passes_only_digits_and_the_last_repeated_key()
    {
        await As(Super, "GET", "/admin/whatsapp/runs?limit=5%26x%3D1&reminderId=7%26y");
        await As(Super, "GET", "/admin/whatsapp/runs?limit=5&limit=9&reminderId=7");
        await As(Super, "GET", "/admin/whatsapp/runs?limit=-1&reminderId=1.5");
        await As(Super, "GET", "/admin/whatsapp/runs?limit=" + new string('9', 19));
        await As(Super, "GET", "/admin/whatsapp/runs");

        Assert.That(
            fake.Calls,
            Is.EqualTo(new List<string> { "recent limit=- reminder=-", "recent limit=9 reminder=7", "recent limit=- reminder=-", "recent limit=- reminder=-", "recent limit=- reminder=-" }));
    }

    [Test]
    public async Task A_test_message_sends_non_strings_as_empty_text_and_rejects_nul_and_overlong_text_with_422()
    {
        fake.Answer = new NotifierAnswer(200, """{"run_id": 4}""");

        var ok = await As(Super, "POST", "/admin/whatsapp/test", """{"mobile":5,"message":["x"]}""");
        var nul = await As(Super, "POST", "/admin/whatsapp/test", """{"mobile":"+9\u00001","message":"m"}""");
        var longMessage = await As(Super, "POST", "/admin/whatsapp/test", "{\"mobile\":\"1\",\"message\":\"" + new string('x', 4097) + "\"}");

        Assert.That(ok.Status, Is.EqualTo(HttpStatusCode.OK), ok.Body);
        Assert.That(ok.Json!["status"]!.GetValue<string>(), Is.EqualTo("sent"));
        Assert.That(nul.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), nul.Body);
        Assert.That(longMessage.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), longMessage.Body);
        Assert.That(fake.Calls, Has.Count.EqualTo(1));
        fake.Answer = new NotifierAnswer(200, """{"run_id": 4, "status": "sent"}""");
        var sent = await As(Super, "POST", "/admin/whatsapp/test", """{"mobile":"+9199887766","message":"DISTINCT-MESSAGE-TEXT"}""");
        Assert.That(sent.Status, Is.EqualTo(HttpStatusCode.OK), sent.Body);
        var captured = string.Join('\n', logs.Lines);
        Assert.That(captured, Does.Contain("whatsapp.test_sent"), "positive control: this request's own log line is captured");
        Assert.That(captured, Does.Not.Contain("99887766").And.Not.Contain("DISTINCT-MESSAGE-TEXT"));
    }

    [TestCase(400, """{"error":"mobile is required"}""", 400, "mobile is required")]
    [TestCase(409, """{"error":"a run is already in progress"}""", 409, "a run is already in progress")]
    [TestCase(404, """{"error":"run not found"}""", 404, "run not found")]
    [TestCase(500, """{"error":"connect ECONNREFUSED 10.0.0.5:3306 (db host)"}""", 500, "connect ECONNREFUSED 10.0.0.5:3306 (db host)")]
    [TestCase(500, """{}""", 500, "The reminder service could not do that. Please try again.")]
    [TestCase(400, """{"error":""}""", 400, "The reminder service could not do that. Please try again.")]
    [TestCase(502, "<html>bad gateway</html>", 502, "The reminder service could not do that. Please try again.")]
    [TestCase(404, """{"error":5}""", 404, "The reminder service could not do that. Please try again.")]
    public async Task A_notifier_answer_of_400_or_more_keeps_its_status_and_error_text_as_PHP_does(int status, string body, int expectedStatus, string expectedDetail)
    {
        fake.Answer = new NotifierAnswer(status, body);

        var reply = await As(Super, "GET", "/admin/whatsapp/reminders");

        Assert.That((int)reply.Status, Is.EqualTo(expectedStatus), reply.Body);
        Assert.That(reply.Detail, Is.EqualTo(expectedDetail));
    }

    [Test]
    public async Task An_unreachable_notifier_is_502_notifier_unreachable_with_no_host_or_port()
    {
        fake.Answer = NotifierAnswer.Unreachable;

        var reply = await As(Super, "GET", "/admin/whatsapp/reminders");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.BadGateway), reply.Body);
        Assert.That(reply.Detail, Is.EqualTo("notifier unreachable"));
    }

    [Test]
    public async Task A_reminders_answer_that_is_not_an_array_is_an_empty_list_and_a_non_object_row_is_skipped()
    {
        fake.Answer = new NotifierAnswer(200, """{"x":1}""");
        var notList = await As(Super, "GET", "/admin/whatsapp/reminders");
        fake.Answer = new NotifierAnswer(200, """[1,"a",{"id":3,"name":"N","enabled":1,"updated_at":"2026-11-01 10:00:00"}]""");
        var mixed = await As(Super, "GET", "/admin/whatsapp/reminders");

        Assert.That(notList.Json!["reminders"]!.AsArray(), Is.Empty);
        Assert.That(mixed.Json!["reminders"]!.AsArray(), Has.Count.EqualTo(1));
        Assert.That(mixed.Json["reminders"]![0]!["updatedAt"]!.GetValue<string>(), Is.EqualTo("2026-11-01T10:00:00Z"));
    }

    [Test]
    public async Task The_link_and_qr_answers_carry_no_store_on_200_401_403_and_503()
    {
        fake.Answer = new NotifierAnswer(200, """{"connected":true}""");
        var ok = await kit.SendRawAsync(Super, HttpMethod.Get, "/admin/whatsapp/link");
        fake.Answer = new NotifierAnswer(500, "{}");
        var unavailable = await kit.SendRawAsync(Super, HttpMethod.Get, "/admin/whatsapp/link/qr");
        var denied = await kit.SendRawAsync(Plain, HttpMethod.Get, "/admin/whatsapp/link/qr");
        var nobody = await kit.SendRawAsync(null, HttpMethod.Post, "/admin/whatsapp/link/relink");

        Assert.That(ok.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(unavailable.Status, Is.EqualTo(HttpStatusCode.ServiceUnavailable));
        Assert.That(denied.Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(nobody.Status, Is.EqualTo(HttpStatusCode.Unauthorized));
        foreach (var reply in new[] { ok, unavailable, denied, nobody })
        {
            Assert.That(reply.CacheControl, Is.EqualTo("no-store"));
        }
    }

    [TestCase(0, 20, false)]
    [TestCase(1, 60, false)]
    [TestCase(1, 61, true)]
    [TestCase(1, -1, true)]
    public async Task A_qr_older_than_60_seconds_or_of_unknown_age_is_withheld_and_never_logged(int _, int age, bool stale)
    {
        fake.Answer = new NotifierAnswer(200, $$"""{"qr":"SECRET-QR-VALUE","generated_seconds_ago":{{age}}}""");

        var reply = await As(Super, "GET", "/admin/whatsapp/link/qr");
        fake.Answer = new NotifierAnswer(200, """{"run_id": 4}""");
        await As(Super, "POST", "/admin/whatsapp/test", """{"mobile":"1","message":"m"}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["stale"]!.GetValue<bool>(), Is.EqualTo(stale));
        Assert.That(reply.Json["qr"] is null, Is.EqualTo(stale));
        var captured = string.Join('\n', logs.Lines);
        Assert.That(captured, Does.Contain("whatsapp.test_sent"), "positive control: the capture sees this host's log lines");
        Assert.That(captured, Does.Not.Contain("SECRET-QR-VALUE"));
    }

    [Test]
    public async Task A_qr_without_an_age_is_withheld_a_missing_qr_is_503_and_a_404_means_no_code_yet()
    {
        fake.Answer = new NotifierAnswer(200, """{"qr":"SECRET-QR-VALUE"}""");
        var ageless = await As(Super, "GET", "/admin/whatsapp/link/qr");
        fake.Answer = new NotifierAnswer(200, """{"qr":""}""");
        var empty = await As(Super, "GET", "/admin/whatsapp/link/qr");
        fake.Answer = new NotifierAnswer(404, "{}");
        var none = await As(Super, "GET", "/admin/whatsapp/link/qr");

        Assert.That(ageless.Json!["qr"], Is.Null);
        Assert.That(ageless.Json["stale"]!.GetValue<bool>(), Is.True);
        Assert.That(empty.Status, Is.EqualTo(HttpStatusCode.ServiceUnavailable));
        Assert.That(none.Json!["qr"], Is.Null);
        Assert.That(none.Json["stale"]!.GetValue<bool>(), Is.False);
    }

    [Test]
    public async Task The_link_state_is_connected_waiting_or_offline_and_503_when_the_notifier_cannot_be_asked()
    {
        var states = new List<string>();
        foreach (var body in new[] { """{"connected":1}""", """{"connected":0,"awaiting_qr":1}""", """{"connected":"0","awaiting_qr":"0"}""", "[]" })
        {
            fake.Answer = new NotifierAnswer(200, body);
            states.Add((await As(Super, "GET", "/admin/whatsapp/link")).Json!["state"]!.GetValue<string>());
        }

        fake.Answer = new NotifierAnswer(200, "not json");
        var notJson = await As(Super, "GET", "/admin/whatsapp/link");
        fake.Answer = new NotifierAnswer(404, "{}");
        var notFound = await As(Super, "GET", "/admin/whatsapp/link");

        Assert.That(states, Is.EqualTo(new List<string> { "connected", "waiting", "offline", "offline" }));
        Assert.That(notJson.Status, Is.EqualTo(HttpStatusCode.ServiceUnavailable));
        Assert.That(notFound.Status, Is.EqualTo(HttpStatusCode.ServiceUnavailable));
    }

    [Test]
    public async Task The_link_read_limit_is_90_a_minute_shared_by_link_and_qr()
    {
        fake.Answer = new NotifierAnswer(200, """{"connected":true}""");
        for (var i = 0; i < 45; i++)
        {
            Assert.That((await As(927010, "GET", "/admin/whatsapp/link")).Status, Is.EqualTo(HttpStatusCode.OK));
            Assert.That((await As(927010, "GET", "/admin/whatsapp/link/qr")).Status, Is.Not.EqualTo(HttpStatusCode.TooManyRequests));
        }

        var over = await kit.SendRawAsync(927010, HttpMethod.Get, "/admin/whatsapp/link");
        var other = await As(927011, "GET", "/admin/whatsapp/link");

        Assert.That(over.Status, Is.EqualTo(HttpStatusCode.TooManyRequests));
        Assert.That(over.CacheControl, Is.EqualTo("no-store"));
        Assert.That(over.Body, Does.Contain("Too many requests. Please wait a minute and try again."));
        Assert.That(other.Status, Is.EqualTo(HttpStatusCode.OK));
    }

    [Test]
    public async Task The_change_limit_is_6_a_minute_shared_by_relink_and_logout_and_a_limited_call_writes_no_audit_row()
    {
        for (var i = 0; i < 3; i++)
        {
            Assert.That((await As(927012, "POST", "/admin/whatsapp/link/relink", "{}")).Status, Is.EqualTo(HttpStatusCode.OK));
            Assert.That((await As(927012, "POST", "/admin/whatsapp/link/logout", "{}")).Status, Is.EqualTo(HttpStatusCode.OK));
        }

        var rowsBefore = await MembershipTestKit.CountAsync("platform.admin_access_log", "token = 927012");
        var seventh = await kit.SendRawAsync(927012, HttpMethod.Post, "/admin/whatsapp/link/relink", "{}");
        var rowsAfter = await MembershipTestKit.CountAsync("platform.admin_access_log", "token = 927012");

        Assert.That(seventh.Status, Is.EqualTo(HttpStatusCode.TooManyRequests));
        Assert.That(seventh.CacheControl, Is.EqualTo("no-store"));
        Assert.That(rowsBefore, Is.EqualTo(6));
        Assert.That(rowsAfter, Is.EqualTo(6));
        Assert.That(fake.Calls, Has.Count.EqualTo(6));
    }

    [Test]
    public async Task Ten_simultaneous_relinks_by_one_member_give_exactly_six_attempts_four_429s_and_six_audit_rows()
    {
        var replies = await Task.WhenAll(Enumerable.Range(0, 10).Select(_ => As(927015, "POST", "/admin/whatsapp/link/relink", "{}")));

        Assert.That(replies.Count(r => r.Status == HttpStatusCode.OK), Is.EqualTo(6));
        Assert.That(replies.Count(r => r.Status == HttpStatusCode.TooManyRequests), Is.EqualTo(4));
        Assert.That(fake.Calls, Has.Count.EqualTo(6));
        Assert.That(await MembershipTestKit.CountAsync("platform.admin_access_log", "token = 927015"), Is.EqualTo(6));
    }

    [TestCase("/admin/whatsapp/link/relink", "Re-link failed. The link is unchanged; please try again.")]
    [TestCase("/admin/whatsapp/link/logout", "Logout failed. The link is unchanged; please try again.")]
    public async Task Relink_and_logout_write_one_audit_row_before_the_call_also_when_the_notifier_fails(string path, string failedText)
    {
        fake.Answer = new NotifierAnswer(500, """{"error":"boom"}""");

        var failed = await As(927013, "POST", path, "{}");
        fake.Answer = new NotifierAnswer(200, "{}");
        var done = await As(927014, "POST", path, "{}");

        Assert.That(failed.Status, Is.EqualTo(HttpStatusCode.BadGateway), failed.Body);
        Assert.That(failed.Detail, Is.EqualTo(failedText));
        Assert.That(done.Status, Is.EqualTo(HttpStatusCode.OK), done.Body);
        Assert.That(done.Json!["ok"]!.GetValue<bool>(), Is.True);
        Assert.That(await MembershipTestKit.CountAsync("platform.admin_access_log", "token = 927013"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.admin_access_log", "token = 927014"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.admin_access_log", $"page = '{path}' and method = 'POST'"), Is.EqualTo(2));
    }

    [Test]
    public async Task The_notifier_writes_no_outbox_event_for_any_route()
    {
        var before = await MembershipTestKit.CountAsync("platform.outbox");
        foreach (var (method, path, body) in AllRoutes)
        {
            await As(Super, method, path, body);
        }

        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(before));
    }
}
