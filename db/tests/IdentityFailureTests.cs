using System.Net;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using NUnit.Framework;
using Tsr.Identity.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// Issue 102, failure pins on identity as it is (IDN-R5, R7, R8, R13, R20): what a caller sees, what is stored and what is logged when the database refuses something under a request.
/// Each case runs on its own copy of the identity golden database (<see cref="IdentityRun"/>), so a revoked right or a trigger never reaches another test, and "rows unchanged" starts from a known
/// state. Recorded on today's code, not predicted; each case also asserts that the failure really happened (a 500, or the warning), so a revoke that turned out to do nothing cannot record a success.
/// </summary>
public sealed class IdentityFailureTests
{
    private const string TrackingWarning = "Sign-in tracking failed: {Reason}";
    private static readonly HttpMethod Get = HttpMethod.Get;
    private static readonly HttpMethod Post = HttpMethod.Post;
    private static readonly HttpMethod Delete = HttpMethod.Delete;

    // TC-IDN-R5-01. Today's {Reason} is "PostgresException" (EF's ExecuteUpdate lets Npgsql's exception through). A different type name after the conversion is reported in the pull request, not failed here.
    [Test]
    public async Task A_sign_in_record_that_fails_logs_one_warning_and_serves_the_request()
    {
        var logs = new CapturedLogs();
        await using var run = await IdentityRun.StartAsync("failure-signin-record", services => services.AddSingleton<ILoggerProvider>(logs));
        await run.Run.ExecuteAsync("revoke update on identity.users from tsr_app");
        var before = await SnapshotAsync(run);
        var headers = IdentityGoldenScenarios.Headers(
            "uid-" + IdentitySeed.Plain, MembershipTestKit.EmailOf(IdentitySeed.Plain), true, null, null, ("User-Agent", "FailUA/1.0"), ("X-Device-Info", "Pixel"));

        var reply = await run.SendAsync("plain, tracking headers", headers, Get, "/me/deletion-request");
        await run.RowsAsync("after");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(await SnapshotAsync(run), Is.EqualTo(before));
        var warnings = logs.Warnings.Where(w => w.Template == TrackingWarning).ToList();
        Assert.That(warnings, Has.Count.EqualTo(1), "exactly one warning with the template");
        Assert.That(warnings[0].Reason, Does.Match("^[A-Za-z][A-Za-z0-9_]*$"), "a type name, no address, token or header value");
        GoldenScenario.Check("failure-signin-record", run.Transcript, IdentityGolden.Set);
    }

    // TC-IDN-R7-01 (the other half is TestDeletionTests.A_failure_after_the_devices_were_deleted_and_the_queue_redacted_rolls_the_whole_completion_back).
    [Test]
    public async Task A_completion_whose_event_cannot_be_written_leaves_nothing()
    {
        await using var run = await IdentityRun.StartAsync("failure-complete-event");
        await run.Run.ExecuteAsync("revoke insert on platform.outbox from tsr_app");
        var before = await SnapshotAsync(run);

        var reply = await run.AsAsync(IdentitySeed.Admin, Post, $"/admin/deletion-requests/{IdentitySeed.PendingConfirmedTarget}/complete");
        await run.RowsAsync("after");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.InternalServerError), reply.Body);
        Assert.That(await SnapshotAsync(run), Is.EqualTo(before), "every row of the seven tables and the outbox is as before");
        Assert.That(
            await run.Run.QueryAsync($"select status::text from identity.account_deletion_requests where id = {IdentitySeed.PendingConfirmedTarget}"),
            Is.EqualTo(["pending"]));
        GoldenScenario.Check("failure-complete-event", run.Transcript, IdentityGolden.Set);
    }

    // TC-IDN-R8-01: the four other writes that write a row and an event together.
    [Test]
    public async Task A_deletion_write_whose_event_cannot_be_written_stores_nothing()
    {
        await using var run = await IdentityRun.StartAsync("failure-write-event");
        await run.Run.ExecuteAsync("revoke insert on platform.outbox from tsr_app");
        var before = await RequestsAsync(run);

        var replies = new[]
        {
            await run.AsAsync(IdentitySeed.Plain, Post, "/me/deletion-request", Body("reason", IdentitySeed.Odd)),
            await run.AsAsync(IdentitySeed.Admin, Post, "/admin/deletion-requests", Body("email", IdentitySeed.ClaimAddress)),
            await run.AsAsync(IdentitySeed.Unconfirmed, Delete, "/me/deletion-request"),
            await run.AsAsync(IdentitySeed.Admin, Post, $"/admin/deletion-requests/{IdentitySeed.PendingUnconfirmed}/hold", Body("note", "a note")),
        };
        await run.RowsAsync("after");

        Assert.That(replies.Select(r => r.Status), Is.All.EqualTo(HttpStatusCode.InternalServerError));
        Assert.That(await RequestsAsync(run), Is.EqualTo(before));
        GoldenScenario.Check("failure-write-event", run.Transcript, IdentityGolden.Set);
    }

    // TC-IDN-R13-01: every member route of every domain reads identity first, so one unreadable table fails them all.
    [TestCase("users")]
    [TestCase("account_deletion_requests")]
    public async Task Unreadable_identity_tables_fail_member_routes_as_recorded(string table)
    {
        var scenario = "failure-unreadable-" + table;
        await using var run = await IdentityRun.StartAsync(scenario);
        await run.Run.ExecuteAsync($"revoke select on identity.{table} from tsr_app");
        var before = await SnapshotAsync(run);

        var replies = new[]
        {
            await run.AsAsync(IdentitySeed.Plain, Get, "/me/deletion-request"),
            await run.AsAsync(IdentitySeed.Admin, Get, "/admin/deletion-requests"),
            await run.AsAsync(IdentitySeed.Plain, Get, "/me/permissions"),
        };
        await run.RowsAsync("after");

        Assert.That(replies.Select(r => r.Status), Is.All.EqualTo(HttpStatusCode.InternalServerError));
        Assert.That(await SnapshotAsync(run), Is.EqualTo(before));
        GoldenScenario.Check(scenario, run.Transcript, IdentityGolden.Set);
    }

    // TC-IDN-R20-01: a trigger refuses any change of firebase_uid, so the claim of a member with no uid fails; the tracking update does not change the uid and is not affected.
    // The 500's body is not recorded: today it is the first line of Entity Framework's DbUpdateException ("An error occurred while saving the entity changes"), a text the conversion cannot keep
    // (the claim becomes one SQL statement, which fails with Npgsql's own exception). What must stay is that the request fails with a 500, stores nothing and hands nothing on.
    [Test]
    public async Task A_claim_whose_write_fails_stores_nothing_and_answers_as_recorded()
    {
        var sink = new SinkCalls();
        await using var run = await IdentityRun.StartAsync("failure-claim-write", services => CountProfileSink(services, sink));
        await run.Run.ExecuteAsync(
            """
            create function identity.refuse_uid_change() returns trigger language plpgsql as
            $$ begin raise exception 'uid change refused (test)'; end $$;
            create trigger refuse_uid_change before update on identity.users for each row
              when (new.firebase_uid is distinct from old.firebase_uid) execute function identity.refuse_uid_change();
            """);
        var before = await SnapshotAsync(run);

        var lookup = await run.SendAsync(
            "claim on a lookup route", IdentityGoldenScenarios.Headers("uid-claim-x", IdentitySeed.ClaimAddress, true, "Ignored Name"), Post, "/feedback", """{"clientId":"c-1","text":"salaam"}""",
            recordBody: false);
        var create = await run.SendAsync(
            "claim on a create route", IdentityGoldenScenarios.Headers("uid-claim-x", IdentitySeed.ClaimAddress, true, IdentitySeed.Odd, "https://img.invalid/claim"), Post, "/auth/link", recordBody: false);
        await run.RowsAsync("after");

        Assert.That(new[] { lookup.Status, create.Status }, Is.All.EqualTo(HttpStatusCode.InternalServerError), lookup.Body + create.Body);
        Assert.That(await SnapshotAsync(run), Is.EqualTo(before), "the member's row and profile are as before");
        Assert.That(sink.Count, Is.Zero, "no name or picture was handed on");
        GoldenScenario.Check("failure-claim-write", run.Transcript, IdentityGolden.Set);
    }

    private static string Body(string field, string value) => IdentityGoldenScenarios.Body(field, value);

    // Every row query of the identity set, one text: equal before and after means not one row was touched.
    private static async Task<string> SnapshotAsync(IdentityRun run)
    {
        var parts = new List<string>();
        foreach (var entry in IdentityGolden.Set.RowQueries)
        {
            parts.AddRange(await run.Run.QueryAsync(entry[(entry.IndexOf('|', StringComparison.Ordinal) + 1)..]));
        }

        return string.Join('\n', parts);
    }

    private static async Task<string> RequestsAsync(IdentityRun run) =>
        string.Join('\n', await run.Run.QueryAsync("select row_to_json(t)::text from identity.account_deletion_requests t order by t.id"));

    // The real profile sink (membership's) inside a counter: a claim that stored nothing must not hand a name on.
    private static void CountProfileSink(IServiceCollection services, SinkCalls calls)
    {
        var original = services.Last(d => d.ServiceType == typeof(IProfileSink));
        services.Remove(original);
        services.AddScoped<IProfileSink>(provider =>
            new CountingSink((IProfileSink)ActivatorUtilities.CreateInstance(provider, original.ImplementationType!), calls));
    }

    private sealed class SinkCalls
    {
        private int count;

        public int Count => Volatile.Read(ref count);

        public void Add() => Interlocked.Increment(ref count);
    }

    private sealed class CountingSink(IProfileSink inner, SinkCalls calls) : IProfileSink
    {
        public Task RecordSignInAsync(int userId, string? name, string? picture, bool isNewMember, CancellationToken ct)
        {
            calls.Add();
            return inner.RecordSignInAsync(userId, name, picture, isNewMember, ct);
        }
    }

    // Every warning or worse the host logged: its template, and the value of {Reason} when it has one.
    private sealed class CapturedLogs : ILoggerProvider
    {
        private readonly List<(LogLevel Level, string Template, string? Reason)> entries = [];

        public IEnumerable<(string Template, string? Reason)> Warnings
        {
            get
            {
                lock (entries)
                {
                    return entries.Where(e => e.Level == LogLevel.Warning).Select(e => (e.Template, e.Reason)).ToList();
                }
            }
        }

        public ILogger CreateLogger(string categoryName) => new Capture(this);

        public void Dispose()
        {
        }

        private void Add(LogLevel level, object? state)
        {
            var pairs = state as IReadOnlyList<KeyValuePair<string, object?>> ?? [];
            var template = pairs.FirstOrDefault(p => p.Key == "{OriginalFormat}").Value as string ?? string.Empty;
            var reason = pairs.FirstOrDefault(p => p.Key == "Reason").Value as string;
            lock (entries)
            {
                entries.Add((level, template, reason));
            }
        }

        private sealed class Capture(CapturedLogs owner) : ILogger
        {
            public IDisposable? BeginScope<TState>(TState state)
                where TState : notnull => null;

            public bool IsEnabled(LogLevel logLevel) => logLevel >= LogLevel.Warning;

            public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
            {
                if (IsEnabled(logLevel))
                {
                    owner.Add(logLevel, state);
                }
            }
        }
    }
}
