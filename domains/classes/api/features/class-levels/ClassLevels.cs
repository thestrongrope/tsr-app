using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassLevels;

// Slice: GET /class-levels -> the class levels in display order. Any signed-in member (no permission, as PHP). Contract: spec/api.yaml.
// PHP: routes/classes.php route_class_levels (classes.php:159). This file is the slice template (domains/CLAUDE.md, "Anatomy"):
// route, guard chain, SQL and response record in one static class; no handler class.

internal static class ClassLevelsSlice
{
    internal sealed record Level(int Id, string Code, string Name);

    public static IEndpointRouteBuilder MapClassLevels(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/class-levels", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, CancellationToken ct)
    {
        if (context.GetCaller() is null)
        {
            return Problem.Unauthenticated();
        }

        var levels = await source.ListAsync(
            $"""select id as "Id", code as "Code", name as "Name" from classes.class_levels order by sort_order, id""",
            row => new Level(row.Int("Id"), row.Text("Code"), row.Text("Name")),
            ct);
        return Results.Json(levels, ClassesJson.Answers.ClassLevelList);
    }
}
