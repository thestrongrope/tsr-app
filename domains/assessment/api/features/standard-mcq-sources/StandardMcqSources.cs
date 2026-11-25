using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.StandardMcqSources;

// Slice: GET /standard-mcqs/sources -> the languages and levels that can be updated (static lists). Contract: spec/api.yaml.
// PHP: routes/standard_mcqs.php route_standard_mcqs_sources (:40), McqModel standardMcqSources. Order: standard-mcqs:update (403). Reads and writes nothing.

internal static class StandardMcqSourcesSlice
{
    internal sealed record Source(int Id, string Name);

    internal sealed record Body(IReadOnlyList<Source> Languages, IReadOnlyList<Source> Levels);

    public static IEndpointRouteBuilder MapStandardMcqSources(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/standard-mcqs/sources", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "standard-mcqs:update", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        return Results.Json(new Body(Numbered(StandardMcqCatalog.Languages), Numbered(StandardMcqCatalog.Levels)), AssessmentJson.Answers.StandardMcqSources);
    }

    private static List<Source> Numbered(IReadOnlyList<string> names) => names.Select((name, index) => new Source(index + 1, name)).ToList();
}
