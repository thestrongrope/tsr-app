using System.Globalization;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.MyAttendance;

// Slice: GET /classes/{class_id}/my-attendance?start_date&end_date -> the caller's own attendance, one entry per conducted session, newest first. Contract: spec/api.yaml.
// PHP: routes/classes.php route_class_attendance (classes.php:433). Guards in PHP's order: attendance:read (403), gender set (400), enrolled or teacher of an active class (404).
// A teacher passes the 404 guard and sees every session as absent (PHP says so on purpose).

internal static class MyAttendanceSlice
{
    internal sealed record Item(
        [property: JsonPropertyName("sessionId")] int SessionId,
        [property: JsonPropertyName("conductedOn")] string ConductedOn,
        [property: JsonPropertyName("present")] bool Present,
        [property: JsonPropertyName("recitation")] int Recitation);

    public static IEndpointRouteBuilder MapMyAttendance(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/my-attendance", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "attendance:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        if (!await ClassGuards.HasNumericGenderAsync(db, caller, ct))
        {
            return Refusals.GenderNotSet();
        }

        var classId = ClassGuards.IdOf(class_id);
        if (!await ClassGuards.CanViewClassAsync(db, classId, caller.Token, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Class not found or not enrolled");
        }

        var history = await StudentAttendance.HistoryAsync(
            db, (int)classId, caller.Token, context.Request.Query["start_date"].LastOrDefault(), context.Request.Query["end_date"].LastOrDefault(), ct);
        return Results.Json(history
            .Select(s => new Item(s.SessionId, s.ConductedOn.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), s.Present, s.Recitation))
            .ToList());
    }
}
