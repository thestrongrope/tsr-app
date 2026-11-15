using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.SyllabusLevels;

// Slice: GET /syllabus/levels -> every class level with its sort order, for the level picker. Permission syllabus:read. Contract: spec/api.yaml.
// PHP: routes/syllabus.php route_syllabus_levels (syllabus.php:86). Unlike GET /class-levels, the sort order is returned (the app reads it).

internal static class SyllabusLevelsSlice
{
    internal sealed record Level(int Id, string Code, string Name, [property: JsonPropertyName("sort_order")] int SortOrder);

    public static IEndpointRouteBuilder MapSyllabusLevels(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/syllabus/levels", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "syllabus:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var levels = await db.Database
            .SqlQuery<Level>($"""select id as "Id", code as "Code", name as "Name", sort_order as "SortOrder" from classes.class_levels order by sort_order, id""")
            .ToListAsync(ct);
        return Results.Json(levels);
    }
}
