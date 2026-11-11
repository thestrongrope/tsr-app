using System.Globalization;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ChildAttendance;

// Slice: GET /me/children/{child_token}/classes/{class_id}/attendance?start_date&end_date -> a linked child's attendance summary and session history. Contract: spec/api.yaml.
// PHP: routes/children.php route_child_attendance, GuardiansModel::getChildAttendance. Guards: children-performance:read (403), active link AND any enrolment row (404 "Child or class not found").
// The summary counts every conducted session in range, not only those after the child joined (PHP's rule).

internal static class ChildAttendanceSlice
{
    internal sealed record Summary(
        [property: JsonPropertyName("total_sessions")] int TotalSessions,
        [property: JsonPropertyName("attended_sessions")] int AttendedSessions,
        [property: JsonPropertyName("attendance_percentage")] PhpFloat AttendancePercentage,
        [property: JsonPropertyName("total_recitation")] int TotalRecitation);

    internal sealed record Entry(
        [property: JsonPropertyName("date")] string Date,
        [property: JsonPropertyName("duration")] int Duration,
        [property: JsonPropertyName("present")] bool Present,
        [property: JsonPropertyName("recitation")] int Recitation);

    internal sealed record Body([property: JsonPropertyName("summary")] Summary Summary, [property: JsonPropertyName("history")] IReadOnlyList<Entry> History);

    public static IEndpointRouteBuilder MapChildAttendance(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/me/children/{child_token}/classes/{class_id}/attendance", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string child_token, string class_id, HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "children-performance:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var childToken = ClassGuards.IdOf(child_token);
        var classId = ClassGuards.IdOf(class_id);
        if (!await ChildGuards.IsActiveGuardianAsync(db, caller.Token, childToken, ct)
            || !await ChildGuards.IsChildEnrolledAsync(db, childToken, classId, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Child or class not found");
        }

        var history = await StudentAttendance.HistoryAsync(
            db, (int)classId, (int)childToken, context.Request.Query["start_date"].LastOrDefault(), context.Request.Query["end_date"].LastOrDefault(), ct);
        var summary = StudentAttendance.Summarise(history);
        return Results.Json(new Body(
            new Summary(summary.TotalSessions, summary.AttendedSessions, StudentAttendance.Percent(summary, 1), summary.TotalRecitation),
            history.Select(s => new Entry(s.ConductedOn.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), s.Duration, s.Present, s.Recitation)).ToList()));
    }
}
