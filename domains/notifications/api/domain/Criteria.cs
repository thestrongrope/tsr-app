using System.Text.Json;
using Microsoft.EntityFrameworkCore;

namespace Tsr.Notifications.Api.Domain;

/// <summary>
/// Reading the <c>target_audience_criteria</c> JSON a notification was stored with (PHP <c>json_decode($x, true)</c>): an unreadable value is "no criteria", never an error.
/// Also the class names PHP looks up for it (<c>namesById</c>: the class code and name joined by a space), read from classes' published view.
/// </summary>
internal static class Criteria
{
    public static JsonElement? Parse(string? text)
    {
        if (string.IsNullOrEmpty(text))
        {
            return null;
        }

        try
        {
            return JsonElement.Parse(text);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    /// <summary>The string field of an object criteria, or "".</summary>
    public static string TypeOf(JsonElement? criteria) =>
        criteria is { ValueKind: JsonValueKind.Object } c && c.TryGetProperty("type", out var type) && type.ValueKind == JsonValueKind.String ? type.GetString() ?? string.Empty : string.Empty;

    /// <summary>The ids of a JSON list as PHP's <c>array_map('intval')</c> then "above zero, each once".</summary>
    public static List<int> PositiveIds(IEnumerable<JsonElement> values)
    {
        var ids = new List<int>();
        foreach (var value in values)
        {
            var id = (int)Math.Clamp(PhpValue.ToInteger(value), 0, int.MaxValue);
            if (id > 0 && !ids.Contains(id))
            {
                ids.Add(id);
            }
        }

        return ids;
    }

    internal sealed record Named(int Id, string Name);

    /// <summary>Class id to "code name", for the ids that exist.</summary>
    public static async Task<Dictionary<int, string>> ClassNamesAsync(NotificationsContext db, IEnumerable<int> ids, CancellationToken ct)
    {
        var wanted = ids.Distinct().Take(Audience.MaxRecipients).ToArray();
        if (wanted.Length == 0)
        {
            return [];
        }

        var rows = await db.Database
            .SqlQuery<Named>($"""select id as "Id", trim(coalesce(code, '') || ' ' || coalesce(name, '')) as "Name" from classes.v_classes where id = any({wanted})""")
            .ToListAsync(ct);
        return rows.ToDictionary(r => r.Id, r => r.Name);
    }
}
