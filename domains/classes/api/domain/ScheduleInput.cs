using System.Text.Json;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP's <c>api_manage_schedules_input</c> (class_manage.php), shared by the writes that take a weekly schedule: a list of at most 21 slots, each with a day (1 to 7), hour (0 to 23) and minute (0 to 59)
/// written as JSON integers and a supported timezone ("Calcutta" is read as "Kolkata"). When topics are asked for, each slot's topics are checked too. The first failure is the 422 message, in PHP's order.
/// </summary>
internal static class ScheduleInput
{
    private const int MaxSlots = 21;

    internal sealed record Topic(JsonElement Id, int TopicId);

    internal sealed record Slot(JsonElement Id, int Day, int Hour, int Minute, string Timezone, IReadOnlyList<Topic> Topics);

    /// <param name="schedules">The body's <c>schedules</c> value (missing or null is refused like a non-list).</param>
    /// <param name="topicIds">The ids a topic may name; null when the slot's topics are not read (the schedule route ignores them).</param>
    public static Result<IReadOnlyList<Slot>> Parse(JsonElement schedules, IReadOnlySet<int>? topicIds)
    {
        if (schedules.ValueKind is not (JsonValueKind.Array or JsonValueKind.Object) || JsonBody.Entries(schedules).Count > MaxSlots)
        {
            return Result.Fail<IReadOnlyList<Slot>>("schedules must be a list of at most 21 entries");
        }

        var slots = new List<Slot>();
        foreach (var (_, entry) in JsonBody.Entries(schedules))
        {
            var parsed = ParseSlot(entry, topicIds);
            if (!parsed.IsSuccess)
            {
                return Result.Fail<IReadOnlyList<Slot>>(parsed.Error!);
            }

            slots.Add(parsed.Value!);
        }

        return Result.Ok<IReadOnlyList<Slot>>(slots);
    }

    private static Result<Slot> ParseSlot(JsonElement entry, IReadOnlySet<int>? topicIds)
    {
        if (!TryFields(entry, out var day, out var hour, out var minute, out var zone))
        {
            return Result.Fail<Slot>("each schedule needs a day (1-7), hour (0-23), minute (0-59) and timezone");
        }

        var timezone = zone.Replace("Calcutta", "Kolkata", StringComparison.Ordinal);
        if (!Timezones.All.Any(t => (string?)t["timezone"] == timezone))
        {
            return Result.Fail<Slot>("timezone is not one of the supported timezones");
        }

        var topics = new List<Topic>();
        if (topicIds is not null && entry.TryGetProperty("topics", out var raw))
        {
            foreach (var (_, topic) in JsonBody.Entries(raw))
            {
                if (!IsKnownTopic(topic, topicIds, out var topicId))
                {
                    return Result.Fail<Slot>("each topic needs a topicId from the topics list");
                }

                topics.Add(new Topic(topic.TryGetProperty("id", out var id) ? id : default, topicId));
            }
        }

        return Result.Ok(new Slot(entry.TryGetProperty("id", out var slotId) ? slotId : default, day, hour, minute, timezone, topics));
    }

    private static bool TryFields(JsonElement entry, out int day, out int hour, out int minute, out string zone)
    {
        day = hour = minute = 0;
        zone = string.Empty;
        if (entry.ValueKind != JsonValueKind.Object)
        {
            return false;
        }

        var ok = IntBetween(entry, "day", 1, 7, out day)
            && IntBetween(entry, "hour", 0, 23, out hour)
            && IntBetween(entry, "minute", 0, 59, out minute)
            && entry.TryGetProperty("timezone", out var timezone)
            && timezone.ValueKind == JsonValueKind.String;
        zone = ok ? entry.GetProperty("timezone").GetString() ?? string.Empty : string.Empty;
        return ok;
    }

    private static bool IntBetween(JsonElement entry, string name, int min, int max, out int value)
    {
        value = 0;
        if (!entry.TryGetProperty(name, out var raw) || !PhpValue.IsInt(raw, out var number) || number < min || number > max)
        {
            return false;
        }

        value = (int)number;
        return true;
    }

    private static bool IsKnownTopic(JsonElement topic, IReadOnlySet<int> topicIds, out int topicId)
    {
        topicId = 0;
        if (topic.ValueKind != JsonValueKind.Object || !topic.TryGetProperty("topicId", out var raw) || !PhpValue.IsInt(raw, out var number))
        {
            return false;
        }

        topicId = (int)Math.Clamp(number, int.MinValue, int.MaxValue);
        return topicIds.Contains(topicId);
    }
}
