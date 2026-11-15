using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.OpenQuizzes;

// Slice: GET /mcq/open -> the quizzes the caller may attempt now, across their classes, newest first, 20 at most. Contract: spec/api.yaml.
// PHP: routes/mcq.php route_mcq_open (:79), McqModel openForStudent. Order: quizzes:take (403); no gender check.
// A quiz is listed when it is published, not deactivated, its class has the caller as a current student (status A, not removed) and the caller has no response to it. The class's own status is not read (PHP joins classes only for its code).
// Exposes per quiz: id, code, name, topic, classCode. The limit is fixed (PHP's default 20; the route cannot change it).

internal static class OpenQuizzesSlice
{
    private const int Limit = 20;

    internal sealed record Item(int Id, string Code, string Name, string? Topic, string ClassCode);

    internal sealed record Body(IReadOnlyList<Item> Items);

    private sealed record Row(int Id, string? Code, string? Name, string? Topic, string? ClassCode);

    public static IEndpointRouteBuilder MapOpenQuizzes(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/mcq/open", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, AssessmentContext db, Permissions permissions, CancellationToken ct)
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

        var token = caller.Token;
        var rows = await db.Database
            .SqlQuery<Row>($"""
                select q.id as "Id", q.code::text as "Code", q.name::text as "Name", q.topic::text as "Topic", c.code as "ClassCode"
                from assessment.spot_quizzes q
                join classes.v_classes c on c.id = q.class_id
                where q.published_at is not null
                  and q.deactivated_at is null
                  and exists (select 1 from classes.v_enrolments cs where cs.class_id = q.class_id and cs.token_no = {token} and cs.status = 'A' and cs.removed_at is null)
                  and not exists (select 1 from assessment.spot_quiz_responses r where r.spot_quiz_id = q.id and r.token = {token})
                order by q.published_at desc, q.id desc
                limit {Limit}
                """)
            .ToListAsync(ct);
        return Results.Json(new Body(rows.Select(r => new Item(r.Id, r.Code ?? string.Empty, r.Name ?? string.Empty, QuizResult.TextOrNull(r.Topic), r.ClassCode ?? string.Empty)).ToList()));
    }
}
