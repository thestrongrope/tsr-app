using System.Diagnostics.CodeAnalysis;
using System.Text.Json;
using System.Text.Json.Serialization.Metadata;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Npgsql;

namespace Tsr.Shared.Api;

/// <summary>
/// Writes a domain event to the outbox in the same transaction as the change that caused it, so
/// the event exists if and only if the change committed: the caller starts the transaction on its own
/// context and this writes through that context's connection. The table is platform-owned (mapped by
/// platform's context, schema "platform"). A relay (hosts/scheduler, the foundation step) publishes outbox
/// rows to Redis Streams; nothing in a slice talks to Redis directly.
/// </summary>
public static class Outbox
{
    // Same JSON shape as the API (camelCase): events are a published contract too (each domain CLAUDE.md, "Events").
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    [RequiresUnreferencedCode("Entity Framework is JIT only. Use the DbTx overload with a source-generated JsonTypeInfo.")]
    [RequiresDynamicCode("Entity Framework is JIT only. Use the DbTx overload with a source-generated JsonTypeInfo.")]
    public static async Task WriteAsync<TEvent>(
        DbContext context,
        string eventType,
        TEvent payload,
        TimeProvider clock,
        CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentException.ThrowIfNullOrWhiteSpace(eventType);
        var transaction = context.Database.CurrentTransaction
            ?? throw new InvalidOperationException("The outbox is written inside the transaction of the change that caused the event.");

        // The context owns the connection and transaction; joining them means this neither commits, rolls back nor closes.
        var tx = DbTx.Join((NpgsqlConnection)context.Database.GetDbConnection(), (NpgsqlTransaction)transaction.GetDbTransaction());
        await InsertAsync(tx, eventType, JsonSerializer.Serialize(payload, Json), clock, ct);
    }

    /// <summary>Writes the event on the caller's <see cref="DbTx"/>, with a source-generated serializer (no reflection).</summary>
    public static Task WriteAsync<TEvent>(
        DbTx tx,
        string eventType,
        TEvent payload,
        JsonTypeInfo<TEvent> type,
        TimeProvider clock,
        CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(tx);
        ArgumentException.ThrowIfNullOrWhiteSpace(eventType);
        ArgumentNullException.ThrowIfNull(type);
        return InsertAsync(tx, eventType, JsonSerializer.Serialize(payload, type), clock, ct);
    }

    // The one insert both overloads end in.
    private static async Task InsertAsync(DbTx tx, string eventType, string json, TimeProvider clock, CancellationToken ct)
    {
        var id = Guid.CreateVersion7();
        var created = clock.GetUtcNow();
        await tx.ExecuteAsync(
            $"insert into platform.outbox (id, event_type, payload, created_at) values ({id}, {eventType}, {json}::jsonb, {created})",
            ct);
    }
}
