using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ConductionCreate;

// Slice: POST /classes/{class_id}/conduction -> record a class session (201), or answer the record an earlier copy of the same request already made (200). Contract: spec/api.yaml.
// PHP: routes/conduction.php route_conduction_create (:445), api_conduction_payload, SessionsModel add, findReplay, recordedAt. Order: active class (404), sessions:create (403), body (422), the payload's rules (422, domain/ConductionRules.cs),
// replay, a session already on the day (409 "A conduction record already exists for this date").
// Writes (domain/ConductionWriter.cs, one transaction): class_sessions (teacher = the class's teacher now, created_by = the caller, created_at = recordedAt or now) and class_attendance; event classes.session_recorded.
// Copied quirks: students who never had a row in the class are dropped without a word, the recorded time is clamped to now and cut to the second, a repeat is a record of the same class, day, caller and recorded time.
// Deviations: one transaction with a class lock (PHP has none); a number beyond its column, a NUL byte or a text over its column is a 422. Nothing is sent to anyone (PHP sends nothing here either).

internal static class ConductionCreateSlice
{
    public static IEndpointRouteBuilder MapConductionCreate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/{class_id}/conduction", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (head, refusal) = await ConductionData.OpenAsync(db, permissions, caller, class_id, "sessions:create", ct);
        if (refusal is not null)
        {
            return refusal;
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

        var recordedAt = ConductionRules.RecordedAt(body!.Has("recordedAt") ? PhpValue.Text(body.Get("recordedAt")) : null, clock.GetUtcNow());
        var saved = await ConductionWriter.CreateAsync(db, clock, head!.Id, caller.Token, payload.Value!, recordedAt, ct);
        if (saved.Duplicate)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "A conduction record already exists for this date");
        }

        var row = await ConductionData.GetSessionAsync(db, saved.SessionId, ct);
        return Results.Json(ConductionData.ToItem(row!, clock.GetUtcNow()), statusCode: saved.Replayed ? StatusCodes.Status200OK : StatusCodes.Status201Created);
    }
}
