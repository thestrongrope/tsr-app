using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.RegistrationPlace;

// Slice: POST /registrations/{registration_id}/place {classId} -> put a waiting registrant in a class. Answers {placed: true, registrationId, classId}. Contract: spec/api.yaml.
// PHP: routes/registrations.php route_registrations_place (:75), ClassStudentsModel::addStudent. Order: the waiting-registrant guard (domain/WaitingRegistrant.cs: 403, 409, 403), classId a JSON integer above 0
// (422 "classId must be a class id"), an active complete class (404), students:enrol on that class (403 "You do not have permission to place members in this class"), domain/Enrolment.AddAsync with NO added_by
// (placement is not attributed, as PHP): a gender mismatch is 422 "Could not place them: their gender does not match this class." The registration row is not updated (membership's accepted-registration
// command adds a row only for a member who has none); "placed" is derived, the registrant stops being waiting once enrolled. No lock between the waiting check and the insert, as PHP.
// Event: classes.student_enrolled (source "placed", outbox, same transaction). PHP's registration.placed log line is not written.

internal static class RegistrationPlaceSlice
{
    public static IEndpointRouteBuilder MapRegistrationPlace(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/registrations/{registration_id}/place", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string registration_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (registrant, refusal) = await WaitingRegistrant.RequireAsync(source, permissions, caller, registration_id, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        if (!PhpValue.IsInt(body!.Get("classId"), out var classId) || classId <= 0)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "classId must be a class id");
        }

        var head = await ClassGuards.FindActiveClassAsync(source, classId, ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "students:enrol", AccessTarget.ForClass(head.Id), ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to place members in this class");
        }

        if (!await SaveAsync(source, clock, head.Id, registrant!.Token, ct))
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Could not place them: their gender does not match this class.");
        }

        return Results.Json(new Dictionary<string, object?>
        {
            ["placed"] = true,
            ["registrationId"] = PhpValue.IntOfText(registration_id),
            ["classId"] = head.Id,
        }, ClassesJson.Answers.Answer);
    }

    private static async Task<bool> SaveAsync(NpgsqlDataSource source, TimeProvider clock, int classId, int token, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        if (!await Enrolment.AddAsync(tx, classId, token, null, ct))
        {
            return false;
        }

        await Outbox.WriteAsync(tx, "classes.student_enrolled", new StudentEnrolled(classId, token, null, "placed"), ClassesJson.Default.StudentEnrolled, clock, ct);
        await tx.CommitAsync(ct);
        return true;
    }
}
