using System.Collections.Concurrent;
using System.Globalization;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Notifications.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Notifications.Api.Workers;

namespace Tsr.Db.Tests;

/// <summary>
/// The golden set-up of the notifications characterisation tests (issue 103, plan "Golden files"): the template <c>notifications_golden_template</c>, migrated as production and seeded
/// with <see cref="NotificationsSeed"/>, and <see cref="NotificationsRun"/>, a <see cref="GoldenScenario"/> whose push service and notifier are recording stubs, so nothing here can reach
/// FCM, Google or a messaging service. Every row query reads a table a route, a worker or a command writes, ordered by its key; every <c>timestamptz</c> column is shown through
/// <c>public.golden_clock</c>: its value when it is more than an hour before the database's own clock, else <c>"db-clock"</c>, so a switch of time source shows and a run on another day is the same file.
/// </summary>
internal static class NotificationsGolden
{
    public static GoldenSet Set { get; } = new(
        "notifications",
        "notifications_golden_template",
        NotificationsSeed.RunAsync,
        [
            Rows("notifications.notifications", "t.notification_id", "sent_at"),
            Rows("notifications.user_notifications", "t.id", "read_at", "created_at"),
            Rows("notifications.user_devices", "t.id", "last_accessed_at", "registered_at"),
            Rows("notifications.notifier_reminders", "t.id", "updated_at"),
            Rows("notifications.notifier_runs", "t.id", "started_at", "finished_at"),
            Rows("notifications.notifier_sent_messages", "t.id", "sent_at"),
            Rows("notifications.class_scheduled_notifications", "t.id", "last_run_at", "created_at", "updated_at"),
            Rows("notifications.class_scheduled_notification_runs", "t.id", "run_at"),
            Rows("notifications.class_scheduled_events", "t.id", "created_at", "updated_at", "deleted_at"),
            Rows("notifications.member_event_settings", "t.id", "client_updated_at", "server_updated_at"),
            Rows("platform.outbound_messages", "t.id", "next_attempt_at", "created_at", "sent_at", "claimed_at"),
            Rows("platform.admin_access_log", "t.id", "accessed_at"),
            "platform.outbox (created_at, event_type, payload)|select public.golden_clock(t.created_at)::text || ' | ' || t.event_type || ' | ' || t.payload::text from platform.outbox t order by t.created_at, t.event_type, t.payload::text",
        ],
        null);

    private static string Rows(string table, string key, params string[] stamps)
    {
        var pairs = string.Join(", ", stamps.Select(s => $"'{s}', public.golden_clock(t.{s})"));
        return $"{table}|select (to_jsonb(t) || jsonb_build_object({pairs}))::text from {table} t order by {key}";
    }
}

/// <summary>
/// A scenario on the notifications template. The push service is the real <c>FcmPushSender</c> on a recording primary handler (<see cref="RecordingFcm"/>) and the notifier the real
/// <c>Notifier</c> on <see cref="RecordingNotifier"/>, with the address <c>http://notifier.invalid/</c>: what each was sent is written to the transcript after the answer that caused it.
/// Both workers are ticked in-process (<see cref="TickSchedulesAsync"/>, <see cref="TickDrainAsync"/>): no worker is ever started.
/// </summary>
internal sealed class NotificationsRun : IAsyncDisposable
{
    private static readonly Regex DatabaseStamp = new(@"""(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})""", RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private readonly FcmRecording fcm;
    private readonly NotifierRecording notifier;

    private NotificationsRun(GoldenScenario run, FcmRecording fcm, NotifierRecording notifier)
    {
        Run = run;
        this.fcm = fcm;
        this.notifier = notifier;
    }

    public GoldenScenario Run { get; }

    /// <summary>
    /// The transcript. A wire stamp (<c>yyyy-MM-dd HH:mm:ss</c>) within an hour of the machine's own clock is a value the database's clock gave (a row made by a route leaves its
    /// <c>created_at</c> to the database) and is written <c>"db-clock"</c>; a stamp from the fixed clock (2026-01-01) or a seed literal stays as it is, so a change of time source still shows.
    /// </summary>
    public string Transcript => DatabaseStamp.Replace(Run.Transcript, match => IsDatabaseClock(match.Groups[1].Value) ? "\"db-clock\"" : match.Value);

    /// <summary>A fresh copy of the template. <paramref name="pushConfigured"/> false starts it with no push credentials (the three push routes refuse).</summary>
    public static async Task<NotificationsRun> StartAsync(string name, bool pushConfigured = true, Action<IServiceCollection>? configure = null)
    {
        var fcm = new FcmRecording();
        var notifier = new NotifierRecording();
        var settings = new Dictionary<string, string>
        {
            ["TSR_GOOGLE_SERVICE_ACCOUNT_B64"] = pushConfigured ? ServiceAccount.Value : string.Empty,
            ["TSR_NOTIFIER_URL"] = "http://notifier.invalid/",
        };
        var run = await GoldenScenario.StartAsync(
            name,
            services =>
            {
                // A new handler per call (the client factory disposes the ones it builds); the log is shared.
                services.AddHttpClient(FcmPushSender.HttpClientName).ConfigurePrimaryHttpMessageHandler(() => new RecordingFcm(fcm));
                services.AddHttpClient(nameof(INotifier)).ConfigurePrimaryHttpMessageHandler(() => new RecordingNotifier(notifier));
                configure?.Invoke(services);
            },
            NotificationsGolden.Set,
            settings);
        var started = new NotificationsRun(run, fcm, notifier);
        await started.ProveStubsAsync();
        return started;
    }

    /// <summary>A request as one seeded member (uid and address as the seed gives them), then what it sent to the outside services.</summary>
    public Task<GoldenReply> AsAsync(int token, HttpMethod method, string path, string? json = null) =>
        SendAsync(token.ToString(CultureInfo.InvariantCulture), [.. TestApi.SignedInAs("uid-" + token, MembershipTestKit.EmailOf(token))], method, path, json);

    /// <summary>A request as the seeded guest (a signed-in account with no member token: it holds no permission).</summary>
    public Task<GoldenReply> AsGuestAsync(HttpMethod method, string path, string? json = null) =>
        SendAsync("guest", [.. TestApi.SignedInAs("uid-guest", NotificationsSeed.GuestAddress)], method, path, json);

    /// <summary>A request with nobody signed in.</summary>
    public Task<GoldenReply> AsNobodyAsync(HttpMethod method, string path, string? json = null) =>
        SendAsync("nobody", [new(TestApi.Outcome, "missing")], method, path, json);

    /// <summary>Sends one request, then writes the push and notifier requests it caused, after the answer (the sends of one request sorted by device: sixteen run at once).</summary>
    public async Task<GoldenReply> SendAsync(string who, IReadOnlyList<KeyValuePair<string, string>> headers, HttpMethod method, string path, string? json = null, bool recordBody = true)
    {
        var reply = await Run.SendAsync(who, headers, method, path, json, recordBody);
        WriteOutsideCalls();
        return reply;
    }

    public Task RowsAsync(string label) => Run.AppendRowsAsync(label);

    /// <summary>One tick of the class-schedules worker on this copy, in-process. The only way a test reaches that tick (plan, "Tests that resolve NotificationsContext").</summary>
    public async Task<ScheduleReport> TickSchedulesAsync()
    {
        await using var scope = Run.Services.CreateAsyncScope();
        var report = await ClassScheduleSend.TickAsync(
            scope.ServiceProvider.GetRequiredService<NotificationsContext>(),
            scope.ServiceProvider.GetRequiredService<Permissions>(),
            GoldenScenario.Clock,
            NullLogger.Instance,
            CancellationToken.None);
        WriteOutsideCalls();
        return report;
    }

    /// <summary>One tick of the push drain on this copy, in-process, through the real push sender on the recording handler.</summary>
    public async Task<DrainReport> TickDrainAsync()
    {
        await using var scope = Run.Services.CreateAsyncScope();
        var report = await PushDrain.TickAsync(
            scope.ServiceProvider.GetRequiredService<NpgsqlDataSource>(),
            scope.ServiceProvider.GetRequiredService<IPushSender>(),
            GoldenScenario.Clock,
            NullLogger.Instance,
            CancellationToken.None);
        WriteOutsideCalls();
        return report;
    }

    /// <summary>The lines of the outside services not yet written to the transcript (a test of the stubs themselves reads them).</summary>
    public IReadOnlyList<string> DrainOutsideCalls() => [.. fcm.Drain(), .. notifier.Drain()];

    public ValueTask DisposeAsync() => Run.DisposeAsync();

    private static bool IsDatabaseClock(string stamp) =>
        DateTime.TryParseExact(stamp, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var value)
        && Math.Abs((DateTime.UtcNow - value).TotalMinutes) < 60;

    private void WriteOutsideCalls()
    {
        foreach (var line in DrainOutsideCalls())
        {
            Run.Note(line);
        }
    }

    // Before any scenario: the push and notifier clients must be the recording ones. A request to a name that never resolves is answered by the stub, or the scenario does not start.
    private async Task ProveStubsAsync()
    {
        var clients = Run.Services.GetRequiredService<IHttpClientFactory>();
        foreach (var name in new[] { FcmPushSender.HttpClientName, nameof(INotifier) })
        {
            using var client = clients.CreateClient(name);
            using var request = new HttpRequestMessage(HttpMethod.Get, "https://stub-proof.invalid/" + name);
            using var response = await client.SendAsync(request);
            if (response.Headers.Contains(RecordingStub.Header) is false)
            {
                throw new InvalidOperationException($"The {name} client is not on a recording handler: a test must never reach a real service.");
            }
        }

        fcm.Drain();
        notifier.Drain();
    }

    private static class ServiceAccount
    {
        // A key made for this process only and never stored: nothing it signs is accepted by any real service.
        public static readonly string Value = Build();

        private static string Build()
        {
            using var key = RSA.Create(2048);
            var account = new Dictionary<string, string>
            {
                ["project_id"] = "gold-project",
                ["client_email"] = "push@gold-project.invalid",
                ["private_key"] = key.ExportPkcs8PrivateKeyPem(),
            };
            return Convert.ToBase64String(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(account)));
        }
    }
}

/// <summary>What a recording handler marks on every answer, so a test can see that a stub (and not a network) answered.</summary>
internal static class RecordingStub
{
    public const string Header = "X-Recording-Stub";
}

/// <summary>The push service's requests of one scenario: the token-claims line first, then the sends sorted by device.</summary>
internal sealed class FcmRecording
{
    private readonly object gate = new();
    private readonly List<(int Rank, string Device, string Line)> lines = [];

    public void Add(int rank, string device, string line)
    {
        lock (gate)
        {
            lines.Add((rank, device, line));
        }
    }

    public List<string> Drain()
    {
        lock (gate)
        {
            var taken = lines.OrderBy(l => l.Rank).ThenBy(l => l.Device, StringComparer.Ordinal).ThenBy(l => l.Line, StringComparer.Ordinal).Select(l => l.Line).ToList();
            lines.Clear();
            return taken;
        }
    }
}

/// <summary>The notifier's requests of one scenario, in the order they were made, and whether it answers 503.</summary>
internal sealed class NotifierRecording
{
    private readonly object gate = new();
    private readonly List<string> lines = [];

    public bool Down { get; set; }

    public void Add(string line)
    {
        lock (gate)
        {
            lines.Add(line);
        }
    }

    public List<string> Drain()
    {
        lock (gate)
        {
            var taken = lines.ToList();
            lines.Clear();
            return taken;
        }
    }
}

/// <summary>
/// The push service as a recording stub (the primary handler of <c>FcmPushSender</c>'s client). The token endpoint answers an access token and records the decoded claims of the signed request (the signature varies
/// with the key); a send is recorded with its body, device by device, and answered by the device id: ending <c>-gone</c> 404 UNREGISTERED (a dead token), ending <c>-busy</c> 503, any other 200.
/// A request to any other address is recorded as unexpected and answered 400: nothing leaves the process.
/// </summary>
internal sealed class RecordingFcm(FcmRecording log) : HttpMessageHandler
{
    private const string TokenUrl = "https://oauth2.googleapis.com/token";
    private const string SendUrl = "https://fcm.googleapis.com/v1/projects/gold-project/messages:send";

    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var url = request.RequestUri!.ToString();
        var body = request.Content is null ? string.Empty : await request.Content.ReadAsStringAsync(cancellationToken);
        var response = (request.Method.Method, url) switch
        {
            ("POST", TokenUrl) => Token(body),
            ("POST", SendUrl) => Send(request, body),
            _ => Unexpected(request.Method.Method, url),
        };
        response.Headers.Add(RecordingStub.Header, "fcm");
        return response;
    }

    private HttpResponseMessage Token(string form)
    {
        var assertion = System.Web.HttpUtility.ParseQueryString(form)["assertion"] ?? string.Empty;
        var claims = assertion.Split('.') is { Length: 3 } parts ? Encoding.UTF8.GetString(Base64UrlDecode(parts[1])) : "(no assertion)";
        log.Add(0, string.Empty, "fcm: token claims " + claims);
        return Json(HttpStatusCode.OK, """{"access_token":"stub-access-token","expires_in":3600}""");
    }

    private HttpResponseMessage Send(HttpRequestMessage request, string body)
    {
        using var document = JsonDocument.Parse(body);
        var device = document.RootElement.GetProperty("message").GetProperty("token").GetString() ?? string.Empty;
        var bearer = request.Headers.Authorization?.ToString();
        log.Add(1, device, "fcm: send " + device + " " + body + (bearer == "Bearer stub-access-token" ? string.Empty : " (authorization: " + bearer + ")"));
        if (device.EndsWith("-gone", StringComparison.OrdinalIgnoreCase))
        {
            return Json(
                HttpStatusCode.NotFound,
                """{"error":{"code":404,"message":"Requested entity was not found.","status":"NOT_FOUND","details":[{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"UNREGISTERED"}]}}""");
        }

        return device.EndsWith("-busy", StringComparison.OrdinalIgnoreCase)
            ? Json(HttpStatusCode.ServiceUnavailable, """{"error":{"code":503,"message":"The service is currently unavailable.","status":"UNAVAILABLE"}}""")
            : Json(HttpStatusCode.OK, """{"name":"projects/gold-project/messages/stub"}""");
    }

    private HttpResponseMessage Unexpected(string method, string url)
    {
        log.Add(2, url, "fcm: unexpected " + method + " " + url);
        return Json(HttpStatusCode.BadRequest, """{"error":{"code":400,"message":"stub: unexpected request","status":"INVALID_ARGUMENT"}}""");
    }

    private static HttpResponseMessage Json(HttpStatusCode status, string body) =>
        new(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    private static byte[] Base64UrlDecode(string text)
    {
        var padded = text.Replace('-', '+').Replace('_', '/');
        return Convert.FromBase64String(padded.PadRight(padded.Length + ((4 - (padded.Length % 4)) % 4), '='));
    }
}

/// <summary>The notifier as a recording stub: <c>notifier: METHOD /path body</c>, answered 200 with a small canned body, or 503 while the recording says it is down.</summary>
internal sealed class RecordingNotifier(NotifierRecording log) : HttpMessageHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var body = request.Content is null ? string.Empty : await request.Content.ReadAsStringAsync(cancellationToken);
        log.Add("notifier: " + request.Method.Method + " " + request.RequestUri!.PathAndQuery + (body.Length == 0 ? string.Empty : " " + body));
        var response = log.Down
            ? new HttpResponseMessage(HttpStatusCode.ServiceUnavailable) { Content = new StringContent("""{"error":"stub: notifier down"}""", Encoding.UTF8, "application/json") }
            : new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("""{"ok":true,"stub":"notifier"}""", Encoding.UTF8, "application/json") };
        response.Headers.Add(RecordingStub.Header, "notifier");
        return response;
    }
}

/// <summary>
/// The synthetic members, classes, devices, inbox rows, history, scheduled notifications, events and settings of the notifications goldens: tokens 900301 to 900399, addresses on .invalid
/// (one on @demo.invalid), class ids 98501 and up (the access golden uses 98501 to 98505 too, but each set has its own template database). Every timestamp is a literal before the scenarios'
/// fixed instant (2026-01-01T00:00:00Z); no date is relative to the machine's clock. Free texts hold a plus, quotes, angle brackets, an ampersand, an HTML entity, Arabic, an emoji and a line break.
/// A change of this seed changes every golden file: add data a scenario needs with <c>run.Run.ExecuteAsync</c> on its own copy instead.
/// </summary>
internal static class NotificationsSeed
{
    public const int Admin = 900301;
    public const int Sender = 900302;
    public const int Plain = 900303;
    public const int Student = 900304;
    public const int Removed = 900305;
    public const int Teacher2 = 900306;
    public const int Demo = 900307;
    public const int Crowd = 900308;
    public const int Ladies = 900309;
    public const int Taker = 900310;
    public const int Student3 = 900311;
    public const int Bare = 900312;

    public const int ClassOne = 98501;
    public const int ClassTwo = 98502;
    public const int ClassClosed = 98503;
    public const int ClassBare = 98504;

    public const int SlotLive = 98511;
    public const int SlotOther = 98512;
    public const int SlotDeleted = 98513;

    public const string GuestAddress = "guest@example.invalid";

    /// <summary>A text with a plus, quotes, angle brackets, an ampersand, an HTML entity, Arabic, an emoji and a line break.</summary>
    public const string Odd = "Zoë \"Q\" <b> + & &amp; أحمد 🙂 Ünï\nline two";

    private const string DeviceKeyA = "devicekey-aaaaaaaa1";
    private const string DeviceKeyB = "devicekey-bbbbbbbb2";

    public static async Task RunAsync(string ownerConnection)
    {
        var sql = new StringBuilder();
        Clock(sql);
        Members(sql);
        Classes(sql);
        Devices(sql);
        Inbox(sql);
        Scheduled(sql);
        Calendar(sql);

        await using var connection = new NpgsqlConnection(ownerConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql.ToString(), connection);
        await command.ExecuteNonQueryAsync();
    }

    private static string Q(string? value) => MembershipTestKit.Quote(value);

    private static void Add(StringBuilder sql, FormattableString text) => sql.Append(text.ToString(CultureInfo.InvariantCulture)).Append(' ');

    // The value as JSON when it is more than an hour before the database's own clock (a seed literal, the fixed clock), else "db-clock".
    private static void Clock(StringBuilder sql) =>
        sql.Append("""
            create function public.golden_clock(value timestamptz) returns jsonb language sql stable as $f$
              select case when value is null then 'null'::jsonb when value < now() - interval '1 hour' then to_jsonb(value) else '"db-clock"'::jsonb end
            $f$;
            """).Append(' ');

    private static void Members(StringBuilder sql)
    {
        (int Token, string Name, string? Gender, string Email)[] members =
        [
            (Admin, "Note Admin &amp; Sons", "1", MembershipTestKit.EmailOf(Admin)),
            (Sender, "Zoë Sender \"Q\" + Co", "1", MembershipTestKit.EmailOf(Sender)),
            (Plain, "Plain Member", "1", MembershipTestKit.EmailOf(Plain)),
            (Student, "Student One", "1", MembershipTestKit.EmailOf(Student)),
            (Removed, "Removed Student", "1", MembershipTestKit.EmailOf(Removed)),
            (Teacher2, "Teacher Two", "1", MembershipTestKit.EmailOf(Teacher2)),
            (Demo, "Demo Reviewer", "1", "m900307@demo.invalid"),
            (Crowd, "Crowded Member", "1", MembershipTestKit.EmailOf(Crowd)),
            (Ladies, "Ladies Member", "2", MembershipTestKit.EmailOf(Ladies)),
            (Taker, "Taker Owner", "1", MembershipTestKit.EmailOf(Taker)),
            (Student3, "Student Three", "1", MembershipTestKit.EmailOf(Student3)),
            (Bare, "Bare Student", "1", MembershipTestKit.EmailOf(Bare)),
        ];
        foreach (var (token, name, gender, email) in members)
        {
            Add(sql, $"insert into identity.users (token, email, firebase_uid) values ({token}, {Q(email)}, {Q("uid-" + token)});");
            Add(sql, $"insert into membership.member_profiles (user_id, name, gender) select id, {Q(name)}, {Q(gender)} from identity.users where token = {token};");
        }

        Add(sql, $"insert into identity.users (token, email, firebase_uid) values (0, {Q(GuestAddress)}, 'uid-guest');");
        Add(sql, $"insert into access.user_roles (user_id, roleid) select id, 1 from identity.users where token = {Admin};");
    }

    private static void Classes(StringBuilder sql)
    {
        sql.Append("insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; ");
        sql.Append("insert into classes.class_levels (id, code, name, sort_order) values (1, 'SM', 'SALMAN', 1), (2, 'AG', 'ABUZAR', 2), (3, 'MK', 'MIQDAD', 3) on conflict do nothing; ");
        sql.Append("insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, city, country, status, created_by) values ");
        Add(sql, $"({ClassOne}, 'NT-G-501', 7, 'nt1', 'Gold \"One\" + Co', 2, {Sender}, 1, 'Offline', 'Goldville', 'Goldland', 'A', {Admin}), ");
        Add(sql, $"({ClassTwo}, 'NT-G-502', 7, 'nt2', 'Gold Two', 3, {Teacher2}, 1, 'Offline', 'Goldville', 'Goldland', 'A', {Admin}), ");
        Add(sql, $"({ClassClosed}, 'NT-G-503', 7, 'nt3', 'Gold Closed', 2, {Sender}, 1, 'Offline', 'Goldville', 'Goldland', 'I', {Admin}), ");
        Add(sql, $"({ClassBare}, 'NT-G-504', 7, 'nt4', 'Gold Bare', 2, {Sender}, 1, 'Offline', 'Goldville', 'Goldland', 'A', {Admin}); ");
        sql.Append("insert into classes.class_students (class_id, token_no, joined_on, status, removed_at) values ");
        Add(sql, $"({ClassOne}, {Student}, '2025-09-01', 'A', null), ({ClassOne}, {Removed}, '2025-09-01', 'A', '2025-10-01'), ({ClassOne}, {Demo}, '2025-09-01', 'A', null), ");
        Add(sql, $"({ClassTwo}, {Student3}, '2025-09-01', 'A', null), ({ClassBare}, {Bare}, '2025-09-01', 'A', null), ({ClassClosed}, {Plain}, '2025-09-01', 'A', null); ");
        sql.Append("insert into classes.class_schedules (id, class_id, day, hour, minute, timezone, deleted_at) values ");
        Add(sql, $"({SlotLive}, {ClassOne}, 1, 10, 0, 'Asia/Kolkata', null), ({SlotOther}, {ClassOne}, 3, 18, 30, 'Europe/London', null), ({SlotDeleted}, {ClassOne}, 5, 9, 0, 'UTC', timestamptz '2025-11-01 00:00:00+00'); ");
    }

    private static void Devices(StringBuilder sql)
    {
        const string accessed = "timestamptz '2025-12-10 08:00:00+00'";
        (int Token, string Device)[] devices =
        [
            (Admin, "dev-admin-1"), (Sender, "dev-sender-1"), (Plain, "dev-plain-1"), (Plain, "dev-plain-2"), (Student, "dev-s1-ok"), (Student, "dev-shared"), (Demo, "dev-shared"),
            (Removed, "dev-s2-gone"), (Teacher2, "dev-t2-ok"), (Ladies, "dev-f1-ok"), (Ladies, "Dev-F2-Mixed"), (Student3, "dev-s3-busy"), (Taker, "dev-taker-1"),
        ];
        sql.Append("insert into notifications.user_devices (token, device_id, last_accessed_at, registered_at) values ");
        sql.Append(string.Join(", ", devices.Select(d => $"({d.Token}, {Q(d.Device)}, {accessed}, {accessed})")));
        sql.Append("; ");
        // A member holding the cap of 20: the oldest access first, so the least recently used is known.
        sql.Append("insert into notifications.user_devices (token, device_id, last_accessed_at, registered_at) ");
        Add(sql, $"select {Crowd}, 'dev-crowd-' || lpad(n::text, 2, '0'), timestamptz '2025-12-01 00:00:00+00' + make_interval(hours => n), timestamptz '2025-11-01 00:00:00+00' from generate_series(1, 20) n; ");
    }

    // Ten notifications of every audience type in the history, and the inbox rows of the plain member (three: read, unread, a reminder naming a live, a closed and a missing class) and of one other member.
    private static void Inbox(StringBuilder sql)
    {
        const string columns = "title, body, target_audience_criteria, sent_at, created_by, device_count, success_count, failure_count, action_link";
        sql.Append($"insert into notifications.notifications ({columns}) values ");
        Add(sql, $"({Q(Odd)}, {Q("Body " + Odd)}, {Q("""{"type":"ALL_USERS","value":null}""")}, timestamptz '2025-12-30 10:00:00+00', {Admin}, 10, 9, 1, '/classes/98501/dashboard'), ");
        Add(sql, $"({Q("Levels")}, {Q("For levels")}, {Q("""{"type":"CLASS_LEVEL","value":[2,3,99]}""")}, timestamptz '2025-12-29 09:00:00+00', {Admin}, 4, 4, 0, ''), ");
        Add(sql, $"({Q("Reminder")}, {Q("Nudge a teacher")}, {Q("""{"type":"CC_NUDGE","teacher":900302,"classes":[98501,98503,98599]}""")}, timestamptz '2025-12-29 09:00:00+00', {Admin}, 1, 1, 0, null), ");
        Add(sql, $"({Q("Gents")}, {Q("For gents")}, {Q("""{"type":"GENDER","value":["1"]}""")}, timestamptz '2025-12-28 09:00:00+00', {Sender}, 6, 5, 1, null), ");
        Add(sql, $"({Q("Ladies")}, {Q("For ladies")}, {Q("""{"type":"GENDER","value":[2]}""")}, timestamptz '2025-12-27 09:00:00+00', {Admin}, 2, 2, 0, null), ");
        Add(sql, $"({Q("Teachers")}, {Q("For teachers")}, {Q("""{"type":"TEACHERS","value":[98501]}""")}, timestamptz '2025-12-26 09:00:00+00', {Admin}, 1, 1, 0, null), ");
        Add(sql, $"({Q("One class")}, {Q("For a class")}, {Q("""{"type":"CLASS","class_id":98502}""")}, timestamptz '2025-12-25 09:00:00+00', {Admin}, 1, 0, 1, '/classes/98502/dashboard'), ");
        Add(sql, $"({Q("Empty criteria")}, {Q("Nothing named")}, {Q("{}")}, timestamptz '2025-12-24 09:00:00+00', {Admin}, null, null, null, null), ");
        Add(sql, $"({Q("Mystery")}, {Q("Unknown type")}, {Q("""{"type":"MYSTERY"}""")}, timestamptz '2025-12-23 09:00:00+00', 0, 0, 0, 0, null); ");
        // The inbox rows (ids 1 to 3 are the plain member's, 4 the ladies member's).
        sql.Append("insert into notifications.user_notifications (notification_id, user_token, is_read, read_at, created_at) values ");
        Add(sql, $"(1, {Plain}, 1, timestamptz '2025-12-30 11:00:00+00', timestamptz '2025-12-30 10:00:00+00'), (2, {Plain}, 0, null, timestamptz '2025-12-29 09:00:00+00'), ");
        Add(sql, $"(3, {Plain}, 0, null, timestamptz '2025-12-29 09:00:00+00'), (5, {Ladies}, 0, null, timestamptz '2025-12-27 09:00:00+00'); ");
    }

    // The scheduled notifications of class one (ids 1 to 6: ONCE due, ONCE late, WEEKLY due, REMINDER on a live slot, on a deleted slot, a bad zone), a ONCE in class two whose class is at the hourly limit, and their runs.
    private static void Scheduled(StringBuilder sql)
    {
        const string columns = "class_id, created_by, created_by_user_id, title, body, action_link, kind, send_at, weekdays, send_time, tz, class_schedule_id, offset_minutes, repeat_weekly, status, last_run_at, last_run_key, created_at, updated_at";
        const string created = "timestamptz '2025-12-20 08:00:00+00'";
        string By(int token) => $"{token}, (select id from identity.users where token = {token})";
        sql.Append($"insert into notifications.class_scheduled_notifications ({columns}) values ");
        Add(sql, $"({ClassOne}, {By(Sender)}, {Q("Once due " + Odd)}, {Q("Body once due")}, '/classes/98501/syllabus', 'ONCE', timestamp '2025-12-31 23:50:00', null, null, 'UTC', null, null, 0, 'active', null, null, {created}, {created}), ");
        Add(sql, $"({ClassOne}, {By(Sender)}, {Q("Once late")}, {Q("Body once late")}, null, 'ONCE', timestamp '2025-12-31 20:00:00', null, null, 'UTC', null, null, 0, 'active', null, null, {created}, {created}), ");
        Add(sql, $"({ClassOne}, {By(Sender)}, {Q("Weekly due")}, {Q("Body weekly")}, null, 'WEEKLY', null, '3,4', time '23:55', 'UTC', null, null, 0, 'active', null, null, {created}, {created}), ");
        Add(sql, $"({ClassOne}, {By(Sender)}, {Q("Reminder live")}, {Q("Body reminder live")}, null, 'REMINDER', null, null, null, 'Asia/Kolkata', {SlotLive}, -30, 1, 'active', null, null, {created}, {created}), ");
        Add(sql, $"({ClassOne}, {By(Sender)}, {Q("Reminder deleted slot")}, {Q("Body reminder deleted")}, null, 'REMINDER', null, null, null, 'UTC', {SlotDeleted}, -60, 0, 'active', null, null, {created}, {created}), ");
        Add(sql, $"({ClassOne}, {By(Sender)}, {Q("Bad zone")}, {Q("Body bad zone")}, null, 'ONCE', timestamp '2026-02-01 10:00:00', null, null, 'Mars/Phobos', null, null, 0, 'active', null, null, {created}, {created}), ");
        Add(sql, $"({ClassTwo}, {By(Teacher2)}, {Q("Limited class")}, {Q("Body limited")}, null, 'ONCE', timestamp '2025-12-31 23:55:00', null, null, 'UTC', null, null, 0, 'active', null, null, {created}, {created}); ");
        sql.Append("insert into notifications.class_scheduled_notification_runs (scheduled_id, class_id, run_at, notification_id, student_count, device_count, success_count, failure_count, skipped_reason) values ");
        Add(sql, $"(3, {ClassOne}, timestamptz '2025-12-24 23:55:00+00', 7, 3, 2, 2, 0, null), ");
        sql.Append(string.Join(", ", Enumerable.Range(1, 10).Select(n => $"(7, {ClassTwo}, timestamptz '2025-12-31 23:{(10 + n):00}:00+00', null, 1, 1, 1, 0, null)")));
        sql.Append("; ");
    }

    // Class events (ids 1 to 4: the sender's, one whose owner lost the right to send, a deleted one, class two's) and the alert settings of two students, tombstones included.
    private static void Calendar(StringBuilder sql)
    {
        const string columns = "class_id, created_by, created_by_user_id, message, description, action_link, weekdays, send_time, tz, status, created_at, updated_at, deleted_at";
        const string created = "timestamptz '2025-12-15 08:00:00+00'";
        string By(int token) => $"{token}, (select id from identity.users where token = {token})";
        sql.Append($"insert into notifications.class_scheduled_events ({columns}) values ");
        Add(sql, $"({ClassOne}, {By(Sender)}, {Q("Event one " + Odd)}, {Q("Described " + Odd)}, '/classes/98501/syllabus', '1,3,5', time '18:30', 'Asia/Kolkata', 'active', {created}, {created}, null), ");
        Add(sql, $"({ClassOne}, {By(Taker)}, {Q("Event two")}, null, null, '2', time '09:05', 'Europe/London', 'active', {created}, {created}, null), ");
        Add(sql, $"({ClassOne}, {By(Sender)}, {Q("Event three deleted")}, null, null, '4', time '10:00', 'UTC', 'deleted', {created}, {created}, timestamptz '2025-12-16 08:00:00+00'), ");
        Add(sql, $"({ClassTwo}, {By(Teacher2)}, {Q("Event four")}, null, null, '1,7', time '07:00', 'UTC', 'active', {created}, {created}, null); ");
        sql.Append("insert into notifications.member_event_settings (user_id, class_id, event_key, offset_minutes, muted, deleted_for_me, client_updated_at, server_updated_at, device_key) ");
        Add(sql, $"select u.id, s.class_id, s.event_key, s.offset_minutes, s.muted, s.deleted_for_me, s.client_at, s.server_at, s.device_key from identity.users u join (values ");
        Add(sql, $"({Student}, {ClassOne}, 'event:1', -15, 1::smallint, 0::smallint, timestamptz '2025-12-20 10:00:00.123+00', timestamptz '2025-12-20 10:00:01.456+00', {Q(DeviceKeyA)}), ");
        Add(sql, $"({Student}, {ClassOne}, 'event:2', null::int, 0::smallint, 1::smallint, timestamptz '2025-12-21 10:00:00+00', timestamptz '2025-12-21 10:00:02+00', {Q(DeviceKeyB)}), ");
        Add(sql, $"({Student}, {ClassOne}, 'slot:{SlotLive}', -60, 0::smallint, 0::smallint, timestamptz '2025-12-22 10:00:00+00', timestamptz '2025-12-22 10:00:01+00', {Q(DeviceKeyA)}), ");
        Add(sql, $"({Student3}, {ClassTwo}, 'event:4', 0, 0::smallint, 0::smallint, timestamptz '2025-12-22 11:00:00+00', timestamptz '2025-12-22 11:00:01+00', {Q(DeviceKeyB)})) ");
        Add(sql, $"as s(token, class_id, event_key, offset_minutes, muted, deleted_for_me, client_at, server_at, device_key) on u.token = s.token order by u.token, s.event_key;");
    }
}
