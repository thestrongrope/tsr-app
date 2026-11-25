using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassCreateOptions;

// Slice: GET /classes/create-options -> what the create-class form offers. Contract: spec/api.yaml.
// PHP: api/mobile/routes/class_manage.php route_class_create_options (:564). Guard: classes:create at any scope (403), then genders: each of 1, 2 the caller may create for,
// tags: the live tags by name, timezones: domain/Timezones.cs.

internal static class ClassCreateOptionsSlice
{
    private const int MaxTags = 5000;

    internal sealed record Tag(int Id, string? Name);

    public static IEndpointRouteBuilder MapClassCreateOptions(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/create-options", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "classes:create", AccessTarget.None, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to create a class");
        }

        var genders = new List<int>();
        foreach (var gender in new[] { 1, 2 })
        {
            if (await permissions.CanAsync(caller, "classes:create", AccessTarget.ForGender(gender), ct))
            {
                genders.Add(gender);
            }
        }

        var tags = await source.ListAsync(
            $"""select id as "Id", name as "Name" from classes.tags where deleted_at is null order by name, id limit {MaxTags}""",
            row => new Tag(row.Int("Id"), row.TextOrNull("Name")),
            ct);
        var wire = tags.Select(t => new Dictionary<string, object?> { ["id"] = t.Id, ["name"] = PhpText.HtmlDecode(t.Name ?? string.Empty) }).ToList();
        return Results.Json(new Dictionary<string, object?> { ["genders"] = genders, ["tags"] = wire, ["timezones"] = Timezones.All }, ClassesJson.Answers.Answer);
    }
}
