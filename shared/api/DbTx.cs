using System.Runtime.CompilerServices;
using Npgsql;

namespace Tsr.Shared.Api;

/// <summary>
/// One database transaction: <c>await using var tx = await db.BeginAsync(ct)</c> ... <c>await tx.CommitAsync(ct)</c>. Disposing without a commit
/// rolls back, so a failed write leaves none of the transaction's writes behind. The helpers are the same as on the data source, run on this transaction.
/// </summary>
public sealed class DbTx : IAsyncDisposable
{
    private readonly NpgsqlConnection _connection;
    private readonly NpgsqlTransaction _transaction;
    private readonly bool _owned;
    private readonly Func<bool>? _stillOpen;
    private bool _committed;

    private DbTx(NpgsqlConnection connection, NpgsqlTransaction transaction, bool owned, Func<bool>? stillOpen = null)
    {
        _connection = connection;
        _transaction = transaction;
        _owned = owned;
        _stillOpen = stillOpen;
    }

    /// <summary>
    /// Wraps a connection and transaction someone else owns (Entity Framework's, for a domain not yet converted): dispose then neither rolls back
    /// nor closes, and the owner commits or rolls back.
    /// </summary>
    public static DbTx Join(NpgsqlConnection connection, NpgsqlTransaction transaction)
    {
        ArgumentNullException.ThrowIfNull(connection);
        ArgumentNullException.ThrowIfNull(transaction);
        return new DbTx(connection, transaction, owned: false);
    }

    /// <summary>
    /// As <see cref="Join(NpgsqlConnection, NpgsqlTransaction)"/>, with a check from the joiner that its transaction is still the open one. Npgsql refuses a
    /// joined transaction its owner committed or rolled back, but not one the owner only disposed and replaced: the next statement would run in the new transaction.
    /// </summary>
    internal static DbTx Join(NpgsqlConnection connection, NpgsqlTransaction transaction, Func<bool> stillOpen)
    {
        ArgumentNullException.ThrowIfNull(connection);
        ArgumentNullException.ThrowIfNull(transaction);
        ArgumentNullException.ThrowIfNull(stillOpen);
        return new DbTx(connection, transaction, owned: false, stillOpen);
    }

    internal static DbTx Own(NpgsqlConnection connection, NpgsqlTransaction transaction) => new(connection, transaction, owned: true);

    /// <exception cref="InvalidOperationException">This transaction was joined (its owner commits) or is already committed.</exception>
    public async Task CommitAsync(CancellationToken ct)
    {
        if (!_owned)
        {
            throw new InvalidOperationException("A joined transaction is committed only by its owner: the owner commits.");
        }

        RequireOpen();
        await _transaction.CommitAsync(ct);
        _committed = true;
    }

    // A committed transaction would let a later statement run on the connection with no transaction, outside the unit of work.
    internal void RequireOpen()
    {
        if (_committed)
        {
            throw new InvalidOperationException("The transaction is already committed.");
        }

        if (_stillOpen is not null && !_stillOpen())
        {
            throw new InvalidOperationException("The transaction that was joined has ended.");
        }
    }

    public Task<List<T>> ListAsync<T>(
        Sql sql,
        Func<DbRow, T> read,
        CancellationToken ct,
        [CallerFilePath] string file = "",
        [CallerMemberName] string member = "")
    {
        RequireOpen();
        return Db.ReadListAsync(_connection, _transaction, sql, read, Db.QueryName(file, member), ct);
    }

    /// <inheritdoc cref="Db.ScalarAsync{T}"/>
    public Task<T?> ScalarAsync<T>(
        Sql sql,
        CancellationToken ct,
        [CallerFilePath] string file = "",
        [CallerMemberName] string member = "")
        where T : struct
    {
        RequireOpen();
        return Db.ReadScalarAsync<T>(_connection, _transaction, sql, Db.QueryName(file, member), ct);
    }

    public Task<int> ExecuteAsync(Sql sql, CancellationToken ct)
    {
        RequireOpen();
        return Db.RunAsync(_connection, _transaction, sql, ct);
    }

    public async ValueTask DisposeAsync()
    {
        if (!_owned)
        {
            return;
        }

        try
        {
            await _transaction.DisposeAsync();
        }
        finally
        {
            await _connection.DisposeAsync();
        }
    }
}
