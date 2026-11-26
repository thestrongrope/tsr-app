using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassSchedule;

// Slice: GET /classes/{class_id}/schedule -> the class's schedule slots and the timezones to pick from (domain/SchedulePayload.cs). Contract: spec/api.yaml.
// PHP: api/mobile/routes/class_manage.php route_class_schedule_get (:519), api_require_class_schedule, api_class_schedule_payload. Guards: active complete class (404), then classes:update
// on the class or else classes:schedule on it (403, "set this class's schedule"). Slots are the live rows (no deleted_at) in id order (PHP has no ORDER BY).

internal static class ClassScheduleSlice
{
    public static IEndpointRouteBuilder MapClassSchedule(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/schedule", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var head = await ClassGuards.FindActiveClassAsync(source, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await ClassGuards.CanSetScheduleAsync(permissions, caller, head.Id, ct))
        {
            return ClassGuards.ScheduleRefusal();
        }

        return Results.Json(await SchedulePayload.BuildAsync(source, head.Id, ct), ClassesJson.Answers.Answer);
    }
}
