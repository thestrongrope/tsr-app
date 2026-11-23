using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Search.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Search.Api.Features.Search;

// Slice: GET /search?q=&kinds= -> up to 50 results per kind (class, teacher, guide, student, subscriber) the caller may see, and the kinds that could not be searched. Contract: spec/api.yaml.
// PHP: routes/search.php route_search (search.php:29), models/search.php SearchModel::search. Guards in PHP's order: sign-in with member creation, api_require_identity
// (400 when the stored gender is not numeric), classes:read (403), then q and kinds (422). The caller's reach is a filter in the query (SearchPlans); the pure rules are SearchRequestRules.
// Copied quirks: a kind the caller has no way in to is left out of `groups`; a kind the index cannot answer is in `unavailable`, never an empty group; a limit of 50 per kind sets capped.

internal static class SearchSlice
{
    internal sealed record Body(IReadOnlyList<SearchGroup> Groups, IReadOnlyList<string> Unavailable);

    public static IEndpointRouteBuilder MapSearchRoute(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/search", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, Permissions permissions, ISearchFacts facts, SearchEngine engine, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await facts.HasNumericGenderAsync(caller.UserId, ct))
        {
            return Problem.Detail(StatusCodes.Status400BadRequest, "User gender not set; update profile first");
        }

        if (!await permissions.CanAsync(caller, "classes:read", AccessTarget.None, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to do that");
        }

        var request = SearchRequestRules.Parse(context.Request.Query["q"].LastOrDefault(), context.Request.Query["kinds"].LastOrDefault());
        if (!request.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, request.Error!);
        }

        var wanted = request.Value!;
        var access = await AccessOfAsync(permissions, caller, wanted.Kinds, ct);
        var answer = await engine.SearchAsync(access, wanted.Text, wanted.Kinds, ct);
        return Results.Json(new Body(answer.Groups, answer.Unavailable), SearchJson.Answers.Body);
    }

    // The teacher rule (PHP TeachersModel::canView): the genders the caller may look up outright, and whether gents who actually teach are visible through the teacher-gender rule (a ladies-class manager).
    private static async Task<SearchAccess> AccessOfAsync(Permissions permissions, Caller caller, IReadOnlyList<string> kinds, CancellationToken ct)
    {
        var classes = await permissions.ReachAsync(caller, "classes:read", ct);
        if (!kinds.Contains(SearchPlans.TeacherKind))
        {
            return new SearchAccess(classes, new SearchReach(false, null, [], null), []);
        }

        var teachers = (await permissions.ReachAsync(caller, "teachers:lookup", ct)).Search;
        var genders = new List<int>();
        if (await permissions.CanAsync(caller, "teachers:lookup", AccessTarget.ForGender(1), ct))
        {
            genders.Add(1);
        }

        if (await permissions.CanAsync(caller, "teachers:lookup", AccessTarget.ForGender(2), ct))
        {
            genders.Add(2);
        }

        var gentsWhoTeach = await permissions.CanAsync(caller, "teachers:lookup", AccessTarget.ForTeacherGender(1), ct);
        return new SearchAccess(classes, teachers, genders, gentsWhoTeach);
    }
}
