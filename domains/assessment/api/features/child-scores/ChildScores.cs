using System.Globalization;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ChildScores;

// Slice: GET /me/children/{child_token}/classes/{class_id}/scores?start_date&end_date -> a linked child's quiz scores in a class. Contract: spec/api.yaml.
// PHP: routes/children.php route_child_scores (:117), GuardiansModel getChildScores (:939), isActiveGuardian, isChildEnrolled; the figures are McqModel getStudentScoresByClass (domain/ScoreRows.cs, shared with my-scores).
// Order: children-performance:read (403; no gender check on this route), then ONE 404 "Child or class not found" unless the caller has an ACTIVE guardian link to the child (membership's v_guardian_links; a revoked link, a link of another parent
// and a stranger are all 404) AND the child has an enrolment row in the class. Copied quirk: ANY enrolment row counts, a removed one too, and the class's status is not read.
// Body: a bare array, newest attempt first, snake_case: quiz_id, quiz_name, score, total_questions, percentage (a float rounded to ONE place, 0.0 with no questions), attempted_on (the last response's time as `Y-m-d H:i:s`, with a space; empty text when none).

internal static class ChildScoresSlice
{
    internal sealed record Item(
        [property: JsonPropertyName("quiz_id")] int QuizId,
        [property: JsonPropertyName("quiz_name")] string QuizName,
        [property: JsonPropertyName("score")] int Score,
        [property: JsonPropertyName("total_questions")] int TotalQuestions,
        [property: JsonPropertyName("percentage")] PhpFloat Percentage,
        [property: JsonPropertyName("attempted_on")] string AttemptedOn);

    public static IEndpointRouteBuilder MapChildScores(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/me/children/{child_token}/classes/{class_id}/scores", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string child_token, string class_id, HttpContext context, AssessmentContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "children-performance:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var childToken = PhpValue.IntOfText(child_token);
        var classId = PhpValue.IntOfText(class_id);
        if (!await IsActiveGuardianAsync(db, caller.Token, childToken, ct) || !await IsChildEnrolledAsync(db, childToken, classId, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Child or class not found");
        }

        var from = context.Request.Query["start_date"].LastOrDefault();
        var to = context.Request.Query["end_date"].LastOrDefault();
        var rows = await ScoreRows.ForAsync(db, classId, (int)childToken, from, to, ct);
        return Results.Json(rows.Select(ToItem).ToList());
    }

    /// <summary>PHP isActiveGuardian: tokens above zero and an active link from the parent to the child.</summary>
    private static async Task<bool> IsActiveGuardianAsync(AssessmentContext db, int parentToken, long childToken, CancellationToken ct)
    {
        if (parentToken <= 0 || childToken <= 0)
        {
            return false;
        }

        var rows = await db.Database
            .SqlQuery<int>($"""select 1 as "Value" from membership.v_guardian_links where parent_token = {parentToken} and child_token = {childToken} and status = 'active' limit 1""")
            .ToListAsync(ct);
        return rows.Count > 0;
    }

    /// <summary>PHP isChildEnrolled: any enrolment row of the child in the class, removed or not.</summary>
    private static async Task<bool> IsChildEnrolledAsync(AssessmentContext db, long childToken, long classId, CancellationToken ct)
    {
        if (childToken <= 0 || classId <= 0)
        {
            return false;
        }

        var rows = await db.Database
            .SqlQuery<int>($"""select 1 as "Value" from classes.v_enrolments where token_no = {childToken} and class_id = {classId} limit 1""")
            .ToListAsync(ct);
        return rows.Count > 0;
    }

    private static Item ToItem(ScoreRows.Row row)
    {
        var score = row.Score ?? 0;
        var percentage = row.Total > 0 ? PhpFloat.Round(score * 100m / row.Total, 1) : new PhpFloat(0);
        var at = row.AttemptedAt?.UtcDateTime.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture) ?? string.Empty;
        return new Item(row.QuizId, row.QuizName ?? string.Empty, score, row.Total, percentage, at);
    }
}
