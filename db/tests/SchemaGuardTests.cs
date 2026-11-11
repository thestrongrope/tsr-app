using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Npgsql;
using NUnit.Framework;
using Tsr.Host.Api;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// Guard 2 (migration-from-tsr-account.md, "Database and migrations"), read from the Postgres catalog
/// of a database built by the migrations alone: text stays case-insensitive (<c>citext</c>), a string
/// with a maximum length keeps it as a CHECK, and each model matches its migrations.
/// </summary>
public sealed class SchemaGuardTests
{
    private const string MigrationHistoryTable = "__ef_migrations_history";

    private const string GeoCollation = "geo_ci_ai";

    private const string GeoReason =
        "geo lookups search, sort and compare this column ignoring case AND accents, as MariaDB did; citext ignores case only "
        + "(docs/specs/initial-build/phase-3-collation-proof.md)";

    private const string ClassesReason =
        "an access rule matches a class's city and country ignoring case AND accents, as MariaDB did; citext ignores case only "
        + "(docs/specs/initial-build/phase-3-collation-proof.md, schema-phase-design.md risks)";

    /// <summary>
    /// "schema.table.column" to the reason it is not citext. The three geo columns the lookups search, sort and compare, and the two class columns an access rule matches:
    /// they use the ICU collation geo_ci_ai, which is still case-insensitive, so the rule's intent holds (see the test below).
    /// </summary>
    private static readonly Dictionary<string, string> NotCitext = new()
    {
        ["platform.geo_countries.name"] = GeoReason,
        ["platform.geo_postal_codes.postal_code"] = GeoReason,
        ["platform.geo_cities.name"] = GeoReason,
        ["classes.classes.city"] = ClassesReason,
        ["classes.classes.country"] = ClassesReason,
        ["classes.v_classes.city"] = ClassesReason, // the view repeats the table column, collation included
        ["classes.v_classes.country"] = ClassesReason,
    };

    /// <summary>Domains that own no table (routes only), so no context.</summary>
    private static readonly HashSet<string> DomainsWithoutTables = ["search"];

    /// <summary>Foreign keys that may cross schemas. Empty: platform's two into identity.users were dropped by its DropIdentityForeignKeys migration.</summary>
    private static readonly HashSet<string> CrossSchemaForeignKeys = [];

    [Test]
    public void Every_domain_has_exactly_one_context_except_those_without_tables()
    {
        foreach (var module in Modules.All)
        {
            var expected = DomainsWithoutTables.Contains(module.Name) ? 0 : 1;
            Assert.That(ContextTypes(module).ToList(), Has.Count.EqualTo(expected), module.Name + " has the wrong number of DbContexts");
        }
    }

    [Test]
    public void Every_domain_schema_is_covered_by_the_guards()
    {
        // The guards read the schemas from the modules, so a module left out of Modules.All would pass them without being checked.
        var expected = new[] { "identity", "access", "platform", "membership", "content", "classes", "assessment", "notifications" };
        Assert.That(Schemas(), Is.EquivalentTo(expected));
    }

    [Test]
    public void Allow_list_entries_carry_a_reason()
    {
        Assert.That(NotCitext.Where(e => string.IsNullOrWhiteSpace(e.Value)).Select(e => e.Key), Is.Empty);
    }

    [Test]
    public async Task No_foreign_key_crosses_domain_schemas()
    {
        await using var connection = new NpgsqlConnection(TestDatabase.OwnerConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(
            """
            select c.conname, c.conname || ': ' || n1.nspname || '.' || t1.relname || ' -> ' || n2.nspname || '.' || t2.relname
            from pg_constraint c
            join pg_class t1 on t1.oid = c.conrelid
            join pg_namespace n1 on n1.oid = t1.relnamespace
            join pg_class t2 on t2.oid = c.confrelid
            join pg_namespace n2 on n2.oid = t2.relnamespace
            where c.contype = 'f' and n1.nspname <> n2.nspname and n1.nspname = any(@schemas)
            """,
            connection);
        command.Parameters.AddWithValue("schemas", Schemas());
        var crossing = new List<string>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            if (!CrossSchemaForeignKeys.Contains(reader.GetString(0)))
            {
                crossing.Add(reader.GetString(1));
            }
        }

        Assert.That(crossing, Is.Empty, "A domain never references another domain's tables (domains/CLAUDE.md rule 7)");
    }

    [Test]
    public async Task Every_text_column_is_citext_unless_allow_listed_with_a_reason()
    {
        var columns = await TextColumnsAsync();

        var offenders = columns
            .Where(c => c.Type != "citext" && !NotCitext.ContainsKey(c.Name))
            .Select(c => c.Name + " is " + c.Type);

        Assert.That(columns, Is.Not.Empty);
        Assert.That(offenders, Is.Empty, "Text columns that are not citext");
    }

    [Test]
    public async Task Columns_that_are_not_citext_use_the_case_and_accent_insensitive_collation()
    {
        await using var connection = new NpgsqlConnection(TestDatabase.OwnerConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(
            """
            select a.attcollation::regcollation::text, c.collprovider::text, c.collisdeterministic
            from pg_attribute a
            join pg_class t on t.oid = a.attrelid
            join pg_namespace n on n.oid = t.relnamespace
            join pg_collation c on c.oid = a.attcollation
            where n.nspname || '.' || t.relname || '.' || a.attname = @column
            """,
            connection);
        command.Parameters.Add(new NpgsqlParameter("column", NpgsqlTypes.NpgsqlDbType.Text));
        foreach (var column in NotCitext.Keys)
        {
            command.Parameters["column"].Value = column;
            await using var reader = await command.ExecuteReaderAsync();
            Assert.That(await reader.ReadAsync(), Is.True, column + " has a collation");
            Assert.That(reader.GetString(0), Does.EndWith(GeoCollation), column);
            Assert.That(reader.GetString(1), Is.EqualTo("i"), column + " uses ICU");
            Assert.That(reader.GetBoolean(2), Is.False, column + " is nondeterministic, so it ignores case and accents");
        }
    }

    [Test]
    public async Task Every_string_with_a_maximum_length_has_a_length_check()
    {
        var checks = await CheckDefinitionsAsync();
        var offenders = new List<string>();
        foreach (var (context, model) in Models())
        {
            foreach (var entity in model.GetEntityTypes())
            {
                foreach (var property in entity.GetProperties().Where(p => p.ClrType == typeof(string) && p.GetMaxLength() is not null))
                {
                    var key = (context.Schema, entity.GetTableName()!);
                    var column = property.GetColumnName();
                    // PostgreSQL prints the check as: CHECK ((char_length((col)::text) <= 36))
                    var expected = new Regex(
                        "char_length\\(\\(?\"?" + Regex.Escape(column) + "\"?\\)?(::text)?\\)\\s*<=\\s*" + property.GetMaxLength() + "\\b",
                        RegexOptions.None,
                        TimeSpan.FromSeconds(1));
                    if (!checks.TryGetValue(key, out var definitions) || !definitions.Any(expected.IsMatch))
                    {
                        offenders.Add(key.Item1 + "." + key.Item2 + "." + column);
                    }
                }
            }
        }

        Assert.That(offenders, Is.Empty, "Columns with a maximum length but no matching CHECK in the database");
    }

    [Test]
    public void Each_model_has_no_pending_changes_against_its_migrations()
    {
        foreach (var (context, _) in Models())
        {
            using var db = context.Create();
            Assert.That(db.Database.HasPendingModelChanges(), Is.False, context.Type.Name + " needs a new migration");
        }
    }

    private sealed record ContextInfo(Type Type, string Schema)
    {
        public DbContext Create()
        {
            var builder = (DbContextOptionsBuilder)Activator.CreateInstance(typeof(DbContextOptionsBuilder<>).MakeGenericType(Type))!;
            builder.UseNpgsql(TestDatabase.OwnerConnection);
            return (DbContext)Activator.CreateInstance(Type, builder.Options)!;
        }
    }

    private sealed record Column(string Name, string Type);

    private static IEnumerable<Type> ContextTypes(ModuleInfo module) =>
        module.Assembly.GetTypes().Where(t => t.IsSubclassOf(typeof(TsrDbContext)) && !t.IsAbstract);

    private static List<(ContextInfo Context, IModel Model)> Models()
    {
        var models = new List<(ContextInfo, IModel)>();
        foreach (var type in Modules.All.SelectMany(ContextTypes))
        {
            var info = new ContextInfo(type, string.Empty);
            using var db = info.Create();
            var model = db.GetService<IDesignTimeModel>().Model;
            models.Add((info with { Schema = model.GetDefaultSchema()! }, model));
        }

        return models;
    }

    private static string[] Schemas() => Models().Select(m => m.Context.Schema).ToArray();

    private static async Task<List<Column>> TextColumnsAsync()
    {
        await using var connection = new NpgsqlConnection(TestDatabase.OwnerConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(
            """
            select table_schema || '.' || table_name || '.' || column_name,
                   case when data_type = 'USER-DEFINED' then udt_name else data_type end
            from information_schema.columns
            where table_schema = any(@schemas)
              and table_name <> @history
              and (data_type in ('text', 'character varying', 'character') or udt_name = 'citext')
            """,
            connection);
        command.Parameters.AddWithValue("schemas", Schemas());
        command.Parameters.AddWithValue("history", MigrationHistoryTable);
        var columns = new List<Column>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            columns.Add(new Column(reader.GetString(0), reader.GetString(1)));
        }

        return columns;
    }

    private static async Task<Dictionary<(string, string), List<string>>> CheckDefinitionsAsync()
    {
        await using var connection = new NpgsqlConnection(TestDatabase.OwnerConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(
            """
            select n.nspname, t.relname, pg_get_constraintdef(c.oid)
            from pg_constraint c
            join pg_class t on t.oid = c.conrelid
            join pg_namespace n on n.oid = t.relnamespace
            where c.contype = 'c' and n.nspname = any(@schemas)
            """,
            connection);
        command.Parameters.AddWithValue("schemas", Schemas());
        var checks = new Dictionary<(string, string), List<string>>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var key = (reader.GetString(0), reader.GetString(1));
            if (!checks.TryGetValue(key, out var list))
            {
                checks[key] = list = [];
            }

            list.Add(reader.GetString(2));
        }

        return checks;
    }
}
