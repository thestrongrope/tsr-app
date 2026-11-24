using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Microsoft.Extensions.Configuration;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.MeGuide;

// Slice: GET /me/guides/{slug} -> one level's English guide by the slug of its guide link, untrimmed, with the link to share and the level's name. Contract: spec/api.yaml.
// PHP: routes/guides.php route_reader_guide, GuidesModel::forSlug. Guards, in PHP's order: syllabus:read (403), a student or a teacher (403), then the
// lookup: a slug that names no level (the match is exact), no English guide row or a blank guide is 404 "Guide not found".
// share_url is PHP's public_web_base() plus /guide.php?guide=<slug>; here the base is TSR_PUBLIC_WEB_BASE, and without it share_url is null.

internal static class MeGuideSlice
{
    internal sealed record Body(
        [property: JsonPropertyName("guide")] string Guide,
        [property: JsonPropertyName("share_url")] string? ShareUrl,
        [property: JsonPropertyName("level_name")] string LevelName);

    public static IEndpointRouteBuilder MapMeGuide(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/me/guides/{slug}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string slug,
        HttpContext context,
        NpgsqlDataSource source,
        Permissions permissions,
        IConfiguration configuration,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var refusal = await GuideReaders.RefusalAsync(caller, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var levelId = GuideSlugs.LevelFor(slug);
        var guides = levelId is null
            ? []
            : await source.ListAsync(
                $"""select coalesce(guide, '') as "Value" from classes.guides where level_id = {levelId} and language_id = 1 order by id limit 1""",
                row => row.Text("Value"),
                ct);
        if (guides.Count == 0 || PhpText.Trim(guides[0]).Length == 0)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Guide not found");
        }

        var names = await source.ListAsync($"""select name as "Value" from classes.class_levels where id = {levelId} limit 1""", row => row.Text("Value"), ct);
        var publicWebBase = (configuration["TSR_PUBLIC_WEB_BASE"] ?? string.Empty).TrimEnd('/');
        var shareUrl = publicWebBase.Length == 0 ? null : publicWebBase + "/guide.php?guide=" + slug;
        return Results.Json(new Body(guides[0], shareUrl, names.Count == 0 ? string.Empty : names[0]), ClassesJson.Answers.MeGuideBody);
    }
}
