using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.SyllabusLevel;

// Slice: GET /syllabus/level/{level_id} -> one level's active syllabus items. Permission syllabus:read (every member holds it). Contract: spec/api.yaml.
// PHP: routes/syllabus.php route_syllabus_by_level (syllabus.php:100). The id is PHP's (int) cast; an unknown level is 404. Dates are naive Y-m-d\TH:i:s.

internal static class SyllabusLevelSlice
{
    internal sealed record Level(int Id, string Name, string Code);

    internal sealed record Body(
        [property: JsonPropertyName("level_id")] int LevelId,
        [property: JsonPropertyName("level_name")] string LevelName,
        [property: JsonPropertyName("level_code")] string LevelCode,
        IReadOnlyList<SyllabusItems.Item> Items);

    public static IEndpointRouteBuilder MapSyllabusLevel(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/syllabus/level/{level_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string level_id, HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
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

        var levelId = ClassGuards.IdOf(level_id);
        var levels = await db.Database
            .SqlQuery<Level>($"""select id as "Id", name as "Name", code as "Code" from classes.class_levels where id = {levelId} limit 1""")
            .ToListAsync(ct);
        if (levels.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Level not found");
        }

        var items = await SyllabusItems.ActiveOfLevelAsync(db, levelId, ct);
        return Results.Json(new Body(levels[0].Id, levels[0].Name, levels[0].Code, items));
    }
}
