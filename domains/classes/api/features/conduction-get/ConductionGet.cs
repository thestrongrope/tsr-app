using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ConductionGet;

// Slice: GET /classes/{class_id}/conduction/{session_id} -> one record for editing: the class and roster, the session, its attendance rows, the surah list. Contract: spec/api.yaml.
// PHP: routes/conduction.php route_conduction_get (:398), SessionsModel getById. Guards: active class (404), sessions:update on it (403), the session exists AND belongs to the class (404 "Session not found").
// Copied quirks: no deleted_at filter; attendance is every stored row in insertion order with the member's current name (the stored name for an extra student); editable is the ten-day window from created_at.

internal static class ConductionGetSlice
{
    internal sealed record Detail(
        ConductionData.ClassPayload Class,
        ConductionData.SessionItem Session,
        IReadOnlyList<ConductionData.AttendanceItem> Attendance,
        IReadOnlyList<ConductionData.Surah> HolyQuran);

    public static IEndpointRouteBuilder MapConductionGet(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/conduction/{session_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, string session_id, HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (head, refusal) = await ConductionData.OpenAsync(db, permissions, caller, class_id, "sessions:update", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var session = await ConductionData.GetSessionAsync(db, ClassGuards.IdOf(session_id), ct);
        if (session is null || session.ClassId != head!.Id)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Session not found");
        }

        return Results.Json(new Detail(
            await ConductionData.HeaderAsync(db, head.Id, ct),
            ConductionData.ToItem(session, clock.GetUtcNow()),
            await ConductionData.AttendanceAsync(db, session.Id, ct),
            await ConductionData.HolyQuranAsync(db, ct)));
    }
}
