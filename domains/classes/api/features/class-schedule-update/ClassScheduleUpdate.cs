using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassScheduleUpdate;

// Slice: PUT /classes/{class_id}/schedule {schedules} -> replace the class's weekly slots; answers like GET (domain/SchedulePayload.cs). Contract: spec/api.yaml.
// PHP: routes/class_manage.php route_class_schedule_put (:532), api_manage_schedules_input, ClassesModel::replaceSchedules. Order: active complete class (404), classes:update or classes:schedule on it (403), body (422), the
// slots (422 messages in ScheduleInput). Topics and every other field of a slot are ignored. The edit, the inserts and the soft deletes are one transaction (domain/ScheduleWriter.cs), as in PHP.
// Event: classes.schedule_replaced (outbox, same transaction). PHP touches no search index here.

internal static class ClassScheduleUpdateSlice
{
    internal sealed record ScheduleReplaced(int ClassId, int SlotCount, int ChangedBy);

    public static IEndpointRouteBuilder MapClassScheduleUpdate(this IEndpointRouteBuilder routes)
    {
        routes.MapPut("/classes/{class_id}/schedule", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
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

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var slots = ScheduleInput.Parse(body!.Get("schedules"), topicIds: null);
        if (!slots.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, slots.Error!);
        }

        await using (var tx = await source.BeginAsync(ct))
        {
            await ScheduleWriter.ReplaceAsync(tx, head.Id, slots.Value!, caller.Token, ct);
            await Outbox.WriteAsync(tx, "classes.schedule_replaced", new ScheduleReplaced(head.Id, slots.Value!.Count, caller.Token), ClassesJson.Default.ScheduleReplaced, clock, ct);
            await tx.CommitAsync(ct);
        }

        return Results.Json(await SchedulePayload.BuildAsync(source, head.Id, ct), ClassesJson.Answers.Answer);
    }
}
