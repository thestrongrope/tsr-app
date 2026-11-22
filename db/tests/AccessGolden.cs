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
    private static bool templateReady;

    private static readonly string[] RecordedHeaders = ["ETag", "Cache-Control", "Vary", "X-Permissions-Revision", "Content-Type"];

    private static readonly string[] RowQueries =
    [
        "access.user_permissions|select row_to_json(t)::text from access.user_permissions t order by id",
        "access.user_roles|select row_to_json(t)::text from access.user_roles t order by user_id",
        "access.class_access_rules|select row_to_json(t)::text from access.class_access_rules t order by id",
        "access.class_access_rule_conditions|select row_to_json(t)::text from access.class_access_rule_conditions t order by id",
        "platform.outbox (event_type, created_at, payload)|select t.event_type || ' | ' || to_json(t.created_at)::text || ' | ' || t.payload::text from platform.outbox t order by t.id",
    ];

    private readonly string database;
    private readonly WebApplicationFactory<Program> factory;
    private readonly HttpClient client;
    private readonly StringBuilder transcript = new();

    private GoldenScenario(string database, WebApplicationFactory<Program> factory)
    {
        this.database = database;
        this.factory = factory;
        client = factory.CreateClient();
    }

    /// <summary>What the scenario sent and what came back, as the golden file holds it.</summary>
    public string Transcript => transcript.ToString();

    /// <summary>A fresh copy of the template and the API on it. Dispose drops the copy.</summary>
    public static async Task<GoldenScenario> StartAsync(string name)
    {
        await EnsureTemplateAsync();
        var database = DatabaseOf(name);
        await AdminAsync($"drop database if exists {database} with (force)");
        await AdminAsync($"create database {database} with template {GoldenSeed.TemplateName}");
        var factory = TestApi.Create(ConnectionTo(database, TestDatabase.AppConnection))
            .WithWebHostBuilder(builder => builder.ConfigureTestServices(services => services.AddSingleton<TimeProvider>(new FixedClock())));
        return new GoldenScenario(database, factory);
    }

    /// <summary>Compares a transcript with its golden file, or records it when TSR_RECORD_GOLDEN=1.</summary>
    public static void Check(string name, string actual)
    {
        var path = Path.Combine(TestDatabase.RepoRoot(), "db", "tests", "golden", "access", name + ".txt");
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
    public async Task<GoldenReply> SendAsync(int? caller, HttpMethod method, string path, string? json = null, string? ifNoneMatch = null)
    {
        using var request = new HttpRequestMessage(method, path);
        if (caller is null)
        {
            request.Headers.Add(TestApi.Outcome, "missing");
        }
        else
        {
            foreach (var (name, value) in TestApi.SignedInAs("uid-" + caller, MembershipTestKit.EmailOf(caller.Value)))
            {
                request.Headers.Add(name, value);
            }
        }

        if (ifNoneMatch is not null)
        {
            request.Headers.TryAddWithoutValidation("If-None-Match", ifNoneMatch);
        }

        if (json is not null)
        {
            request.Content = new StringContent(json, Encoding.UTF8, new MediaTypeHeaderValue("application/json"));
        }

        using var response = await client.SendAsync(request);
        var body = await response.Content.ReadAsStringAsync();
        Record(caller, method, path, json, ifNoneMatch, response, body);
        return new GoldenReply(response.StatusCode, body);
    }

    /// <summary>Appends every row of the four writable access tables and every outbox payload, as text.</summary>
    public async Task AppendRowsAsync(string label)
    {
        transcript.Append("=== rows after ").Append(label).Append(" ===\n");
        await using var connection = new NpgsqlConnection(ConnectionTo(database, TestDatabase.OwnerConnection));
        await connection.OpenAsync();
        await using (var zone = new NpgsqlCommand("set time zone 'UTC'", connection))
        {
            await zone.ExecuteNonQueryAsync();
        }

        foreach (var entry in RowQueries)
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

    /// <summary>One value read from the scenario's database as the owner.</summary>
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

    private void Record(int? caller, HttpMethod method, string path, string? json, string? ifNoneMatch, HttpResponseMessage response, string body)
    {
        transcript.Append("### ").Append(method.Method).Append(' ').Append(path).Append(" as ").Append(caller?.ToString(CultureInfo.InvariantCulture) ?? "nobody").Append('\n');
        if (ifNoneMatch is not null)
        {
            transcript.Append("If-None-Match: ").Append(ifNoneMatch).Append('\n');
        }

        if (json is not null)
        {
            transcript.Append("request: ").Append(json).Append('\n');
        }

        transcript.Append("status: ").Append((int)response.StatusCode).Append('\n');
        foreach (var header in RecordedHeaders)
        {
            transcript.Append(header).Append(": ").Append(HeaderValue(response, header)).Append('\n');
        }

        transcript.Append("body: ").Append(body).Append('\n');
    }

    // The raw text the server sent, not HttpClient's parsed form (which reorders and rewrites values); several raw values are joined in the order received.
    private static string HeaderValue(HttpResponseMessage response, string name) =>
        response.Headers.NonValidated.TryGetValues(name, out var values) || response.Content.Headers.NonValidated.TryGetValues(name, out values)
            ? values.ToString()
            : "(absent)";

    private static (string Title, string Sql) Split(string entry)
    {
        var at = entry.IndexOf('|', StringComparison.Ordinal);
        return (entry[..at], entry[(at + 1)..]);
    }

    // One database per scenario, named from it, so nothing a scenario leaves behind (a pooled connection, a failed drop) can reach the next.
    private static string DatabaseOf(string name) =>
        "access_golden_" + new string(name.Select(c => char.IsAsciiLetterOrDigit(c) ? char.ToLowerInvariant(c) : '_').ToArray());

    // Pooling off: an idle pooled connection to the template would make "create database ... template" fail.
    private static string ConnectionTo(string database, string baseConnection) =>
        new NpgsqlConnectionStringBuilder(baseConnection) { Database = database, Pooling = false }.ConnectionString;

    private static async Task AdminAsync(string sql)
    {
        await using var connection = new NpgsqlConnection(new NpgsqlConnectionStringBuilder(TestDatabase.OwnerConnection) { Pooling = false }.ConnectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task EnsureTemplateAsync()
    {
        await TemplateLock.WaitAsync();
        try
        {
            if (templateReady)
            {
                return;
            }

            await AdminAsync($"drop database if exists {GoldenSeed.TemplateName} with (force)");
            await AdminAsync($"create database {GoldenSeed.TemplateName}");
            var owner = ConnectionTo(GoldenSeed.TemplateName, TestDatabase.OwnerConnection);
            await TestDatabase.MigrateAsProductionAsync(owner);
            await GoldenSeed.RunAsync(owner);
            templateReady = true;
        }
        finally
        {
            TemplateLock.Release();
        }
    }

    /// <summary>The instant every clock reading of a scenario answers, so every stored and answered time is exact.</summary>
    private sealed class FixedClock : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => DateTimeOffset.Parse(Instant, CultureInfo.InvariantCulture);
    }
}

internal sealed record GoldenReply(HttpStatusCode Status, string Body)
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
