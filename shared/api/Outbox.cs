using System.Text.Json;
using MySqlConnector;

namespace Tsr.Shared.Api;

/// <summary>
/// Writes a domain event to the outbox in the same transaction as the change that caused it, so
/// the event exists if and only if the change committed. A relay (hosts/scheduler, the foundation step)
/// publishes outbox rows to Redis Streams; nothing in a slice talks to Redis directly.
/// </summary>
public static class Outbox
{
    // Same JSON shape as the API (camelCase): events are a published contract too (each domain CLAUDE.md, "Events").
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public static async Task WriteAsync<TEvent>(
        MySqlConnection connection,
        MySqlTransaction transaction,
        string eventType,
        TEvent payload,
        TimeProvider clock,
        CancellationToken ct)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(eventType);
        await using var command = new MySqlCommand(
            "insert into outbox (id, event_type, payload, created_at) values (@id, @type, @payload, @created)",
            connection,
            transaction);
        command.Parameters.AddWithValue("@id", Guid.NewGuid().ToString());
        command.Parameters.AddWithValue("@type", eventType);
        command.Parameters.AddWithValue("@payload", JsonSerializer.Serialize(payload, Json));
        command.Parameters.AddWithValue("@created", clock.GetUtcNow().UtcDateTime);
        await command.ExecuteNonQueryAsync(ct);
    }
}
