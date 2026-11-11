using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP's <c>api_class_schedule_payload</c>: the live slots of a class (no ORDER BY in PHP, so id order) and the timezones to pick from. GET and PUT <c>/classes/{id}/schedule</c> answer with it.
/// </summary>
internal static class SchedulePayload
{
    private const int MaxSlots = 1000;

    internal sealed record Slot(int Id, int Day, int Hour, int Minute, string? Timezone);

    public static async Task<Dictionary<string, object?>> BuildAsync(ClassesContext db, int classId, CancellationToken ct)
    {
        var slots = await db.Database
            .SqlQuery<Slot>($"""
                select id as "Id", coalesce(day, 0) as "Day", coalesce(hour, 0) as "Hour", coalesce(minute, 0) as "Minute", timezone as "Timezone"
                from classes.class_schedules
                where class_id = {classId} and deleted_at is null
                order by id
                limit {MaxSlots}
                """)
            .ToListAsync(ct);

        var schedules = slots.Select(s => new Dictionary<string, object?>
        {
            ["id"] = s.Id,
            ["day"] = s.Day,
            ["hour"] = s.Hour,
            ["minute"] = s.Minute,
            ["timezone"] = s.Timezone ?? string.Empty,
        }).ToList();
        return new Dictionary<string, object?> { ["schedules"] = schedules, ["timezones"] = Timezones.All };
    }
}
