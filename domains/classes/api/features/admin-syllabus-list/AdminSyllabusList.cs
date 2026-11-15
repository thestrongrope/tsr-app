using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminSyllabusList;

// Slice: GET /admin/syllabus?include_inactive -> every level with its live items (levels without items too). Super admin only (syllabus:update, 403 "Only super admins can access this resource"), then the
// admin audit row, then the query (true/1/yes/on or false/0/no/off, any case, trimmed; else 422 "Invalid include_inactive"). Contract: spec/api.yaml.
// PHP: routes/syllabus.php route_admin_syllabus_list (:152). Items sort NULL sort_order first (MariaDB). Bound: 20000 items.

internal static class AdminSyllabusListSlice
{
    internal sealed record Level(int Id, string Code, string Name);

    internal sealed record Section(
        [property: JsonPropertyName("level_id")] int LevelId,
        [property: JsonPropertyName("level_name")] string LevelName,
        [property: JsonPropertyName("level_code")] string LevelCode,
        IReadOnlyList<SyllabusItems.Item> Items);

    public static IEndpointRouteBuilder MapAdminSyllabusList(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/syllabus", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
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

        var values = context.Request.Query["include_inactive"];
        var include = SyllabusRules.IncludeInactive(values.Count == 0 ? null : values[^1]);
        if (!include.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, include.Error!);
        }

        var levels = await db.Database
            .SqlQuery<Level>($"""select id as "Id", code as "Code", name as "Name" from classes.class_levels order by sort_order, id""")
            .ToListAsync(ct);
        var byLevel = (await SyllabusItems.LiveAsync(db, include.Value, ct)).ToLookup(i => i.LevelId);
        return Results.Json(levels.Select(l => new Section(l.Id, l.Name, l.Code, byLevel[l.Id].ToList())).ToList());
    }
}
