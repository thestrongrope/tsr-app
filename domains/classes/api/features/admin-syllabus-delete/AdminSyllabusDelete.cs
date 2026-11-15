using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminSyllabusDelete;

// Slice: DELETE /admin/syllabus/{syllabus_id} -> 200 {"success": true}; a soft delete (deleted_at, deleted_by = the caller's token, and modified_at, which MariaDB stamps on every update). Super admin only (403),
// audit row, the item must exist and not be deleted (404 "Syllabus not found", the edit's text differs). No body is read. Contract: spec/api.yaml.
// PHP: routes/syllabus.php route_admin_syllabus_delete (:309). Event: classes.syllabus_item_deleted (outbox, same transaction).

internal static class AdminSyllabusDeleteSlice
{
    internal sealed record SyllabusItemDeleted(int SyllabusId, int DeletedBy);

    internal sealed record Done(bool Success);

    public static IEndpointRouteBuilder MapAdminSyllabusDelete(this IEndpointRouteBuilder routes)
    {
        routes.MapDelete("/admin/syllabus/{syllabus_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string syllabus_id, HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var refusal = await AdminGuards.SyllabusAdminAsync(context, db, permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var id = ClassGuards.IdOf(syllabus_id);
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var deleted = await db.Database.ExecuteSqlAsync(
            $"update classes.syllabus set deleted_at = now(), deleted_by = {caller.Token}, modified_at = now() where id = {id} and deleted_at is null",
            ct);
        if (deleted == 0)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Syllabus not found");
        }

        await Outbox.WriteAsync(db, "classes.syllabus_item_deleted", new SyllabusItemDeleted((int)id, caller.Token), clock, ct);
        await transaction.CommitAsync(ct);
        return Results.Json(new Done(true));
    }
}
