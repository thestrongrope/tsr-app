using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.AdminQuizWinnersRegenerate;

// Slice: POST /admin/quiz/winners/regenerate {kind} -> draw again: the winners replaced (the current episode for daily, every started episode for grand, the Mega winner) are first appended to the replaced-winners record. Contract: spec/api.yaml.
// PHP: routes/quiz_admin.php route_admin_quiz_winners_regenerate (:294) -> api_quiz_draw(true). Nothing is replaced when the draw is blocked or draws nobody. Rules and state: domain/QuizDrawFlow.cs and domain/QuizDraw.cs.

internal static class AdminQuizWinnersRegenerateSlice
{
    public static IEndpointRouteBuilder MapAdminQuizWinnersRegenerate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/quiz/winners/regenerate", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static Task<IResult> HandleAsync(HttpContext context, AssessmentContext db, Permissions permissions, TimeProvider clock, IQuizRandom random, CancellationToken ct) =>
        QuizDrawFlow.RunAsync(context, db, permissions, clock, random, reset: true, ct);
}
