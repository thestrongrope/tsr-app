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

    internal sealed record Row(
        int Id,
        int LevelId,
        string SubjectName,
        string? Description,
        string LinkType,
        string Url,
        int SortOrder,
        bool IsActive,
        DateTime CreatedAt,
        DateTime? ModifiedAt);

    internal sealed record Item(
        int Id,
        [property: JsonPropertyName("level_id")] int LevelId,
        [property: JsonPropertyName("subject_name")] string SubjectName,
        string? Description,
        [property: JsonPropertyName("link_type")] string LinkType,
        string Url,
        [property: JsonPropertyName("sort_order")] int SortOrder,
        [property: JsonPropertyName("is_active")] bool IsActive,
        [property: JsonPropertyName("created_at")] string CreatedAt,
        [property: JsonPropertyName("modified_at")] string? ModifiedAt);

    internal sealed record Body(
        [property: JsonPropertyName("level_id")] int LevelId,
        [property: JsonPropertyName("level_name")] string LevelName,
        [property: JsonPropertyName("level_code")] string LevelCode,
        IReadOnlyList<Item> Items);

    private const string Naive = "yyyy-MM-dd'T'HH:mm:ss";

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

        var rows = await db.Database
            .SqlQuery<Row>($"""
                select id as "Id", level_id as "LevelId", subject_name as "SubjectName", description as "Description", link_type as "LinkType",
                       url as "Url", coalesce(sort_order, 0) as "SortOrder", is_active <> 0 as "IsActive",
                       created_at at time zone 'UTC' as "CreatedAt", modified_at at time zone 'UTC' as "ModifiedAt"
                from classes.syllabus
                where level_id = {levelId} and is_active = 1 and deleted_at is null
                order by sort_order, subject_name
                """)
            .ToListAsync(ct);
        var items = rows.Select(r => new Item(
            r.Id,
            r.LevelId,
            r.SubjectName,
            string.IsNullOrEmpty(r.Description) ? null : r.Description,
            r.LinkType,
            r.Url,
            r.SortOrder,
            r.IsActive,
            r.CreatedAt.ToString(Naive, System.Globalization.CultureInfo.InvariantCulture),
            r.ModifiedAt?.ToString(Naive, System.Globalization.CultureInfo.InvariantCulture))).ToList();
        return Results.Json(new Body(levels[0].Id, levels[0].Name, levels[0].Code, items));
    }
}
