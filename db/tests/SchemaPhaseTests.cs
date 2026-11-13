using Npgsql;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The schema phase, read from a database built by the migrations alone: the tables in PostgreSQL are the ones the table inventory
/// (docs/specs/initial-build/schema-phase-tables.csv) says were ported, each in its owner's schema, and the API's limited role
/// can use every one of them as the existing grants say (select, insert, update, delete; its sequences; never the migration history).
/// </summary>
public sealed class SchemaPhaseTests
{
    private static readonly string[] Schemas =
        ["identity", "access", "platform", "membership", "content", "classes", "assessment", "notifications"];

    /// <summary>
    /// Tables that exist in PostgreSQL but never in PHP: platform's outbox, the articles, the profile split off <c>users</c>, the role tables,
    /// and content's copy of the website's published content files (the Library reads).
    /// </summary>
    private static readonly string[] NotFromPhp =
    [
        "platform.outbox", "content.articles", "membership.member_profiles", "access.roles", "access.user_roles", "assessment.quiz_state",
        "content.published_articles", "content.categories", "content.publications", "content.refresh_state",
    ];

    private const string History = "__ef_migrations_history";

    private static readonly string[] ExpectedDeleteActions = ["fk_notifier_sent_run c", "fk_syllabus_level r", "fk_user_notifications_notification c"];

    private static readonly string[] Decisions = ["port", "ported", "leave", "derived", "absent"];

    [Test]
    public async Task The_tables_in_the_database_are_the_inventorys_ported_rows_in_their_owners_schemas()
    {
        var expected = InventoryRows()
            .Where(r => r["decision"] is "port" or "ported")
            .Select(r => r["proposed_domain"] + "." + r["table"])
            .Order()
            .ToList();

        var actual = (await ColumnAsync(
                "select table_schema || '.' || table_name from information_schema.tables "
                + "where table_type = 'BASE TABLE' and table_schema = any(@schemas) and table_name <> @history"))
            .Except(NotFromPhp)
            .Order()
            .ToList();

        Assert.That(actual, Is.EqualTo(expected));
    }

    [Test]
    public void The_inventory_decides_every_table_and_this_phase_ports_36()
    {
        var rows = InventoryRows();

        Assert.That(rows.Select(r => r["decision"]).Distinct(), Is.EquivalentTo(Decisions));
        Assert.That(rows.Select(r => r["table"]).Distinct().Count(), Is.EqualTo(rows.Count), "one row per table");
        Assert.That(rows.Count(r => r["decision"] == "port"), Is.EqualTo(36));
        foreach (var owner in new[] { ("classes", 16), ("notifications", 8), ("assessment", 7), ("platform", 4), ("content", 1) })
        {
            Assert.That(rows.Count(r => r["decision"] == "port" && r["proposed_domain"] == owner.Item1), Is.EqualTo(owner.Item2), owner.Item1);
        }
    }

    [Test]
    public async Task Foreign_keys_inside_the_new_schemas_delete_as_PHP_declares_them()
    {
        // PHP names ON DELETE CASCADE for two keys and nothing for the syllabus one, which is RESTRICT: a level in use cannot be removed.
        var keys = await ColumnAsync(
            "select c.conname || ' ' || c.confdeltype::text from pg_constraint c join pg_namespace n on n.oid = c.connamespace "
            + "where c.contype = 'f' and n.nspname in ('classes', 'assessment', 'notifications')");

        Assert.That(
            keys.Order().ToList(),
            Is.EqualTo(ExpectedDeleteActions));
    }

    [Test]
    public async Task The_limited_role_may_read_and_write_every_table_and_use_every_sequence_but_not_the_history()
    {
        var tables = await ColumnAsync(
            "select table_schema || '.' || table_name from information_schema.tables "
            + "where table_type = 'BASE TABLE' and table_schema = any(@schemas) and table_name <> @history");
        Assert.That(tables, Is.Not.Empty);
        var missing = new List<string>();
        foreach (var table in tables)
        {
            var allowed = await BoolAsync("select has_table_privilege('tsr_app', @name, 'select, insert, update, delete')", table);
            if (!allowed)
            {
                missing.Add(table);
            }
        }

        Assert.That(missing, Is.Empty, "Tables the API role cannot read and write");

        var sequences = await ColumnAsync(
            "select sequence_schema || '.' || sequence_name from information_schema.sequences where sequence_schema = any(@schemas)");
        foreach (var sequence in sequences)
        {
            Assert.That(
                await BoolAsync("select has_sequence_privilege('tsr_app', @name, 'usage')", sequence),
                Is.True,
                sequence);
        }

        foreach (var schema in new[] { "classes", "assessment", "notifications" })
        {
            Assert.That(
                await BoolAsync("select has_table_privilege('tsr_app', @name, 'select')", schema + "." + History),
                Is.False,
                schema + " history");
        }
    }

    [Test]
    public async Task The_limited_role_can_write_and_read_back_in_each_new_schema()
    {
        await using var connection = new NpgsqlConnection(TestDatabase.AppConnection);
        await connection.OpenAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        // One round trip per schema: a row with a generated key, read back as the limited role. Rolled back, so nothing is left behind.
        var classTag = await ExecuteScalarAsync(connection, "insert into classes.tags (name) values ('schema-phase-test') returning id");
        var quiz = await ExecuteScalarAsync(connection, "insert into assessment.spot_quizzes (name) values ('schema-phase-test') returning id");
        var device = await ExecuteScalarAsync(
            connection, "insert into notifications.user_devices (token, device_id) values (900999, 'schema-phase-test') returning id");
        var surah = await ExecuteScalarAsync(connection, "insert into content.holy_quran (id, surah, verses) values (9999, 'Test', 1) returning id");
        var language = await ExecuteScalarAsync(connection, "insert into platform.languages (name) values ('schema-phase-test') returning id");

        Assert.That(
            new[] { classTag, quiz, device, surah, language }.All(id => id > 0), Is.True);
        Assert.That(
            await ExecuteScalarAsync(connection, "select count(*) from classes.tags where name = 'schema-phase-test' and created_at is not null"),
            Is.EqualTo(1));
        await transaction.RollbackAsync();
    }

    private static async Task<bool> BoolAsync(string sql, string name)
    {
        await using var connection = new NpgsqlConnection(TestDatabase.OwnerConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("name", name);
        return (bool)(await command.ExecuteScalarAsync())!;
    }

    private static async Task<long> ExecuteScalarAsync(NpgsqlConnection connection, string sql)
    {
        await using var command = new NpgsqlCommand(sql, connection);
        return Convert.ToInt64(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }

    private static async Task<List<string>> ColumnAsync(string sql)
    {
        await using var connection = new NpgsqlConnection(TestDatabase.OwnerConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("schemas", Schemas);
        command.Parameters.AddWithValue("history", History);
        var values = new List<string>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            values.Add(reader.GetString(0));
        }

        return values;
    }

    private static List<Dictionary<string, string>> InventoryRows()
    {
        var path = Path.Combine(TestDatabase.RepoRoot(), "docs", "specs", "initial-build", "schema-phase-tables.csv");
        var records = ReadCsv(File.ReadAllText(path));
        var header = records[0];
        return records.Skip(1).Select(r => header.Zip(r).ToDictionary(p => p.First, p => p.Second)).ToList();
    }

    /// <summary>A minimal RFC 4180 reader: quoted fields may hold commas, doubled quotes and line breaks.</summary>
    private static List<List<string>> ReadCsv(string text)
    {
        var records = new List<List<string>>();
        var record = new List<string>();
        var field = new System.Text.StringBuilder();
        var quoted = false;
        for (var i = 0; i < text.Length; i++)
        {
            var c = text[i];
            if (quoted)
            {
                if (c == '"' && i + 1 < text.Length && text[i + 1] == '"')
                {
                    field.Append('"');
                    i++;
                }
                else if (c == '"')
                {
                    quoted = false;
                }
                else
                {
                    field.Append(c);
                }
            }
            else if (c == '"')
            {
                quoted = true;
            }
            else if (c == ',')
            {
                record.Add(field.ToString());
                field.Clear();
            }
            else if (c == '\n')
            {
                record.Add(field.ToString());
                field.Clear();
                records.Add(record);
                record = [];
            }
            else if (c != '\r')
            {
                field.Append(c);
            }
        }

        return records;
    }
}
