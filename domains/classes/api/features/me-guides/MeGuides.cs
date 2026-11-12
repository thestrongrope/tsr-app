using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.MeGuides;

// Slice: GET /me/guides -> the guides a student or teacher can open: the levels that have a guide page, in level order, by slug. Contract: spec/api.yaml.
// PHP: routes/guides.php route_reader_guides. Guards: syllabus:read (403), a student or a teacher (403 "Guides are for students and teachers").
// A level is listed whether or not its guide has text (PHP lists by the slug table alone).

internal static class MeGuidesSlice
{
    internal sealed record Level(int Id, string Name);

    internal sealed record Guide([property: JsonPropertyName("slug")] string Slug, [property: JsonPropertyName("name")] string Name);

    internal sealed record Body([property: JsonPropertyName("guides")] IReadOnlyList<Guide> Guides);

    public static IEndpointRouteBuilder MapMeGuides(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/me/guides", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
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

        var levels = await db.Database
            .SqlQuery<Level>($"""select id as "Id", name as "Name" from classes.class_levels where id in (2, 3, 4, 5) order by sort_order, id""")
            .ToListAsync(ct);
        var guides = new List<Guide>();
        foreach (var level in levels)
        {
            if (GuideSlugs.ForLevel(level.Id) is { } slug)
            {
                guides.Add(new Guide(slug, level.Name));
            }
        }

        return Results.Json(new Body(guides));
    }
}
