using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.GuidesList;

// Slice: GET /guides -> the class levels that can have a guide (ids 2 to 5), in level order. Permission guides:manage. Contract: spec/api.yaml.
// PHP: routes/guides.php route_guides_levels (guides.php:29).

internal static class GuidesListSlice
{
    internal sealed record Level(int Id, string Name);

    internal sealed record Body([property: JsonPropertyName("levels")] IReadOnlyList<Level> Levels);

    public static IEndpointRouteBuilder MapGuidesList(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/guides", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "guides:manage", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var levels = await db.Database
            .SqlQuery<Level>($"""select id as "Id", name as "Name" from classes.class_levels where id in (2, 3, 4, 5) order by sort_order, id""")
            .ToListAsync(ct);
        return Results.Json(new Body(levels));
    }
}
