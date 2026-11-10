using System.Text.Json;
using Microsoft.EntityFrameworkCore;

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

    public static async Task WriteAsync<TEvent>(
        DbContext context,
        string eventType,
        TEvent payload,
        TimeProvider clock,
        CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentException.ThrowIfNullOrWhiteSpace(eventType);
        if (context.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException("The outbox is written inside the transaction of the change that caused the event.");
        }

        var id = Guid.CreateVersion7();
        var json = JsonSerializer.Serialize(payload, Json);
        var created = clock.GetUtcNow();
        await context.Database.ExecuteSqlAsync(
            $"insert into platform.outbox (id, event_type, payload, created_at) values ({id}, {eventType}, {json}::jsonb, {created})",
            ct);
    }
}
