using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.ClassAccessOptions;

// Slice: GET /admin/class-access/options -> {genders, levels, cities, countries, tags}: what a rule can be built from. The genders are those the operator manages; the cities, countries and tags are those of the active
// classes of those genders (sorted, one spelling each, at most 500), so a gender admin is offered nothing about the other gender's classes; the levels are all of them (as PHP).
// Order as PHP (routes/class_access.php route_class_access_options :229): sign-in (401), class-access:manage (403). Contract: spec/api.yaml.

internal static class ClassAccessOptionsSlice
{
    internal sealed record GenderOption(int Id, string Name);

    internal sealed record ClassAccessOptionsAnswer(
        IReadOnlyList<GenderOption> Genders,
        IReadOnlyList<LevelBody> Levels,
        IReadOnlyList<string> Cities,
        IReadOnlyList<string> Countries,
        IReadOnlyList<string> Tags);

    public static IEndpointRouteBuilder MapClassAccessOptions(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/class-access/options", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, AccessContext db, Permissions permissions, IClassScopes classes, CancellationToken ct)
    {
        var (op, refusal) = await ClassAccessOperator.RequireAsync(context, permissions, ct);
        if (op is null)
        {
            return refusal!;
        }

        var genders = await op.GendersAsync(ct);
        var levels = await ClassAccessStore.LevelsAsync(db, ct);
        var active = await classes.ActiveClassesAsync(ct);
        return Results.Json(new ClassAccessOptionsAnswer(
            genders.Select(g => new GenderOption(g, ClassAccessRules.GenderLabel(g))).ToList(),
            levels,
            ClassAccessRules.Cities(active, genders),
            ClassAccessRules.Countries(active, genders),
            ClassAccessRules.Tags(active, genders)), AccessJson.Answers.ClassAccessOptionsAnswer);
    }
}
