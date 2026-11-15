using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminTransferClasses;

// Slice: GET /admin/transfers/classes -> {classes, levels}: every class (closed ones too) and the distinct level names in order of first appearance. students:transfer (403 "Only administrators can transfer
// students"), no audit row. Contract: spec/api.yaml.
// PHP: routes/student_transfers.php route_admin_transfer_classes (:93), ClassesModel::getAll(0, true) (domain/ClassListing.cs). Quirks: name is "text" (the number 0 when empty), the count is the rows not removed
// whatever their status, a class with no level is not listed. A caller whose classes:read is assigned-only (a coordinator given students:transfer by a named grant) sees the assigned classes only, as in PHP.

internal static class AdminTransferClassesSlice
{
    internal sealed record TransferClass(int Id, string Code, object Name, string Level, int Gender, string? Teacher, string? City, string? Country, int Students, bool Active);

    internal sealed record Body(IReadOnlyList<TransferClass> Classes, IReadOnlyList<string> Levels);

    public static IEndpointRouteBuilder MapAdminTransferClasses(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/transfers/classes", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    internal static TransferClass ToWire(ClassListing.Row c) => new(
        c.Id,
        PhpCast.Str(c.Code),
        PhpCast.Text(c.Name),
        PhpCast.Str(c.Level),
        c.Gender ?? 0,
        PhpCast.TextOrNull(c.TeacherName),
        PhpCast.TextOrNull(c.City),
        PhpCast.TextOrNull(c.Country),
        c.Students,
        c.Status == "A");

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
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

        var classes = await ClassListing.AllAsync(db, await ClassListing.AssignedAsync(permissions, caller, ct), includeInactive: true, ct);
        return Results.Json(new Body(classes.Select(ToWire).ToList(), classes.Select(c => c.Level).Distinct().ToList()));
    }
}
