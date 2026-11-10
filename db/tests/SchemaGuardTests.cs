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

    /// <summary>"schema.table.column" to the reason it is case-sensitive. Empty today: no plain text column is.</summary>
    private static readonly Dictionary<string, string> CaseSensitive = [];

    [Test]
    public void Every_domain_has_exactly_one_context()
    {
        foreach (var module in Modules.All)
        {
            Assert.That(ContextTypes(module).ToList(), Has.Count.EqualTo(1), module.Name + " must have one DbContext");
        }
    }

    [Test]
    public void Allow_list_entries_carry_a_reason()
    {
        Assert.That(CaseSensitive.Where(e => string.IsNullOrWhiteSpace(e.Value)).Select(e => e.Key), Is.Empty);
    }

    [Test]
    public async Task Every_text_column_is_citext_unless_allow_listed_with_a_reason()
    {
        var columns = await TextColumnsAsync();

        var offenders = columns
            .Where(c => c.Type != "citext" && !CaseSensitive.ContainsKey(c.Name))
            .Select(c => c.Name + " is " + c.Type);

        Assert.That(columns, Is.Not.Empty);
        Assert.That(offenders, Is.Empty, "Text columns that are not citext");
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
