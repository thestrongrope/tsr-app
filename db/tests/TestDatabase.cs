using Npgsql;
using NUnit.Framework;
using Testcontainers.PostgreSql;

namespace Tsr.Db.Tests;

/// <summary>
/// One throwaway postgres:18 for the whole run. Set up like a deployment: the limited API role is
/// created from db/init/01-app-role.sql, then the host's own <c>--migrate</c> job runs as Production
/// (the environment where the dev verifier does not exist) and applies every domain's migrations.
/// </summary>
[SetUpFixture]
public sealed class TestDatabase
{
    public const string Image = "postgres:18";

    private static PostgreSqlContainer? container;

    /// <summary>The owner role: runs migrations and test set-up.</summary>
    public static string OwnerConnection => Container.GetConnectionString();

    /// <summary>The limited role the API connects as.</summary>
    public static string AppConnection =>
        new NpgsqlConnectionStringBuilder(OwnerConnection) { Username = "tsr_app", Password = "local-only-app" }.ConnectionString;

    private static PostgreSqlContainer Container =>
        container ?? throw new InvalidOperationException("The database fixture did not start.");

    [OneTimeSetUp]
    public static async Task StartAsync()
    {
        container = new PostgreSqlBuilder(Image).Build();
        await container.StartAsync();

        await ExecuteAsync(await File.ReadAllTextAsync(Path.Combine(RepoRoot(), "db", "init", "01-app-role.sql")));
        await MigrateAsProductionAsync(OwnerConnection);
    }

    [OneTimeTearDown]
    public static async Task StopAsync()
    {
        if (container is not null)
        {
            await container.DisposeAsync();
        }
    }

    /// <summary>Runs one statement or script as the owner.</summary>
    public static async Task ExecuteAsync(string sql)
    {
        await using var connection = new NpgsqlConnection(OwnerConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }

    /// <summary>One scalar value, read as the owner.</summary>
    public static async Task<T> ScalarAsync<T>(string sql, string connectionString)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        return (T)(await command.ExecuteScalarAsync())!;
    }

    /// <summary>The first row of a query as the owner, column name to value (DBNull as null); null when there is no row.</summary>
    public static async Task<Dictionary<string, string?>?> RowAsync(string sql)
    {
        await using var connection = new NpgsqlConnection(OwnerConnection);
        await connection.OpenAsync();
        // citext cannot be read as object by Npgsql, so the row travels as JSON text.
        await using var command = new NpgsqlCommand("select row_to_json(q)::text from (" + sql + ") q", connection);
        var json = await command.ExecuteScalarAsync() as string;
        if (json is null)
        {
            return null;
        }

        using var document = System.Text.Json.JsonDocument.Parse(json);
        return document.RootElement.EnumerateObject().ToDictionary(
            p => p.Name,
            p => p.Value.ValueKind == System.Text.Json.JsonValueKind.Null ? null : p.Value.ValueKind == System.Text.Json.JsonValueKind.String ? p.Value.GetString() : p.Value.GetRawText());
    }

    /// <summary>Runs the host's entry point with <c>--migrate</c> in Production, as the deployed job does.</summary>
    public static async Task MigrateAsProductionAsync(string connectionString)
    {
        var entry = typeof(Program).Assembly.EntryPoint
            ?? throw new InvalidOperationException("The API assembly has no entry point.");
        string[] args = ["--migrate", "--environment=Production", "--TSR_DB=" + connectionString];
        var result = await Task.Run(() => entry.Invoke(null, [args]));
        if (result is Task task)
        {
            await task;
        }
    }

    public static string RepoRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "TsrApp.slnx")))
        {
            directory = directory.Parent;
        }

        return directory?.FullName ?? throw new InvalidOperationException("TsrApp.slnx not found above the test output.");
    }
}
