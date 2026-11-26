using System.Diagnostics.CodeAnalysis;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Npgsql;

namespace Tsr.Shared.Api;

/// <summary>
/// The one bridge from a caller still on Entity Framework to a published command: the command runs on the caller's open transaction.
/// </summary>
public static class EfTransaction
{
    /// <exception cref="InvalidOperationException">The context has no open transaction, or does not use the Npgsql provider.</exception>
    [RequiresUnreferencedCode("Entity Framework is JIT only. A converted domain passes its own DbTx.")]
    [RequiresDynamicCode("Entity Framework is JIT only. A converted domain passes its own DbTx.")]
    public static DbTx Join(DbContext db)
    {
        ArgumentNullException.ThrowIfNull(db);
        var current = db.Database.CurrentTransaction
            ?? throw new InvalidOperationException("A published command runs inside its caller's transaction.");
        var id = current.TransactionId;
        if (db.Database.GetDbConnection() is not NpgsqlConnection connection || current.GetDbTransaction() is not NpgsqlTransaction transaction)
        {
            throw new InvalidOperationException("The bridge needs the Npgsql provider: the context's connection and transaction are not Npgsql's.");
        }

        return DbTx.Join(connection, transaction, () => db.Database.CurrentTransaction?.TransactionId == id);
    }
}
