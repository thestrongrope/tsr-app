using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminTransferStudents;

// Slice: GET /admin/transfers/classes/{class_id}/students -> {students}: who can be moved out of the class (domain/TransferRoster.cs: the active students, or for a closed class with none, its deactivation
// cohort). students:transfer (403), then the class in any status (404 "Class not found", also for a path that is not a number). Contact details are returned (administrators only). Contract: spec/api.yaml.
// PHP: routes/student_transfers.php route_admin_transfer_students (:105). Quirks: name is "text" (0 when empty), email and mobile null when empty, joinedOn is the first enrolment's day, removedOn the
// latest removal's.

internal static class AdminTransferStudentsSlice
{
    internal sealed record Student(int Token, object Name, string? Email, string? Mobile, string? JoinedOn, string? RemovedOn, bool FromDeactivation);

    internal sealed record Body(IReadOnlyList<Student> Students);

    public static IEndpointRouteBuilder MapAdminTransferStudents(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/transfers/classes/{class_id}/students", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var refusal = await AdminGuards.TransfersAsync(permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var found = await ClassListing.FindAsync(source, await ClassListing.AssignedAsync(permissions, caller, ct), ClassGuards.IdOf(class_id), ct);
        if (found is null)
        {
            return Refusals.ClassNotFound();
        }

        var roster = await TransferRoster.ForAsync(source, found.Id, found.Status == "A", ct);
        return Results.Json(new Body(roster
            .Select(s => new Student(s.Token, PhpCast.Text(s.Name), PhpCast.StrOrNull(s.Email), PhpCast.StrOrNull(s.Mobile), s.JoinedOn, s.RemovedOn, s.FromDeactivation))
            .ToList()), ClassesJson.Answers.TransferStudentsBody);
    }
}
