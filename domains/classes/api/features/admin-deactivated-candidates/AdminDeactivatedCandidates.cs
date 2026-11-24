using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminDeactivatedCandidates;

// Slice: GET /admin/deactivated-classes/candidates -> {classes}: the active classes one may choose to deactivate, with level name, gender, teacher, city and the live student count. deactivated-classes:manage
// (403 "You do not have permission to do that"), no audit row. Contract: spec/api.yaml.
// PHP: routes/deactivated_classes.php route_admin_deactivated_classes_candidates (:75), ClassesModel::activeClassesForDeactivation (getAll(0, false), domain/ClassListing.cs). Teacher and city are "" when missing.

internal static class AdminDeactivatedCandidatesSlice
{
    internal sealed record Candidate(int Id, string Code, string Level, int Gender, string Teacher, string City, int Students);

    internal sealed record Body(IReadOnlyList<Candidate> Classes);

    public static IEndpointRouteBuilder MapAdminDeactivatedCandidates(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/deactivated-classes/candidates", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var refusal = await AdminGuards.DeactivatedClassesAsync(permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var classes = await ClassListing.AllAsync(source, await ClassListing.AssignedAsync(permissions, caller, ct), includeInactive: false, ct);
        return Results.Json(new Body(classes
            .Select(c => new Candidate(c.Id, PhpCast.Str(c.Code), PhpCast.Str(c.Level), c.Gender ?? 0, PhpCast.Str(c.TeacherName), PhpCast.Str(c.City), c.Students))
            .ToList()), ClassesJson.Answers.DeactivatedCandidatesBody);
    }
}
