using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.GuideGet;

// Slice: GET /guides/{level_id} -> the English guide of a level as the editor starts from it, or null. Permission guides:manage. Contract: spec/api.yaml.
// PHP: routes/guides.php route_guide_edit_get (guides.php:45). The id is PHP's (int) cast; a level without a guide page (not 2 to 5) is 404.

internal static class GuideGetSlice
{
    internal sealed record Body([property: JsonPropertyName("guide")] string? Guide, [property: JsonPropertyName("level_name")] string LevelName);

    public static IEndpointRouteBuilder MapGuideGet(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/guides/{level_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string level_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
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

        var levelId = ClassGuards.IdOf(level_id);
        if (GuideSlugs.ForLevel(levelId) is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Level not found");
        }

        var names = await source.ListAsync($"""select name as "Value" from classes.class_levels where id = {levelId} limit 1""", row => row.Text("Value"), ct);
        var guides = await source.ListAsync(
            $"""select coalesce(guide, '') as "Value" from classes.guides where level_id = {levelId} and language_id = 1 order by id limit 1""",
            row => row.Text("Value"),
            ct);
        return Results.Json(new Body(guides.Count == 0 ? null : guides[0], names.Count == 0 ? string.Empty : names[0]), ClassesJson.Answers.GuideGetBody);
    }
}
