using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.QuizByCode;

// Slice: GET /mcq/by-code/{code} -> what opening an MCQ link does for the caller: {state, quizId}. Contract: spec/api.yaml.
// PHP: routes/mcq.php route_mcq_by_code (:67), McqModel resolveLink and getByCode. Order: quizzes:take (403); NO gender check (a member without gender gets an answer); then the state machine (domain/QuizRules.Resolve, unit tested).
// States: not_found (not 1 to 32 ASCII letters and digits, or no such code; the code is matched ignoring case, as MariaDB did), not_eligible (not a current student of the quiz's class: nothing else is said), not_released (a draft),
// attempted (the caller has answers, even if deactivated now), open, closed (deactivated, not answered). quizId only for open and attempted. Exposes no question, answer or name.

internal static class QuizByCodeSlice
{
    internal sealed record Body(string State, int? QuizId);

    private sealed record Facts(int QuizId, bool Published, bool Deactivated, bool Enrolled, bool Attempted);

    public static IEndpointRouteBuilder MapQuizByCode(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/mcq/by-code/{code}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string code, HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "quizzes:take", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var facts = QuizRules.IsLinkCode(code) ? await FindAsync(source, code, caller.Token, ct) : null;
        var state = QuizRules.Resolve(
            facts is null ? null : new QuizRules.LinkFacts(facts.QuizId, facts.Published, facts.Deactivated), facts?.Enrolled ?? false, facts?.Attempted ?? false);
        return Results.Json(new Body(state.State, state.QuizId), AssessmentJson.Answers.QuizByCode);
    }

    private static async Task<Facts?> FindAsync(NpgsqlDataSource source, string code, int token, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"""
                select q.id as "QuizId", q.published_at is not null as "Published", q.deactivated_at is not null as "Deactivated",
                       exists (select 1 from classes.v_enrolments cs where cs.class_id = q.class_id and cs.token_no = {token} and cs.status = 'A' and cs.removed_at is null) as "Enrolled",
                       exists (select 1 from assessment.spot_quiz_responses r where r.spot_quiz_id = q.id and r.token = {token}) as "Attempted"
                from assessment.spot_quizzes q
                where q.code = {code}::citext
                order by q.id
                limit 1
                """,
            row => new Facts(row.Int("QuizId"), row.Bool("Published"), row.Bool("Deactivated"), row.Bool("Enrolled"), row.Bool("Attempted")),
            ct);
        return rows.Count == 0 ? null : rows[0];
    }
}
