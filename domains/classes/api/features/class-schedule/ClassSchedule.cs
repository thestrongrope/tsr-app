using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassSchedule;

// Slice: GET /classes/{class_id}/schedule -> the class's schedule slots and the timezones to pick from. Contract: spec/api.yaml.
// PHP: api/mobile/routes/class_manage.php route_class_schedule_get (:519), api_require_class_schedule, api_class_schedule_payload. Guards: active complete class (404), then classes:update
// on the class or else classes:schedule on it (403, "set this class's schedule"). Slots are the live rows (no deleted_at) in id order (PHP has no ORDER BY).

internal static class ClassScheduleSlice
{
    private const int MaxSlots = 1000;

    internal sealed record Slot(int Id, int Day, int Hour, int Minute, string? Timezone);

    public static IEndpointRouteBuilder MapClassSchedule(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/schedule", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var head = await ClassGuards.FindActiveClassAsync(db, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        var target = AccessTarget.ForClass(head.Id);
        if (!await permissions.CanAsync(caller, "classes:update", target, ct)
            && !await permissions.CanAsync(caller, "classes:schedule", target, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to set this class's schedule");
        }

        var slots = await db.Database
            .SqlQuery<Slot>($"""
                select id as "Id", coalesce(day, 0) as "Day", coalesce(hour, 0) as "Hour", coalesce(minute, 0) as "Minute", timezone as "Timezone"
                from classes.class_schedules
                where class_id = {head.Id} and deleted_at is null
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
        return Results.Json(new Dictionary<string, object?> { ["schedules"] = schedules, ["timezones"] = Timezones.All });
    }
}
