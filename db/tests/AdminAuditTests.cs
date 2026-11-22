using System.Collections.Concurrent;
using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Npgsql;
using NUnit.Framework;
using Tsr.Platform.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// PHP writes an admin_access_log row (platform's table) when a privileged caller manages a class: GET /classes/{id}/manage, PUT /classes/{id} and POST /classes, after the permission
/// check and before the body is validated. Hurl cannot see the table, so these go through the API as the limited role and read it back. Role 0 and refused calls leave no row.
/// </summary>
public sealed class AdminAuditTests
{
    private const int Admin = 901001;
    private const int Teacher = 901002;
    private const int ClassId = 9901;

    private const string AuditFailedMessage = "The admin access log row could not be written";

    private readonly CaptureProvider logs = new();
    private MembershipTestKit kit = null!;
    private WebApplicationFactory<Program> direct = null!;

    [OneTimeSetUp]
    public void Start()
    {
        kit = new MembershipTestKit(services => services.AddSingleton<ILoggerProvider>(logs));
        direct = TestApi.Create().WithWebHostBuilder(builder => builder.ConfigureTestServices(services => services.AddSingleton<ILoggerProvider>(logs)));
    }

    [OneTimeTearDown]
    public void Stop()
    {
        direct.Dispose();
        kit.Dispose();
    }

    /// <summary>Every line any logger of the API under test writes: category, level, message and the exception's type.</summary>
    private sealed record Line(string Category, LogLevel Level, string Message, string? ExceptionType);

    private sealed class CaptureProvider : ILoggerProvider
    {
        public ConcurrentQueue<Line> Lines { get; } = new();

        public ILogger CreateLogger(string categoryName) => new CaptureLogger(categoryName, Lines);

        public void Dispose()
        {
        }
    }

    private sealed class CaptureLogger(string category, ConcurrentQueue<Line> lines) : ILogger
    {
        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            lines.Enqueue(new Line(category, logLevel, formatter(state, exception), exception?.GetType().Name));
    }

    [SetUp]
    public async Task SeedAsync()
    {
        logs.Lines.Clear();
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync("truncate platform.admin_access_log, classes.class_students, classes.class_schedules, classes.classes restart identity cascade");
        var admin = await MembershipTestKit.AddMemberAsync(Admin, "Audit Admin", "1");
        await MembershipTestKit.AddMemberAsync(Teacher, "Audit Teacher", "1");
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({admin}, 1)");
        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + $"insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values ({ClassId}, 'AU-1', 1, 'aulink1', 'Audit Class', 3, {Teacher}, 1, 'Offline', 'A', {Admin})");
    }

    private static Task<long> RowsAsync(string where = "true") => MembershipTestKit.CountAsync("platform.admin_access_log", where);

    [Test]
    public async Task Managing_a_class_as_an_admin_writes_one_row_with_the_request_details()
    {
        var reply = await kit.SendAsync(Admin, HttpMethod.Get, $"/classes/{ClassId}/manage");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(await RowsAsync(), Is.EqualTo(1));
        var row = await TestDatabase.RowAsync("select token, roleid, page, method, session_id from platform.admin_access_log");
        Assert.That(row!["token"], Is.EqualTo(Admin.ToString(System.Globalization.CultureInfo.InvariantCulture)));
        Assert.That(row["roleid"], Is.EqualTo("1"));
        Assert.That(row["page"], Is.EqualTo($"/classes/{ClassId}/manage"));
        Assert.That(row["method"], Is.EqualTo("GET"));
        Assert.That(row["session_id"], Is.Null);
    }

    [Test]
    public async Task A_refused_caller_leaves_no_row()
    {
        var reply = await kit.SendAsync(Teacher, HttpMethod.Get, $"/classes/{ClassId}/manage");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(await RowsAsync(), Is.EqualTo(0));
    }

    [Test]
    public async Task An_update_that_fails_validation_still_leaves_its_row_because_PHP_logs_before_the_body_is_read()
    {
        var reply = await kit.SendAsync(Admin, HttpMethod.Put, $"/classes/{ClassId}", "{}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), reply.Body);
        Assert.That(await RowsAsync("method = 'PUT' and page = '/classes/" + ClassId + "'"), Is.EqualTo(1));
    }

    [Test]
    public async Task Creating_a_class_logs_after_the_gender_and_permission_checks_and_before_the_rest_of_the_body()
    {
        var invalidGender = await kit.SendAsync(Admin, HttpMethod.Post, "/classes", """{"gender": 5}""");
        Assert.That(invalidGender.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(await RowsAsync(), Is.EqualTo(0), "refused before the log");

        var invalidLevel = await kit.SendAsync(Admin, HttpMethod.Post, "/classes", """{"gender": 1}""");
        Assert.That(invalidLevel.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(await RowsAsync("method = 'POST' and page = '/classes'"), Is.EqualTo(1));
    }

    [Test]
    public async Task Only_the_privileged_roles_are_logged_and_long_values_are_cut_to_the_columns()
    {
        await TestDatabase.ExecuteAsync("insert into access.user_permissions (user_id, permission, reason) select id, 'classes:update:all', 'audit test' from identity.users where token = " + Teacher);
        var granted = await kit.SendAsync(Teacher, HttpMethod.Get, $"/classes/{ClassId}/manage");
        Assert.That(granted.Status, Is.EqualTo(HttpStatusCode.OK), "the grant lets this role-0 caller manage");
        Assert.That(await RowsAsync(), Is.EqualTo(0), "role 0 is not privileged");

        var reply = await kit.SendAsync(Admin, HttpMethod.Get, $"/classes/{ClassId}/manage?x={new string('q', 400)}", userAgent: new string('a', 600));
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        var row = await TestDatabase.RowAsync("select char_length(user_agent) as ua, char_length(page) as pg from platform.admin_access_log");
        Assert.That(row!["ua"], Is.EqualTo("512"));
        Assert.That(row["pg"], Is.EqualTo($"/classes/{ClassId}/manage".Length.ToString(System.Globalization.CultureInfo.InvariantCulture)), "the query string is not part of the page");
    }

    private const string RefuseAuditTrigger =
        """
        create or replace function public.tsr_test_refuse_audit() returns trigger language plpgsql as $$ begin raise exception 'audit refused (test)'; end $$;
        create trigger tsr_test_refuse_audit before insert on platform.admin_access_log for each row execute function public.tsr_test_refuse_audit();
        """;

    private const string SlowAuditTrigger =
        """
        create or replace function public.tsr_test_slow_audit() returns trigger language plpgsql as $$ begin perform pg_sleep(2); return new; end $$;
        create trigger tsr_test_slow_audit before insert on platform.admin_access_log for each row execute function public.tsr_test_slow_audit();
        """;

    private const string Columns = "user_id, token, roleid, page, method, ip, user_agent, referer, session_id, accessed_at is not null as stamped";

    private static Task DropAuditTriggersAsync() => TestDatabase.ExecuteAsync(
        "drop trigger if exists tsr_test_refuse_audit on platform.admin_access_log; drop function if exists public.tsr_test_refuse_audit(); "
        + "drop trigger if exists tsr_test_slow_audit on platform.admin_access_log; drop function if exists public.tsr_test_slow_audit()");

    [Test]
    public async Task An_audit_write_that_fails_is_logged_and_the_action_still_answers()
    {
        await TestDatabase.ExecuteAsync(RefuseAuditTrigger);
        try
        {
            var reply = await kit.SendAsync(Admin, HttpMethod.Get, $"/classes/{ClassId}/manage");

            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
            Assert.That(await RowsAsync(), Is.EqualTo(0));
            var audit = logs.Lines.Where(l => l.Message == AuditFailedMessage).ToList();
            Assert.That(audit, Has.Count.EqualTo(1));
            Assert.That(audit[0].Category, Is.EqualTo("Tsr.Platform.Api.PlatformCommands"));
            Assert.That(audit[0].Level, Is.EqualTo(LogLevel.Warning));
            Assert.That(audit[0].ExceptionType, Is.EqualTo(nameof(PostgresException)));
        }
        finally
        {
            await DropAuditTriggersAsync();
        }
    }

    // The one difference of the move off Entity Framework (issue 98): EF logged "Failed executing DbCommand" at Error (category Microsoft.EntityFrameworkCore.Database.Command)
    // before the audit's own line. Now only the audit's Warning is left.
    [Test]
    public async Task The_lines_a_failed_audit_write_leaves_in_the_log_are_recorded()
    {
        await TestDatabase.ExecuteAsync(RefuseAuditTrigger);
        try
        {
            await kit.SendAsync(Admin, HttpMethod.Get, $"/classes/{ClassId}/manage");

            var lines = logs.Lines.Where(l => l.Level >= LogLevel.Warning).Select(l => $"{l.Category}|{l.Level}|{l.ExceptionType}").ToList();
            TestContext.Out.WriteLine(string.Join('\n', lines));
            Assert.That(string.Join(";", lines), Is.EqualTo("Tsr.Platform.Api.PlatformCommands|Warning|PostgresException"));
        }
        finally
        {
            await DropAuditTriggersAsync();
        }
    }

    [Test]
    public async Task The_stored_row_holds_every_column_as_the_request_gave_it()
    {
        var reply = await kit.SendAsync(Admin, HttpMethod.Get, $"/classes/{ClassId}/manage?x=1", userAgent: "AuditAgent/1.0");
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        var row = await TestDatabase.RowAsync($"select {Columns} from platform.admin_access_log");
        var userId = await TestDatabase.ScalarAsync<int>($"select id from identity.users where token = {Admin}", TestDatabase.OwnerConnection);

        Assert.That(row!["user_id"], Is.EqualTo(userId.ToString(System.Globalization.CultureInfo.InvariantCulture)));
        Assert.That(row["token"], Is.EqualTo("901001"));
        Assert.That(row["roleid"], Is.EqualTo("1"));
        Assert.That(row["page"], Is.EqualTo($"/classes/{ClassId}/manage"));
        Assert.That(row["method"], Is.EqualTo("GET"));
        Assert.That(row["ip"], Is.EqualTo(string.Empty), "no peer address is the empty text, not null");
        Assert.That(row["user_agent"], Is.EqualTo("AuditAgent/1.0"));
        Assert.That(row["referer"], Is.Null, "no Referer header is NULL, not an empty text");
        Assert.That(row["session_id"], Is.Null);
        Assert.That(row["stamped"], Is.EqualTo("true"));
    }

    [Test]
    public async Task A_direct_call_stores_every_column_including_the_referer_and_cuts_to_the_column_lengths()
    {
        await using var scope = direct.Services.CreateAsyncScope();
        var context = AuditRequest(scope, "/p" + new string('q', 400), "PATCH-VERY-LONG-METHOD", "AuditAgent/2.0", "https://referer.example.invalid/x");

        await PlatformCommands.RecordAdminAccessAsync(context, 7, 901003, 4, CancellationToken.None);

        var row = await TestDatabase.RowAsync($"select {Columns}, char_length(page) as page_length from platform.admin_access_log");
        Assert.That(row!["user_id"], Is.EqualTo("7"));
        Assert.That(row["token"], Is.EqualTo("901003"));
        Assert.That(row["roleid"], Is.EqualTo("4"));
        Assert.That(row["page_length"], Is.EqualTo("255"));
        Assert.That(row["method"], Is.EqualTo("PATCH-VERY"));
        Assert.That(row["ip"], Is.EqualTo("203.0.113.7"));
        Assert.That(row["user_agent"], Is.EqualTo("AuditAgent/2.0"));
        Assert.That(row["referer"], Is.EqualTo("https://referer.example.invalid/x"));
        Assert.That(row["session_id"], Is.Null);
        Assert.That(row["stamped"], Is.EqualTo("true"));
    }

    private static DefaultHttpContext AuditRequest(AsyncServiceScope scope, string path, string method, string userAgent, string referer)
    {
        var context = new DefaultHttpContext { RequestServices = scope.ServiceProvider };
        context.Request.Path = path;
        context.Request.Method = method;
        context.Request.Headers.UserAgent = userAgent;
        context.Request.Headers.Referer = referer;
        context.Connection.RemoteIpAddress = IPAddress.Parse("203.0.113.7");
        return context;
    }

    [Test]
    public async Task A_cancel_while_the_insert_runs_reaches_the_caller_and_is_not_logged_and_no_row_is_written()
    {
        await TestDatabase.ExecuteAsync(SlowAuditTrigger);
        try
        {
            await using var scope = direct.Services.CreateAsyncScope();
            var context = AuditRequest(scope, "/classes/1/manage", "GET", "AuditAgent/3.0", "https://referer.example.invalid/y");
            using var cancelling = new CancellationTokenSource();
            var running = PlatformCommands.RecordAdminAccessAsync(context, 7, 901003, 1, cancelling.Token);
            var deadline = DateTime.UtcNow.AddSeconds(10);
            while (!running.IsCompleted)
            {
                var sleeping = await TestDatabase.ScalarAsync<long>(
                    "select count(*) from pg_stat_activity where wait_event = 'PgSleep' and query like '%insert into platform.admin_access_log%'",
                    TestDatabase.OwnerConnection);
                if (sleeping > 0)
                {
                    break;
                }

                Assert.That(DateTime.UtcNow, Is.LessThan(deadline), "the held insert never started");
                await Task.Delay(20);
            }

            Assert.That(running.IsCompleted, Is.False, "the write finished before the cancel, so nothing was held");
            await cancelling.CancelAsync();
            var thrown = await Assert.CatchAsync(() => running.WaitAsync(TimeSpan.FromSeconds(10)));

            Assert.That(thrown, Is.InstanceOf<OperationCanceledException>());
            Assert.That(await RowsAsync(), Is.EqualTo(0));
            Assert.That(logs.Lines.Where(l => l.Message == AuditFailedMessage), Is.Empty, "a cancelled write is not an audit failure");
        }
        finally
        {
            await DropAuditTriggersAsync();
        }
    }

    [Test]
    public async Task A_cancel_before_the_write_reaches_the_caller_and_writes_nothing()
    {
        await using var scope = direct.Services.CreateAsyncScope();
        var context = AuditRequest(scope, "/classes/1/manage", "GET", "AuditAgent/3.0", "https://referer.example.invalid/y");
        using var cancelled = new CancellationTokenSource();
        await cancelled.CancelAsync();

        await Assert.ThatAsync(
            () => PlatformCommands.RecordAdminAccessAsync(context, 7, 901003, 1, cancelled.Token),
            Throws.InstanceOf<OperationCanceledException>());
        Assert.That(await RowsAsync(), Is.EqualTo(0));
    }

    [Test]
    public async Task A_role_that_is_not_privileged_writes_nothing()
    {
        await using var scope = direct.Services.CreateAsyncScope();
        var context = AuditRequest(scope, "/classes/1/manage", "GET", "AuditAgent/3.0", "https://referer.example.invalid/y");

        await PlatformCommands.RecordAdminAccessAsync(context, 7, 901003, 0, CancellationToken.None);

        Assert.That(await RowsAsync(), Is.EqualTo(0));
    }
}
