using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The golden set-up of access's characterisation tests (issue 99, plan "Golden files"): a template database migrated and seeded once, a copy of it for
/// each scenario (so every id, version and preview hash is the same on every run), the API on that copy with a fixed clock, and the transcript of what it
/// answered. A golden file is compared byte for byte; it is written only when TSR_RECORD_GOLDEN=1, and such a run always fails, so it can never pass as a check.
/// </summary>
internal sealed class GoldenScenario : IAsyncDisposable
{
    internal const string Instant = "2026-01-01T00:00:00Z";

    private static readonly SemaphoreSlim TemplateLock = new(1, 1);
    private static readonly HashSet<string> ReadyTemplates = [];

    private readonly GoldenSet set;
    private readonly string database;
    private readonly WebApplicationFactory<Program> factory;
    private readonly HttpClient client;
    private readonly StringBuilder transcript = new();

    private GoldenScenario(GoldenSet set, string database, WebApplicationFactory<Program> factory)
    {
        this.set = set;
        this.database = database;
        this.factory = factory;
        client = factory.CreateClient();
    }

    /// <summary>What the scenario sent and what came back, as the golden file holds it.</summary>
    public string Transcript => transcript.ToString();

    /// <summary>
    /// A fresh copy of the template of <paramref name="set"/> (access when left out) and the API on it. Dispose drops the copy.
    /// <paramref name="settings"/> are host settings (<c>UseSetting</c>) for a scenario that reads one, such as the content directory of a load.
    /// </summary>
    public static async Task<GoldenScenario> StartAsync(
        string name, Action<IServiceCollection>? configure = null, GoldenSet? set = null, IReadOnlyDictionary<string, string>? settings = null)
    {
        set ??= GoldenSet.Access;
        await EnsureTemplateAsync(set);
        var database = DatabaseOf(set, name);
        await AdminAsync($"drop database if exists {database} with (force)");
        await AdminAsync($"create database {database} with template {set.TemplateName}");
        var factory = TestApi.Create(ConnectionTo(database, TestDatabase.AppConnection))
            .WithWebHostBuilder(builder =>
            {
                foreach (var (key, value) in settings ?? new Dictionary<string, string>())
                {
                    builder.UseSetting(key, value);
                }

                builder.ConfigureTestServices(services =>
                {
                    services.AddSingleton<TimeProvider>(new FixedClock());
                    configure?.Invoke(services);
                });
            });
        return new GoldenScenario(set, database, factory);
    }

    /// <summary>The fixed clock every scenario runs on, for a seed or a copy made outside a scenario's host.</summary>
    internal static TimeProvider Clock { get; } = new FixedClock();

    /// <summary>The API's services on the scenario's database, for a test that resolves one in its own scope.</summary>
    public IServiceProvider Services => factory.Services;

    /// <summary>Compares a transcript with its golden file (access's folder when <paramref name="set"/> is left out), or records it when TSR_RECORD_GOLDEN=1.</summary>
    public static void Check(string name, string actual, GoldenSet? set = null)
    {
        var path = Path.Combine(TestDatabase.RepoRoot(), "db", "tests", "golden", (set ?? GoldenSet.Access).Folder, name + ".txt");
        if (Environment.GetEnvironmentVariable("TSR_RECORD_GOLDEN") == "1")
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllBytes(path, new UTF8Encoding(false).GetBytes(actual));
            Assert.Fail($"Recorded {path}. A recording run never passes: unset TSR_RECORD_GOLDEN and run again to check.");
        }

        if (!File.Exists(path))
        {
            Assert.Fail($"The golden file is missing: {path}. Record it on today's code with TSR_RECORD_GOLDEN=1; a test never invents its own expected answer.");
        }

        Assert.That(actual, Is.EqualTo(new UTF8Encoding(false).GetString(File.ReadAllBytes(path))), $"golden file {path}");
    }

    /// <summary>Sends one request as one seeded member (null: nobody signed in) and writes what came back to the transcript.</summary>
    public Task<GoldenReply> SendAsync(int? caller, HttpMethod method, string path, string? json = null, string? ifNoneMatch = null, string? ifModifiedSince = null)
    {
        List<KeyValuePair<string, string>> headers = caller is null
            ? [new KeyValuePair<string, string>(TestApi.Outcome, "missing")]
            : TestApi.SignedInAs("uid-" + caller, MembershipTestKit.EmailOf(caller.Value)).ToList();
        return SendCoreAsync(caller?.ToString(CultureInfo.InvariantCulture) ?? "nobody", headers, method, path, json, new Conditions(ifNoneMatch, ifModifiedSince));
    }

    /// <summary>
    /// Sends one request with exactly <paramref name="headers"/> (<c>TestApi.SignedInAs</c>, the name and picture, the tracking headers) and writes <paramref name="who"/> where the caller number goes.
    /// The headers are not written to the transcript, so a <paramref name="who"/> says what was sent. With <paramref name="recordBody"/> false the body is not written (a failure whose text names a library type the conversion must change).
    /// </summary>
    public Task<GoldenReply> SendAsync(string who, IReadOnlyList<KeyValuePair<string, string>> headers, HttpMethod method, string path, string? json = null, bool recordBody = true) =>
        SendCoreAsync(who, headers, method, path, json, new Conditions(null, null), recordBody);

    private async Task<GoldenReply> SendCoreAsync(string who, IReadOnlyList<KeyValuePair<string, string>> headers, HttpMethod method, string path, string? json, Conditions conditions, bool recordBody = true)
    {
        using var request = new HttpRequestMessage(method, path);
        foreach (var (name, value) in headers)
        {
            request.Headers.TryAddWithoutValidation(name, value);
        }

        if (conditions.IfNoneMatch is not null)
        {
            request.Headers.TryAddWithoutValidation("If-None-Match", conditions.IfNoneMatch);
        }

        if (conditions.IfModifiedSince is not null)
        {
            request.Headers.TryAddWithoutValidation("If-Modified-Since", conditions.IfModifiedSince);
        }

        if (json is not null)
        {
            request.Content = new StringContent(json, Encoding.UTF8, new MediaTypeHeaderValue("application/json"));
        }

        using var response = await client.SendAsync(request);
        var body = await response.Content.ReadAsStringAsync();
        Record(who, method, path, json, conditions, response, recordBody ? body : null);
        return new GoldenReply(response.StatusCode, body, HeaderOrNull(response, "ETag"), HeaderOrNull(response, "Last-Modified"));
    }

    /// <summary>Appends a line of text to the transcript (what a copy answered, or that it threw).</summary>
    public void Note(string line)
    {
        lock (transcript)
        {
            transcript.Append(line).Append('\n');
        }
    }

    /// <summary>Appends every row of the set's tables (access: the four writable tables and every outbox payload), as text.</summary>
    public async Task AppendRowsAsync(string label)
    {
        transcript.Append("=== rows after ").Append(label).Append(" ===\n");
        await using var connection = new NpgsqlConnection(ConnectionTo(database, TestDatabase.OwnerConnection));
        await connection.OpenAsync();
        await using (var zone = new NpgsqlCommand("set time zone 'UTC'", connection))
        {
            await zone.ExecuteNonQueryAsync();
        }

        foreach (var entry in set.RowQueries)
        {
            var (title, sql) = Split(entry);
            transcript.Append("-- ").Append(title).Append('\n');
            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                transcript.Append(reader.GetString(0)).Append('\n');
            }
        }
    }

    /// <summary>One statement run on the scenario's database as the owner (a fixture row, a trigger, a revoke).</summary>
    public async Task ExecuteAsync(string sql)
    {
        await using var connection = new NpgsqlConnection(ConnectionTo(database, TestDatabase.OwnerConnection));
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }

    /// <summary>An open connection to the scenario's database as the owner, for a test that holds a lock or a transaction of its own. The caller disposes it.</summary>
    public async Task<NpgsqlConnection> OpenOwnerConnectionAsync()
    {
        var connection = new NpgsqlConnection(ConnectionTo(database, TestDatabase.OwnerConnection));
        await connection.OpenAsync();
        return connection;
    }

    /// <summary>The values of the first column of a query on the scenario's database, read as the owner.</summary>
    public async Task<List<string>> QueryAsync(string sql)
    {
        await using var connection = new NpgsqlConnection(ConnectionTo(database, TestDatabase.OwnerConnection));
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync();
        var values = new List<string>();
        while (await reader.ReadAsync())
        {
            values.Add(Convert.ToString(reader.GetValue(0), CultureInfo.InvariantCulture)!);
        }

        return values;
    }

    public async ValueTask DisposeAsync()
    {
        client.Dispose();
        await factory.DisposeAsync();
        await AdminAsync($"drop database if exists {database}");
    }

    // A lock: a scenario may send two requests at once, and a StringBuilder is not safe for two writers.
    private void Record(string who, HttpMethod method, string path, string? json, Conditions conditions, HttpResponseMessage response, string? body)
    {
        lock (transcript)
        {
            RecordLocked(who, method, path, json, conditions, response, body);
        }
    }

    private sealed record Conditions(string? IfNoneMatch, string? IfModifiedSince);

    private void RecordLocked(string who, HttpMethod method, string path, string? json, Conditions conditions, HttpResponseMessage response, string? body)
    {
        transcript.Append("### ").Append(method.Method).Append(' ').Append(path).Append(" as ").Append(who).Append('\n');
        if (conditions.IfNoneMatch is not null)
        {
            transcript.Append("If-None-Match: ").Append(conditions.IfNoneMatch).Append('\n');
        }

        if (conditions.IfModifiedSince is not null)
        {
            transcript.Append("If-Modified-Since: ").Append(conditions.IfModifiedSince).Append('\n');
        }

        if (json is not null)
        {
            transcript.Append("request: ").Append(json).Append('\n');
        }

        transcript.Append("status: ").Append((int)response.StatusCode).Append('\n');
        foreach (var header in set.RecordedHeaders ?? AllHeaderNames(response))
        {
            transcript.Append(header).Append(": ").Append(HeaderValue(response, header)).Append('\n');
        }

        transcript.Append("body: ").Append(body is null ? "(not recorded)" : StackTraceCut(body)).Append('\n');
    }

    // An unhandled error answers in the test host with the exception text and its stack, whose lines name files and line numbers of this machine: only the first line is recorded.
    private static string StackTraceCut(string body)
    {
        var at = body.IndexOf("\n   at ", StringComparison.Ordinal);
        return at < 0 ? body : body[..at];
    }

    // The raw text the server sent, not HttpClient's parsed form (which reorders and rewrites values); several raw values are joined in the order received.
    private static string HeaderValue(HttpResponseMessage response, string name) =>
        response.Headers.NonValidated.TryGetValues(name, out var values) || response.Content.Headers.NonValidated.TryGetValues(name, out values)
            ? values.ToString()
            : "(absent)";

    // Every header the server sent but Date (a clock reading of the host, not of the API), by name, from the response and its content.
    private static IEnumerable<string> AllHeaderNames(HttpResponseMessage response) =>
        response.Headers.NonValidated.Select(h => h.Key)
            .Concat(response.Content.Headers.NonValidated.Select(h => h.Key))
            .Where(name => !string.Equals(name, "Date", StringComparison.OrdinalIgnoreCase))
            .Order(StringComparer.OrdinalIgnoreCase);

    private static string? HeaderOrNull(HttpResponseMessage response, string name) =>
        HeaderValue(response, name) is var value && value != "(absent)" ? value : null;

    private static (string Title, string Sql) Split(string entry)
    {
        var at = entry.IndexOf('|', StringComparison.Ordinal);
        return (entry[..at], entry[(at + 1)..]);
    }

    // One database per scenario, named from it, so nothing a scenario leaves behind (a pooled connection, a failed drop) can reach the next.
    private static string DatabaseOf(GoldenSet set, string name) =>
        set.Folder + "_golden_" + new string(name.Select(c => char.IsAsciiLetterOrDigit(c) ? char.ToLowerInvariant(c) : '_').ToArray());

    // Pooling off: an idle pooled connection to the template would make "create database ... template" fail.
    internal static string ConnectionTo(string database, string baseConnection) =>
        new NpgsqlConnectionStringBuilder(baseConnection) { Database = database, Pooling = false }.ConnectionString;

    private static async Task AdminAsync(string sql)
    {
        await using var connection = new NpgsqlConnection(new NpgsqlConnectionStringBuilder(TestDatabase.OwnerConnection) { Pooling = false }.ConnectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task EnsureTemplateAsync(GoldenSet set)
    {
        await TemplateLock.WaitAsync();
        try
        {
            if (ReadyTemplates.Contains(set.TemplateName))
            {
                return;
            }

            await AdminAsync($"drop database if exists {set.TemplateName} with (force)");
            await AdminAsync($"create database {set.TemplateName}");
            var owner = ConnectionTo(set.TemplateName, TestDatabase.OwnerConnection);
            await TestDatabase.MigrateAsProductionAsync(owner);
            await set.SeedAsync(owner);
            ReadyTemplates.Add(set.TemplateName);
        }
        finally
        {
            TemplateLock.Release();
        }
    }

    /// <summary>The instant every clock reading of a scenario answers, so every stored and answered time is exact.</summary>
    internal sealed class FixedClock : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => DateTimeOffset.Parse(Instant, CultureInfo.InvariantCulture);
    }
}

/// <summary>
/// What differs between one domain's goldens and another's: the folder under db/tests/golden, the template database and how it is seeded (as the owner, after the
/// migrations), the queries whose rows a scenario appends (<c>title|sql</c>), and the response headers recorded (null: every header but Date, by name).
/// </summary>
internal sealed record GoldenSet(string Folder, string TemplateName, Func<string, Task> SeedAsync, IReadOnlyList<string> RowQueries, IReadOnlyList<string>? RecordedHeaders)
{
    public static GoldenSet Access { get; } = new(
        "access",
        GoldenSeed.TemplateName,
        GoldenSeed.RunAsync,
        [
            "access.user_permissions|select row_to_json(t)::text from access.user_permissions t order by id",
            "access.user_roles|select row_to_json(t)::text from access.user_roles t order by user_id",
            "access.class_access_rules|select row_to_json(t)::text from access.class_access_rules t order by id",
            "access.class_access_rule_conditions|select row_to_json(t)::text from access.class_access_rule_conditions t order by id",
            "platform.outbox (event_type, created_at, payload)|select t.event_type || ' | ' || to_json(t.created_at)::text || ' | ' || t.payload::text from platform.outbox t order by t.id",
        ],
        ["ETag", "Cache-Control", "Vary", "X-Permissions-Revision", "Content-Type"]);
}

internal sealed record GoldenReply(HttpStatusCode Status, string Body, string? ETag = null, string? LastModified = null)
{
    public JsonNode? Json => JsonNode.Parse(Body);
}

/// <summary>The synthetic members, classes and tags the scenarios run on: tokens 900001 and up, emails on .invalid, written in one fixed order.</summary>
internal static class GoldenSeed
{
    public const string TemplateName = "access_golden_template";

    public const int Super = 900001;
    public const int GentsAdmin = 900002;
    public const int LadiesAdmin = 900003;
    public const int Plain = 900004;
    public const int Subject = 900005;
    public const int LadiesMember = 900006;
    public const int EmptyName = 900007;
    public const int OddName = 900008;
    public const int Teacher = 900009;
    public const int Finance = 900010;
    public const int NoGender = 900011;
    public const int PeerGentsAdmin = 900012;

    /// <summary>A name with a plus, a quote, a less-than sign, an HTML entity and non-ASCII letters.</summary>
    public const string OddNameText = "Zoë \"Q\" <b> + &amp; Ünï";

    private static readonly (int Token, string? Name, string? Gender, int Role)[] Members =
    [
        (Super, "Gold Super", "1", 1),
        (GentsAdmin, "Gold Gents", "1", 3),
        (LadiesAdmin, "Gold Ladies", "2", 4),
        (Plain, "Gold Plain", "1", 0),
        (Subject, "Gold Subject", "1", 0),
        (LadiesMember, "Gold Ladies Member", "2", 0),
        (EmptyName, string.Empty, "1", 0),
        (OddName, OddNameText, "1", 0),
        (Teacher, "Gold Teacher", "1", 0),
        (Finance, "Gold Finance", "1", 7),
        (NoGender, "Gold No Gender", null, 0),
        (PeerGentsAdmin, "Gold Peer", "1", 3),
    ];

    public static async Task RunAsync(string ownerConnection)
    {
        var sql = new StringBuilder();
        foreach (var (token, name, gender, role) in Members)
        {
            sql.Append(CultureInfo.InvariantCulture, $"insert into identity.users (token, email, firebase_uid) values ({token}, '{MembershipTestKit.EmailOf(token)}', 'uid-{token}'); ");
            sql.Append(CultureInfo.InvariantCulture, $"insert into membership.member_profiles (user_id, name, gender) select id, {MembershipTestKit.Quote(name)}, {MembershipTestKit.Quote(gender)} from identity.users where token = {token}; ");
            if (role != 0)
            {
                sql.Append(CultureInfo.InvariantCulture, $"insert into access.user_roles (user_id, roleid) select id, {role} from identity.users where token = {token}; ");
            }
        }

        sql.Append("insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; ");
        sql.Append("insert into classes.class_levels (id, code, name, sort_order) values (1, 'SM', 'SALMAN', 1), (2, 'AG', 'ABUZAR', 2), (3, 'MK', 'MIQDAD', 3) on conflict do nothing; ");
        sql.Append("insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, city, country, status, created_by) values ");
        sql.Append(CultureInfo.InvariantCulture, $"(98501, 'GL-G-501', 7, 'gl1', 'Gold One', 2, {Teacher}, 1, 'Offline', 'Goldville', 'Goldland', 'A', {Super}), ");
        sql.Append(CultureInfo.InvariantCulture, $"(98502, 'GL-G-502', 7, 'gl2', 'Gold Two', 3, {Teacher}, 1, 'Offline', 'Goldville', 'Goldland', 'A', {Super}), ");
        sql.Append(CultureInfo.InvariantCulture, $"(98503, 'GL-G-503', 7, 'gl3', 'Gold Three', 2, {Super}, 1, 'Offline', 'Goldother', 'Goldland', 'A', {Super}), ");
        sql.Append(CultureInfo.InvariantCulture, $"(98504, 'GL-G-504', 7, 'gl4', 'Gold Closed', 2, {Super}, 1, 'Offline', 'Goldville', 'Goldland', 'I', {Super}), ");
        sql.Append(CultureInfo.InvariantCulture, $"(98505, 'GL-L-505', 7, 'gl5', 'Gold Ladies', 2, {Super}, 2, 'Offline', 'Goldville', 'Goldland', 'A', {Super}); ");
        sql.Append("insert into classes.tags (id, name) values (1, 'alpha'), (2, 'beta'); ");
        sql.Append("insert into classes.class_tags (class_id, tag_id) values (98501, 1), (98502, 1), (98503, 2); ");
        sql.Append(CultureInfo.InvariantCulture, $"insert into classes.class_students (class_id, token_no, status) values (98501, {Plain}, 'A');");

        await using var connection = new NpgsqlConnection(ownerConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql.ToString(), connection);
        await command.ExecuteNonQueryAsync();
    }
}
