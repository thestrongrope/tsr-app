using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminSyllabusUpdate;

// Slice: PUT /admin/syllabus/{syllabus_id} {subject_name?, description?, link_type?, url?, sort_order?, is_active?} -> the item. Super admin only (403), audit row, body (422 Invalid JSON), the item must exist and not
// be deleted (404 "Syllabus item not found"), then the field checks of domain/SyllabusRules in PHP's order; a field is given when present and not null (sort_order 0, is_active false and description "" count);
// nothing given is 400 "No fields to update". The level cannot change. Writes modified_at and modified_by (the caller's token). Contract: spec/api.yaml.
// PHP: routes/syllabus.php route_admin_syllabus_update (:238). Event: classes.syllabus_item_updated (outbox, same transaction).

internal static class AdminSyllabusUpdateSlice
{
    internal sealed record SyllabusItemUpdated(int SyllabusId, int ChangedBy);

    public static IEndpointRouteBuilder MapAdminSyllabusUpdate(this IEndpointRouteBuilder routes)
    {
        routes.MapPut("/admin/syllabus/{syllabus_id}", HandleAsync).RequireMember(createsMember: true);
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

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var id = ClassGuards.IdOf(syllabus_id);
        if (await SyllabusItems.LiveByIdAsync(db, id, ct) is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Syllabus item not found");
        }

        var parsed = SyllabusRules.Changes(body!);
        if (!parsed.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, parsed.Error!);
        }

        var edit = parsed.Value!;
        if (edit.IsEmpty)
        {
            return Problem.Detail(StatusCodes.Status400BadRequest, "No fields to update");
        }

        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlAsync(
            $"""
            update classes.syllabus set
                subject_name = coalesce({edit.SubjectName}::citext, subject_name),
                description = coalesce({edit.Description}::citext, description),
                link_type = coalesce({edit.LinkType}::citext, link_type),
                url = coalesce({edit.Url}::citext, url),
                sort_order = coalesce({edit.SortOrder}::integer, sort_order),
                is_active = coalesce({edit.IsActive}::smallint, is_active),
                modified_at = now(), modified_by = {caller.Token}
            where id = {id}
            """,
            ct);
        await Outbox.WriteAsync(db, "classes.syllabus_item_updated", new SyllabusItemUpdated((int)id, caller.Token), clock, ct);
        await transaction.CommitAsync(ct);
        return Results.Json(await SyllabusItems.LiveByIdAsync(db, id, ct));
    }
}
