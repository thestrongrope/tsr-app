using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageScores;

// Slice: GET /mcq/manage/{quiz_id}/scores -> every student who answered the quiz with their correct count; {quiz, total, items}. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_scores (:395), McqModel getAllScores (:542). Order: caller (401), quiz found (404 "Quiz not found"), its class active (404 "Class not found"), mcqs:manage on the class (403), then the read.
// Reached only by the class teacher, a current class admin student and a super admin (the check is the same as the answer key's): these are students' names and scores.
// FLAGGED, COPIED FROM PHP: the rows are grouped by the student's NAME, so two members with the same name are one row with their answers added together (PHP's `group by u.name`). `outof` is the number of RESPONSES (not the quiz's question count),
// `correct` the sum of the is_correct flags, `submitted` the latest response time (Y-m-dTH:i:s), newest first. The name is HTML-decoded (api_cast text). A response whose member has no user row is left out (PHP's inner join).
// Names come from membership.v_members. At most 5000 rows (PHP: all).

internal static class ManageScoresSlice
{
    private const int MaxRows = 5000;

    internal sealed record QuizWire(int Id, string Name, string? Topic, string ClassCode);

    internal sealed record Item(string Name, string? Submitted, int Correct, int Outof);

    internal sealed record Body(QuizWire Quiz, int Total, IReadOnlyList<Item> Items);

    private sealed record Row(string Name, DateTimeOffset? Submitted, int Correct, int Outof);

    public static IEndpointRouteBuilder MapManageScores(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/mcq/manage/{quiz_id}/scores", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string quiz_id, HttpContext context, AssessmentContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (quiz, refusal) = await ManageAccess.ResolveQuizAsync(db, PhpValue.IntOfText(quiz_id), ct);
        if (refusal is not null)
        {
            return refusal;
        }

        if (!await ManageAccess.CanAsync(permissions, caller, "mcqs:manage", quiz!.ClassId, ct))
        {
            return ManageAccess.NotPermitted();
        }

        var rows = await db.Database
            .SqlQuery<Row>($"""
                select coalesce(m.name::text, '') as "Name", max(r.created_at) as "Submitted",
                       coalesce(sum(r.is_correct), 0)::int as "Correct", count(*)::int as "Outof"
                from assessment.spot_quiz_responses r
                join membership.v_members m on m.token = r.token
                where r.spot_quiz_id = {quiz.Id}
                group by m.name
                order by max(r.created_at) desc, m.name
                limit {MaxRows}
                """)
            .ToListAsync(ct);
        var items = rows.Select(r => new Item(PhpText.HtmlDecode(r.Name), QuizAccess.Stamp(r.Submitted), r.Correct, r.Outof)).ToList();
        return Results.Json(new Body(new QuizWire(quiz.Id, quiz.Name ?? string.Empty, quiz.Topic, quiz.ClassCode ?? string.Empty), items.Count, items));
    }
}
