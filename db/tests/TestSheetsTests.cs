using System.Collections.Concurrent;
using System.Net;
using System.Text.Json.Nodes;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Npgsql;
using NUnit.Framework;
using Tsr.Assessment.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>
/// Lane sheets: the standard MCQ update and the quiz competition admin against a real database through the API as the limited role, with FAKE Google Sheets at the boundary (<see cref="FakeSheets"/>, shaped as PHP's
/// GoogleSheetsHelper returns ranges: rows of text, a row ends at its last non-empty cell, an empty range is no rows). Neither stack has Google credentials and no request goes to Google; Hurl proves the refusals and the
/// "sheet cannot be read" answers on both sides (domains/assessment/spec/tests/admin-quiz*.hurl, standard-mcq-*.hurl), this proves everything past the boundary on the new API.
/// World: the admin 923001 holds the named grants quiz:admin and quiz:reset (no role holds them), 923002 only quiz:admin, 923003 only standard-mcqs:update, 923004 nothing. The quiz members are 923101 to 923110 (see <c>SeedQuizWorldAsync</c>).
/// </summary>
[TestFixture]
public sealed partial class TestSheetsTests
{
    private const int Admin = 923001;
    private const int AdminNoReset = 923002;
    private const int McqEditor = 923003;
    private const int Nobody = 923004;
    private const string SettingsSheet = "settings-sheet";
    private const string Busy = "Another quiz admin action is running. Try again in a moment.";

    private FakeSheets sheets = null!;
    private CaptureLogs logs = null!;
    private MembershipTestKit kit = null!;

    [SetUp]
    public async Task StartAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync(
            "truncate access.user_permissions, platform.outbox, platform.outbound_messages, assessment.quiz_state, assessment.standard_mcq_questions, assessment.standard_mcqs, "
            + "notifications.user_notifications, notifications.notifications, notifications.user_devices, classes.class_students, classes.classes restart identity cascade");
        sheets = new FakeSheets();
        logs = new CaptureLogs();
        kit = new MembershipTestKit(services =>
        {
            services.AddSingleton<ISheets>(sheets);
            services.AddSingleton<IQuizRandom>(new FirstPick());
            services.AddSingleton<TimeProvider>(new FixedClock(DateTimeOffset.Parse("2026-12-02T06:30:00+00:00", System.Globalization.CultureInfo.InvariantCulture)));
            services.AddSingleton<ILoggerProvider>(logs);
            services.Configure<GoogleSheetsSettings>(settings => settings.QuizSettingsSheetId = SettingsSheet);
        });
        foreach (var (token, name) in Of((Admin, "Sheet Admin"), (AdminNoReset, "Sheet Quiz Only"), (McqEditor, "Sheet Mcq Editor"), (Nobody, "Sheet Nobody")))
        {
            await MembershipTestKit.AddMemberAsync(token, name, "1");
        }

        await Grant(Admin, "quiz:admin:all", "quiz:reset:all");
        await Grant(AdminNoReset, "quiz:admin:all");
        await Grant(McqEditor, "standard-mcqs:update:all");
    }

    [TearDown]
    public void Stop()
    {
        kit.Dispose();
        logs.Dispose();
    }

    // ---------------------------------------------------------------- the fakes

    private sealed class FirstPick : IQuizRandom
    {
        public int Next(int maxExclusive) => 0;
    }

    private sealed class FixedClock(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    /// <summary>Every log line the API wrote, to prove no member data reaches a log.</summary>
    private sealed class CaptureLogs : ILoggerProvider, ILogger
    {
        public ConcurrentQueue<string> Lines { get; } = new();

        public ILogger CreateLogger(string categoryName) => this;

        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            Lines.Enqueue(formatter(state, exception) + (exception is null ? string.Empty : " " + exception));

        public void Dispose()
        {
        }
    }

    /// <summary>Google Sheets as PHP's helper returns it: a range key is "&lt;sheet id&gt;|&lt;range&gt;". A range nobody set is an empty range (no rows). A failing range throws as the real client does.</summary>
    private sealed class FakeSheets : ISheets
    {
        private readonly object gate = new();

        public Dictionary<string, List<List<string>>> Data { get; } = [];

        public HashSet<string> FailReads { get; } = [];

        public HashSet<string> FailWrites { get; } = [];

        public List<string> Reads { get; } = [];

        public List<(string Key, List<List<object?>> Rows)> Writes { get; } = [];

        /// <summary>Awaited at the start of every read (a test holds a request inside the sheet call with it).</summary>
        public Func<string, Task>? OnRead { get; set; }

        public TaskCompletionSource ReadStarted { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async Task<IReadOnlyList<IReadOnlyList<string>>> ReadAsync(string spreadsheetId, string range, CancellationToken ct)
        {
            var key = spreadsheetId + "|" + range;
            lock (gate)
            {
                Reads.Add(key);
            }

            ReadStarted.TrySetResult();
            if (OnRead is not null)
            {
                await OnRead(key);
            }

            if (FailReads.Contains(key))
            {
                throw new SheetsException("fake read failure");
            }

            return Data.TryGetValue(key, out var rows) ? [.. rows.Select(r => (IReadOnlyList<string>)r)] : [];
        }

        public Task WriteAsync(string spreadsheetId, string range, IReadOnlyList<IReadOnlyList<object?>> rows, CancellationToken ct)
        {
            var key = spreadsheetId + "|" + range;
            if (FailWrites.Contains(key))
            {
                throw new SheetsException("fake write failure");
            }

            lock (gate)
            {
                Writes.Add((key, [.. rows.Select(r => r.ToList())]));
            }

            return Task.CompletedTask;
        }

        public void Set(string sheetId, string range, params string[][] rows) => Data[sheetId + "|" + range] = [.. rows.Select(r => r.ToList())];
    }

    // ---------------------------------------------------------------- helpers

    private static T[] Of<T>(params T[] items) => items;

    private static Task Grant(int token, params string[] permissions) => TestDatabase.ExecuteAsync(
        "insert into access.user_permissions (user_id, permission, revoked_at) select u.id, p, null from identity.users u, unnest(array["
        + string.Join(",", permissions.Select(p => "'" + p + "'")) + "]) p where u.token = " + token);

    private Task<MembershipTestKit.Reply> Post(int caller, string path, string json = "{}") => kit.SendAsync(caller, HttpMethod.Post, path, json);

    private static async Task<JsonNode?> DocAsync(string name)
    {
        var row = await TestDatabase.RowAsync($"select document::text as doc from assessment.quiz_state where name = '{name}'");
        return row is null ? null : JsonNode.Parse(row["doc"]!);
    }

    private static Task<long> CountAsync(string table, string where = "true") => MembershipTestKit.CountAsync(table, where);

    private static Task<long> EventsAsync(string type) => CountAsync("platform.outbox", $"event_type = '{type}'");

    private static Task<long> AllEventsAsync() => CountAsync("platform.outbox");

    private static async Task<JsonNode> OnlyEventPayloadAsync(string type) =>
        JsonNode.Parse((await TestDatabase.RowAsync($"select payload::text as p from platform.outbox where event_type = '{type}'"))!["p"]!)!;

    private static Task PutDocAsync(string name, JsonNode document) => TestDatabase.ExecuteAsync(
        $"insert into assessment.quiz_state (name, document) values ('{name}', '{document.ToJsonString().Replace("'", "''", StringComparison.Ordinal)}'::jsonb) "
        + "on conflict (name) do update set document = excluded.document");

    // ---------------------------------------------------------------- standard MCQs

    private static readonly string[][] AbuzarRows =
    [
        ["EA-1", "Topic A", "Subject", "1", "Name A", "Q1", "ans1", "o1", "o2", "o3", "r1", "r2", "r3"],
        ["EA-1", "Topic A", "Subject", "1", "Name A", "Q2", "ans2", "o1"],
        ["EA-2", "Topic B", "Subject", "2", "Name B", "Q3", "ans3", "x"],
        ["EA-9", "", "Subject", "9", "No topic", "Q9", "a", "b"],
    ];

    private static async Task SeedOldStandardAsync(int languageId, int savedLevel, string code)
    {
        await TestDatabase.ExecuteAsync(
            "insert into assessment.standard_mcqs (code, language_id, level_id, topic, subject, lesson, name, sort_order) values "
            + $"('{code}', {languageId}, {savedLevel}, 'Old', 'Old', '1', 'Old', 1); "
            + $"insert into assessment.standard_mcq_questions (mcq_code, question, answer, option1) values ('{code}', 'old q', 'old a', 'old o')");
    }

    private static string UpdateBody(string languages, string levels) => $$"""{"languages":[{{languages}}],"levels":[{{levels}}]}""";

    [Test]
    public async Task A_good_pair_replaces_its_rows_at_level_plus_one_counts_its_quizzes_and_writes_one_event()
    {
        sheets.Set(StandardMcqCatalog.SheetId, "English-Abuzar!A2:M", AbuzarRows);
        await SeedOldStandardAsync(1, 2, "OLD-A");
        await SeedOldStandardAsync(1, 3, "OLD-OTHER-LEVEL");
        await SeedOldStandardAsync(2, 2, "OLD-OTHER-LANGUAGE");

        var reply = await Post(McqEditor, "/standard-mcqs/update", UpdateBody("1", "1"));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        var result = reply.Json!["results"]![0]!;
        Assert.That(result["status"]!.GetValue<string>(), Is.EqualTo("updated"));
        Assert.That(result["quizzes"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That(await CountAsync("assessment.standard_mcqs", "code = 'OLD-A'"), Is.Zero);
        Assert.That(await CountAsync("assessment.standard_mcq_questions", "mcq_code = 'OLD-A'"), Is.Zero);
        Assert.That(await CountAsync("assessment.standard_mcqs", "code in ('OLD-OTHER-LEVEL', 'OLD-OTHER-LANGUAGE')"), Is.EqualTo(2), "other pairs stay");
        Assert.That(await CountAsync("assessment.standard_mcqs", "language_id = 1 and level_id = 2 and code in ('EA-1', 'EA-2')"), Is.EqualTo(2), "saved level is the chosen id + 1");
        Assert.That(await CountAsync("assessment.standard_mcq_questions", "mcq_code = 'EA-1'"), Is.EqualTo(2));
        Assert.That(await CountAsync("assessment.standard_mcq_questions", "mcq_code = 'EA-2'"), Is.EqualTo(1));
        Assert.That(await CountAsync("assessment.standard_mcqs", "code = 'EA-9'"), Is.Zero, "a row without a topic is skipped");
        var first = await TestDatabase.RowAsync("select topic, sort_order from assessment.standard_mcqs where code = 'EA-2'");
        Assert.That(first!["sort_order"], Is.EqualTo("2"));
        Assert.That(await EventsAsync("assessment.standard_mcqs_updated"), Is.EqualTo(1));
        var payload = await OnlyEventPayloadAsync("assessment.standard_mcqs_updated");
        Assert.That((payload["languageId"]!.GetValue<int>(), payload["levelId"]!.GetValue<int>(), payload["quizzes"]!.GetValue<int>()), Is.EqualTo((1, 2, 2)));
        Assert.That(sheets.Reads, Is.EqualTo(Of(StandardMcqCatalog.SheetId + "|English-Abuzar!A2:M")));
    }

    [Test]
    public async Task One_sheet_that_cannot_be_read_changes_nothing_and_every_other_pair_says_so()
    {
        sheets.Set(StandardMcqCatalog.SheetId, "English-Abuzar!A2:M", AbuzarRows);
        sheets.FailReads.Add(StandardMcqCatalog.SheetId + "|English-Miqdad!A2:M");
        await SeedOldStandardAsync(1, 2, "OLD-A");

        var reply = await Post(McqEditor, "/standard-mcqs/update", UpdateBody("1", "1,2"));

        var results = reply.Json!["results"]!.AsArray();
        Assert.That(results[0]!["reason"]!.GetValue<string>(), Is.EqualTo("Not updated: another sheet could not be read"));
        Assert.That(results[1]!["reason"]!.GetValue<string>(), Is.EqualTo("The sheet could not be read"));
        Assert.That(results.All(r => r!["status"]!.GetValue<string>() == "failed"));
        Assert.That(await CountAsync("assessment.standard_mcqs"), Is.EqualTo(1));
        Assert.That(await CountAsync("assessment.standard_mcqs", "code = 'OLD-A'"), Is.EqualTo(1));
        Assert.That(await AllEventsAsync(), Is.Zero);
    }

    [Test]
    public async Task Every_sheet_is_read_before_anything_is_written()
    {
        sheets.Set(StandardMcqCatalog.SheetId, "English-Abuzar!A2:M", AbuzarRows);
        sheets.Set(StandardMcqCatalog.SheetId, "English-Miqdad!A2:M", AbuzarRows);
        long seen = -1;
        sheets.OnRead = async key =>
        {
            if (key.EndsWith("English-Miqdad!A2:M", StringComparison.Ordinal))
            {
                seen = await CountAsync("assessment.standard_mcqs");
            }
        };

        await Post(McqEditor, "/standard-mcqs/update", UpdateBody("1", "1,2"));

        Assert.That(seen, Is.Zero, "the second range was read while the first pair was not yet saved");
        Assert.That(await CountAsync("assessment.standard_mcqs"), Is.EqualTo(4));
    }

    [Test]
    public async Task An_empty_tab_fails_only_its_pair_and_an_unknown_id_fails_the_others_unread()
    {
        sheets.Set(StandardMcqCatalog.SheetId, "English-Miqdad!A2:M", AbuzarRows);

        var empty = await Post(McqEditor, "/standard-mcqs/update", UpdateBody("1", "1,2"));
        var results = empty.Json!["results"]!.AsArray();
        Assert.That(results[0]!["reason"]!.GetValue<string>(), Is.EqualTo("The sheet has no MCQs for this language and level"));
        Assert.That(results[1]!["status"]!.GetValue<string>(), Is.EqualTo("updated"));

        await TestDatabase.ExecuteAsync("truncate assessment.standard_mcq_questions, assessment.standard_mcqs");
        var unknown = await Post(McqEditor, "/standard-mcqs/update", UpdateBody("1,9", "2"));
        var rows = unknown.Json!["results"]!.AsArray();
        Assert.That(rows[0]!["reason"]!.GetValue<string>(), Is.EqualTo("Not updated: another sheet could not be read"));
        Assert.That(rows[1]!["reason"]!.GetValue<string>(), Is.EqualTo("Unknown language or level"));
        Assert.That(await CountAsync("assessment.standard_mcqs"), Is.Zero);
    }

    [Test]
    public async Task A_save_that_fails_rolls_back_only_its_pair_and_writes_no_event_for_it()
    {
        sheets.Set(StandardMcqCatalog.SheetId, "English-Abuzar!A2:M", AbuzarRows);
        sheets.Set(StandardMcqCatalog.SheetId, "English-Miqdad!A2:M", Of("EM-1", "Topic", "Subject", "1", "Name", "Question with a NUL \0 byte", "a", "b"));
        await SeedOldStandardAsync(1, 3, "OLD-MIQDAD");

        var reply = await Post(McqEditor, "/standard-mcqs/update", UpdateBody("1", "1,2"));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        var results = reply.Json!["results"]!.AsArray();
        Assert.That(results[0]!["status"]!.GetValue<string>(), Is.EqualTo("updated"));
        Assert.That(results[1]!["status"]!.GetValue<string>(), Is.EqualTo("failed"));
        Assert.That(results[1]!["reason"]!.GetValue<string>(), Is.EqualTo("The save failed and nothing was changed"));
        Assert.That(await CountAsync("assessment.standard_mcqs", "code = 'OLD-MIQDAD'"), Is.EqualTo(1), "the failed pair kept its old rows");
        Assert.That(await CountAsync("assessment.standard_mcqs", "code = 'EM-1'"), Is.Zero);
        Assert.That(await CountAsync("assessment.standard_mcqs", "code = 'EA-1'"), Is.EqualTo(1));
        Assert.That(await EventsAsync("assessment.standard_mcqs_updated"), Is.EqualTo(1));
    }

    [Test]
    public async Task The_update_refuses_before_reading_any_sheet_without_the_permission_or_with_a_bad_body()
    {
        var nobody = await Post(Nobody, "/standard-mcqs/update", UpdateBody("1", "1"));
        var onlyQuiz = await Post(Admin, "/standard-mcqs/update", UpdateBody("1", "1"));
        var tooMany = await Post(McqEditor, "/standard-mcqs/update", UpdateBody(string.Join(",", Enumerable.Range(1, 21)), "1"));
        var empty = await Post(McqEditor, "/standard-mcqs/update", """{"languages":[1],"levels":[]}""");

        Assert.That(nobody.Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(nobody.Detail, Is.EqualTo("You do not have permission to do that"));
        Assert.That(onlyQuiz.Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That((tooMany.Status, tooMany.Detail), Is.EqualTo((HttpStatusCode.UnprocessableEntity, "Too many ids in languages")));
        Assert.That((empty.Status, empty.Detail), Is.EqualTo((HttpStatusCode.UnprocessableEntity, "Choose at least one in levels")));
        Assert.That(sheets.Reads, Is.Empty);
        Assert.That(await AllEventsAsync(), Is.Zero);
    }

    [Test]
    public async Task Two_simultaneous_updates_one_runs_and_the_other_gets_409()
    {
        sheets.Set(StandardMcqCatalog.SheetId, "English-Abuzar!A2:M", AbuzarRows);
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        sheets.OnRead = _ => release.Task;

        var first = Post(McqEditor, "/standard-mcqs/update", UpdateBody("1", "1"));
        await sheets.ReadStarted.Task.WaitAsync(TimeSpan.FromSeconds(30));
        var second = await Post(McqEditor, "/standard-mcqs/update", UpdateBody("1", "1")).WaitAsync(TimeSpan.FromSeconds(20));
        release.SetResult();
        var firstReply = await first;

        Assert.That((second.Status, second.Detail), Is.EqualTo((HttpStatusCode.Conflict, "An update is already running. Try again in a minute.")));
        Assert.That(firstReply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(sheets.Reads, Has.Count.EqualTo(1), "the refused request read nothing");
        Assert.That(await EventsAsync("assessment.standard_mcqs_updated"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_lock_held_by_another_session_refuses_the_update_and_a_free_lock_lets_it_run()
    {
        sheets.Set(StandardMcqCatalog.SheetId, "English-Abuzar!A2:M", AbuzarRows);
        await using (await HoldLockAsync(5001))
        {
            var refused = await Post(McqEditor, "/standard-mcqs/update", UpdateBody("1", "1"));
            Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.Conflict));
        }

        var allowed = await Post(McqEditor, "/standard-mcqs/update", UpdateBody("1", "1"));
        Assert.That(allowed.Status, Is.EqualTo(HttpStatusCode.OK));
    }

    /// <summary>A session-level advisory lock held by a second connection until disposed (the API's transaction locks share the key space).</summary>
    private static async Task<AsyncLock> HoldLockAsync(long key)
    {
        var connection = new NpgsqlConnection(TestDatabase.OwnerConnection);
        await connection.OpenAsync();
        await using (var command = new NpgsqlCommand($"select pg_advisory_lock({key})", connection))
        {
            await command.ExecuteScalarAsync();
        }

        return new AsyncLock(connection);
    }

    private sealed class AsyncLock(NpgsqlConnection connection) : IAsyncDisposable
    {
        public async ValueTask DisposeAsync()
        {
            await using (var command = new NpgsqlCommand("select pg_advisory_unlock_all()", connection))
            {
                await command.ExecuteScalarAsync();
            }

            await connection.DisposeAsync();
        }
    }
}
