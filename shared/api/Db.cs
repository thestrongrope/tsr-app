using System.Runtime.CompilerServices;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;

namespace Tsr.Shared.Api;

/// <summary>
/// Reads, writes and transactions on the shared data source, without Entity Framework. SQL is a <see cref="Sql"/>, never a string, so a value
/// reaches the database only as a parameter (rule 5). Each helper exists on the data source and on <see cref="DbTx"/> and shares one implementation.
/// Every helper passes the cancellation token to open, execute and read, and releases its connection, command and reader.
/// </summary>
public static class Db
{
    private const int PoolLimit = 20;

    /// <summary>
    /// Registers the one data source. Same connection string and the same 5 s connect and command timeouts as <see cref="DomainContexts"/>.
    /// The pool is capped at 20 so that this second pool beside EF's cannot make connection use much worse; the cap goes when EF's pool does.
    /// </summary>
    public static IServiceCollection AddTsrDataSource(this IServiceCollection services)
    {
        ArgumentNullException.ThrowIfNull(services);
        services.TryAddSingleton<NpgsqlDataSource>(provider =>
        {
            var settings = provider.GetRequiredService<DbSettings>();
            var connection = new NpgsqlConnectionStringBuilder(settings.ConnectionString)
            {
                Timeout = DomainContexts.TimeoutSeconds,
                CommandTimeout = DomainContexts.TimeoutSeconds,
                MaxPoolSize = PoolLimit,
            };
            return new NpgsqlSlimDataSourceBuilder(connection.ConnectionString).EnableArrays().EnableTransportSecurity().Build();
        });
        return services;
    }

    public static async Task<DbTx> BeginAsync(this NpgsqlDataSource source, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(source);
        var connection = await source.OpenConnectionAsync(ct);
        try
        {
            return DbTx.Own(connection, await connection.BeginTransactionAsync(ct));
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }
    }

    public static async Task<List<T>> ListAsync<T>(
        this NpgsqlDataSource source,
        Sql sql,
        Func<DbRow, T> read,
        CancellationToken ct,
        [CallerFilePath] string file = "",
        [CallerMemberName] string member = "")
    {
        ArgumentNullException.ThrowIfNull(source);
        RequireSql(sql);
        await using var connection = await source.OpenConnectionAsync(ct);
        return await ReadListAsync(connection, null, sql, read, QueryName(file, member), ct);
    }

    /// <summary>
    /// The first column of the first row; <c>null</c> when there is no row or the value is null, so no row is never a real 0.
    /// There is no string scalar: read a string with <see cref="ListAsync"/>.
    /// </summary>
    /// <exception cref="DbShapeException">The select has more than one column, or the column is of another type than <typeparamref name="T"/>, even when no row matches.</exception>
    public static async Task<T?> ScalarAsync<T>(
        this NpgsqlDataSource source,
        Sql sql,
        CancellationToken ct,
        [CallerFilePath] string file = "",
        [CallerMemberName] string member = "")
        where T : struct
    {
        ArgumentNullException.ThrowIfNull(source);
        RequireSql(sql);
        await using var connection = await source.OpenConnectionAsync(ct);
        return await ReadScalarAsync<T>(connection, null, sql, QueryName(file, member), ct);
    }

    /// <summary>Runs a write and returns the rows affected.</summary>
    public static async Task<int> ExecuteAsync(this NpgsqlDataSource source, Sql sql, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(source);
        RequireSql(sql);
        await using var connection = await source.OpenConnectionAsync(ct);
        return await RunAsync(connection, null, sql, ct);
    }

    // The file's name only: a build machine's directories must not reach a log.
    internal static string QueryName(string file, string member)
    {
        var start = file.AsSpan().LastIndexOfAny('/', '\\') + 1;
        return file[start..] + ":" + member;
    }

    internal static async Task<List<T>> ReadListAsync<T>(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        Sql sql,
        Func<DbRow, T> read,
        string query,
        CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(read);
        RequireSql(sql);
        await using var command = CreateCommand(connection, transaction, sql);
        await using var reader = await command.ExecuteReaderAsync(ct);
        var row = new DbRow(reader, query);
        var rows = new List<T>();
        while (await reader.ReadAsync(ct))
        {
            row.Begin();
            rows.Add(read(row));
            row.End();
        }

        return rows;
    }

    internal static async Task<T?> ReadScalarAsync<T>(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        Sql sql,
        string query,
        CancellationToken ct)
        where T : struct
    {
        RequireSql(sql);
        await using var command = CreateCommand(connection, transaction, sql);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (reader.FieldCount != 1)
        {
            throw new DbShapeException($"{query}: a scalar select must return exactly one column, it returned {reader.FieldCount}");
        }

        // The column's type is known before any row is read, so an empty result cannot hide a wrongly typed scalar.
        if (!DbRow.Accepts(reader.GetFieldType(0), reader.GetDataTypeName(0), typeof(T)))
        {
            throw new DbShapeException($"{query}: column '{reader.GetName(0)}' is of type {reader.GetFieldType(0).Name} but the scalar reads {typeof(T).Name}");
        }

        if (!await reader.ReadAsync(ct) || await reader.IsDBNullAsync(0, ct))
        {
            return null;
        }

        return await reader.GetFieldValueAsync<T>(0, ct);
    }

    internal static async Task<int> RunAsync(NpgsqlConnection connection, NpgsqlTransaction? transaction, Sql sql, CancellationToken ct)
    {
        RequireSql(sql);
        await using var command = CreateCommand(connection, transaction, sql);
        return await command.ExecuteNonQueryAsync(ct);
    }

    // default(Sql) holds no text: refuse it before a connection is opened, rather than fail on a null.
    private static void RequireSql(Sql sql)
    {
        if (sql.IsDefault)
        {
            throw new ArgumentException("Sql must be built from an interpolated string, not default.", nameof(sql));
        }
    }

    private static NpgsqlCommand CreateCommand(NpgsqlConnection connection, NpgsqlTransaction? transaction, Sql sql)
    {
        var command = new NpgsqlCommand(sql.Text, connection, transaction);
        // A clone per run: a parameter belongs to one command, and a Sql can be run again (a count, then a list; a retry).
        foreach (var parameter in sql.Parameters)
        {
            command.Parameters.Add(parameter.Clone());
        }

        return command;
    }
}
