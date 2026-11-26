using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.AdminQuizWinnersGenerate;

// Slice: POST /admin/quiz/winners/generate {kind: daily|grand|mega|mega_student} -> draw winners that have none yet (a winner already drawn stays). Contract: spec/api.yaml.
// PHP: routes/quiz_admin.php route_admin_quiz_winners_generate (:286) -> api_quiz_draw(false). The rules, the order of refusals, the state written and the event are in domain/QuizDrawFlow.cs and domain/QuizDraw.cs.

internal static class AdminQuizWinnersGenerateSlice
{
    public static IEndpointRouteBuilder MapAdminQuizWinnersGenerate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/quiz/winners/generate", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, IQuizRandom random, CancellationToken ct) =>
        QuizDrawFlow.RunAsync(context, source, permissions, clock, random, reset: false, ct);
}
