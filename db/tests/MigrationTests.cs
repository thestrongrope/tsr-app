using Npgsql;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The migrate job and the API's limited database role (the fixture already ran the job as
/// Production, so a failure there fails every test here).
/// </summary>
public sealed class MigrationTests
{
    private static readonly string[] Schemas = ["identity", "access", "platform", "content"];

    [Test]
    public async Task Migrating_as_production_creates_every_domain_schema()
    {
        foreach (var schema in Schemas)
        {
            var tables = await TestDatabase.ScalarAsync<long>(
                $"select count(*) from information_schema.tables where table_schema = '{schema}'",
                TestDatabase.OwnerConnection);
            Assert.That(tables, Is.GreaterThan(0), schema + " has no tables");
        }
    }

    [Test]
    public async Task Migrating_again_changes_nothing_and_does_not_fail()
    {
        await TestDatabase.MigrateAsProductionAsync(TestDatabase.OwnerConnection);

        Assert.Pass();
    }

    [Test]
    public async Task The_api_role_is_not_a_superuser()
    {
        var superuser = await TestDatabase.ScalarAsync<bool>(
            "select rolsuper from pg_roles where rolname = current_user", TestDatabase.AppConnection);
        var user = await TestDatabase.ScalarAsync<string>("select current_user::text", TestDatabase.AppConnection);

        Assert.That(user, Is.EqualTo("tsr_app"));
        Assert.That(superuser, Is.False);
    }

    [TestCase("public")]
    [TestCase("platform")]
    public async Task The_api_role_cannot_create_a_table(string schema)
    {
        var error = await Assert.ThrowsAsync<PostgresException>(() => RunAsAppAsync($"create table {schema}.not_allowed (id int)"));

        Assert.That(error!.SqlState, Is.EqualTo(PostgresErrorCodes.InsufficientPrivilege));
    }

    [Test]
    public async Task The_api_role_can_read_and_write_domain_tables_and_tables_added_by_later_migrations()
    {
        await RunAsAppAsync("select count(*) from identity.users");

        // A table a later migration would create, made by the owner after the grants ran.
        await TestDatabase.ExecuteAsync("create table content.created_later (id int primary key)");
        try
        {
            await RunAsAppAsync("insert into content.created_later (id) values (1); select id from content.created_later");
        }
        finally
        {
            await TestDatabase.ExecuteAsync("drop table content.created_later");
        }
    }

    [Test]
    public async Task The_api_role_cannot_edit_the_migration_history()
    {
        var error = await Assert.ThrowsAsync<PostgresException>(() => RunAsAppAsync("delete from platform.__ef_migrations_history"));

        Assert.That(error!.SqlState, Is.EqualTo(PostgresErrorCodes.InsufficientPrivilege));
    }

    private static async Task RunAsAppAsync(string sql)
    {
        await using var connection = new NpgsqlConnection(TestDatabase.AppConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }
}
