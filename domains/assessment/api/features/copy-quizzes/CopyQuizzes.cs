using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.CopyQuizzes;

// Slice: GET /mcq/copy/classes/{class_id}/quizzes?topic= -> the quizzes of a class and topic the caller may copy from, newest first, a bare array {id, name, createdAt}. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_copy_quizzes (:566), McqModel getMCQsByClassAndTopic (:80). Order: caller (401), the class active (404 "Class not found"), mcqs:copy on the class (403 "You do not have permission to copy MCQs from this class"),
// topic = trim(?topic) required (422 "topic is required"), then the list. Every quiz of the class with that topic is listed: drafts and deactivated ones too. Only id, name and createdAt leave: no question and no answer.
// Copied quirk, FLAGGED: the topic is matched with SQL LIKE, so % and _ typed by the caller are wildcards ("%" lists the whole class) and the match ignores case. A NUL inside the topic matches nothing (MariaDB cannot store one).
// Deviation: at most 1000 quizzes (PHP: all).

internal static class CopyQuizzesSlice
{
    private const int MaxRows = 1000;

    internal sealed record Item(int Id, string Name, string? CreatedAt);

    private sealed record Row(int Id, string? Name, DateTimeOffset CreatedAt);

    public static IEndpointRouteBuilder MapCopyQuizzes(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/mcq/copy/classes/{class_id}/quizzes", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, AssessmentContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var classId = PhpValue.IntOfText(class_id);
        if (await ManageAccess.ActiveClassAsync(db, classId, ct) is null)
        {
            return ManageAccess.ClassNotFound();
        }

        if (!await ManageAccess.CanAsync(permissions, caller, "mcqs:copy", classId, ct))
        {
            return ManageAccess.CopyNotPermitted();
        }

        var topics = context.Request.Query["topic"];
        var topic = PhpText.Trim(topics.Count == 0 ? string.Empty : topics[^1] ?? string.Empty);
        if (topic.Length == 0)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "topic is required");
        }

        var rows = topic.Contains('\0', StringComparison.Ordinal) ? [] : await ReadAsync(db, classId, topic, ct);
        return Results.Json(rows.Select(r => new Item(r.Id, r.Name ?? string.Empty, QuizAccess.Stamp(r.CreatedAt))).ToList());
    }

    private static async Task<List<Row>> ReadAsync(AssessmentContext db, long classId, string topic, CancellationToken ct) =>
        await db.Database
            .SqlQuery<Row>($"""
                select q.id as "Id", q.name::text as "Name", q.created_at as "CreatedAt"
                from assessment.spot_quizzes q
                where q.class_id = {classId} and q.topic like {topic}::citext
                order by q.created_at desc, q.id desc
                limit {MaxRows}
                """)
            .ToListAsync(ct);
}
