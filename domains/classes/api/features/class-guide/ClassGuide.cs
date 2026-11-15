using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassGuide;

// Slice: GET /classes/{class_id}/guide -> the English guide of the class's level; nulls when the level has none or a blank one. Contract: spec/api.yaml.
// PHP: routes/classes.php route_class_guide (classes.php:408). Guards: gender set (400), class active (404), classes:read on the class (403).
// share_url is the public guide page: PHP's public_web_base() plus /guide.php?guide=<the level's slug>; here the base is TSR_PUBLIC_WEB_BASE. It is null
// without the setting (PHP without REDIRECT_URI), and null with the guide when the level has no guide page, no English guide or a blank one.

internal static class ClassGuideSlice
{
    internal sealed record Body(
        [property: JsonPropertyName("guide")] string? Guide,
        [property: JsonPropertyName("share_url")] string? ShareUrl,
        [property: JsonPropertyName("level_name")] string? LevelName);

    public static IEndpointRouteBuilder MapClassGuide(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/guide", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string class_id,
        HttpContext context,
        ClassesContext db,
        Permissions permissions,
        IConfiguration configuration,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await ClassGuards.HasNumericGenderAsync(db, caller, ct))
        {
            return Refusals.GenderNotSet();
        }

        var head = await ClassGuards.FindActiveClassAsync(db, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "classes:read", AccessTarget.ForClass(head.Id), ct))
        {
            return Refusals.NotPermitted();
        }

        var slug = GuideSlugs.ForLevel(head.LevelId);
        var guides = slug is null
            ? []
            : await db.Database
                .SqlQuery<string>($"""select coalesce(guide, '') as "Value" from classes.guides where level_id = {head.LevelId} and language_id = 1 order by id limit 1""")
                .ToListAsync(ct);
        var html = guides.Count == 0 ? string.Empty : PhpText.Trim(guides[0]);
        if (html.Length == 0)
        {
            return Results.Json(new Body(null, null, head.LevelName));
        }

        var publicWebBase = (configuration["TSR_PUBLIC_WEB_BASE"] ?? string.Empty).TrimEnd('/');
        var shareUrl = publicWebBase.Length == 0 ? null : publicWebBase + "/guide.php?guide=" + slug;
        return Results.Json(new Body(guides[0], shareUrl, head.LevelName));
    }
}
