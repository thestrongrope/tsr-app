using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminSyllabusCreate;

// Slice: POST /admin/syllabus {level_id, subject_name, url, link_type?, sort_order?, description?} -> 201 with the new item. Super admin only (403 "Only super admins can access this resource"), audit row, body (422),
// the checks of domain/SyllabusRules in PHP's order, then the level must exist (400 "Invalid level_id"). Texts are stored untrimmed. Contract: spec/api.yaml.
// PHP: routes/syllabus.php route_admin_syllabus_create (:188). created_by is the caller's token. Event: classes.syllabus_item_created (outbox, same transaction).

internal static class AdminSyllabusCreateSlice
{
    internal sealed record SyllabusItemCreated(int SyllabusId, int LevelId, int CreatedBy);

    public static IEndpointRouteBuilder MapAdminSyllabusCreate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/syllabus", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
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

        var parsed = SyllabusRules.NewItem(body!);
        if (!parsed.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, parsed.Error!);
        }

        var input = parsed.Value!;
        var levels = await db.Database.SqlQuery<int>($"""select id as "Value" from classes.class_levels where id = {input.LevelId} limit 1""").ToListAsync(ct);
        if (levels.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status400BadRequest, "Invalid level_id");
        }

        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var ids = await db.Database
            .SqlQuery<int>($"""
                insert into classes.syllabus (level_id, subject_name, description, link_type, url, sort_order, created_by)
                values ({input.LevelId}, {input.SubjectName}, {input.Description}, {input.LinkType}, {input.Url}, {input.SortOrder}, {caller.Token})
                returning id as "Value"
                """)
            .ToListAsync(ct);
        await Outbox.WriteAsync(db, "classes.syllabus_item_created", new SyllabusItemCreated(ids[0], levels[0], caller.Token), clock, ct);
        await transaction.CommitAsync(ct);
        return Results.Json(await SyllabusItems.LiveByIdAsync(db, ids[0], ct), statusCode: StatusCodes.Status201Created);
    }
}
