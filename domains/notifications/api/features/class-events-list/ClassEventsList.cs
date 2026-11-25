using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.ClassEventsList;

// Slice: GET /classes/{class_id}/scheduled-events -> {events, slots}: what a sender sees when managing a class's calendar: its live events (by id, each saying whether the caller may edit it
// and whether that would be a take-over) and its live timetable slots (read-only). Contract: spec/api.yaml. PHP: routes/calendar.php route_class_events_list,
// MobileCalendarModel::listForScheduler. Order: notifications:send on the class (403 "You cannot manage events for this class"). At most 500 of each (domain/ClassEvents.cs).

internal static class ClassEventsListSlice
{
    public static IEndpointRouteBuilder MapClassEventsList(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/scheduled-events", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var classId = NotifyGuards.IdOf(class_id);
        var refusal = await ClassEvents.ManageRefusalAsync(permissions, caller, classId, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var items = (await ClassEvents.ItemsByClassAsync(source, permissions, caller, [classId], ct))[classId];
        return Results.Json(new Dictionary<string, object?> { ["events"] = items.Events, ["slots"] = items.Slots }, NotificationsJson.Answers.Answer);
    }
}
