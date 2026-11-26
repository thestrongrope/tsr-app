using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ConductionUpdate;

// Slice: PUT /classes/{class_id}/conduction/{session_id} -> replace a record's fields and attendance; answers the saved session. Contract: spec/api.yaml.
// PHP: routes/conduction.php route_conduction_update (:501), SessionsModel edit and isEditable. Order: active class (404), sessions:update (403), the session exists AND belongs to the class (404 "Session not found"),
// still editable (403 "Session is not editable": more than ten whole days since it was made), body (422), the payload's rules (422, the same as POST), another session on the new day (409 "Another session already exists for this date").
// Writes (domain/ConductionWriter.cs, one transaction): class_sessions (updated_at, updated_by; teacher, created_by and created_at stay), class_attendance deleted and written again; event classes.session_updated.
// Copied quirks: the edit window ignores who the caller is (PHP passes canManage true), a student marked in the body who never was in the class is dropped, the old attendance rows are replaced whole.

internal static class ConductionUpdateSlice
{
    public static IEndpointRouteBuilder MapConductionUpdate(this IEndpointRouteBuilder routes)
    {
        routes.MapPut("/classes/{class_id}/conduction/{session_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, string session_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (head, refusal) = await ConductionData.OpenAsync(source, permissions, caller, class_id, "sessions:update", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var session = await ConductionData.GetSessionAsync(source, ClassGuards.IdOf(session_id), ct);
        if (session is null || session.ClassId != head!.Id)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Session not found");
        }

        if (!ConductionRules.IsEditable(session.CreatedAt, clock.GetUtcNow()))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "Session is not editable");
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var payload = ConductionRules.Parse(body!, ConductionData.Today(clock));
        if (!payload.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, payload.Error!);
        }

        if (!await ConductionWriter.UpdateAsync(source, clock, head.Id, session.Id, caller.Token, payload.Value!, ct))
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "Another session already exists for this date");
        }

        var saved = await ConductionData.GetSessionAsync(source, session.Id, ct);
        return Results.Json(ConductionData.ToItem(saved!, clock.GetUtcNow()), ClassesJson.Answers.ConductionSessionItem);
    }
}
