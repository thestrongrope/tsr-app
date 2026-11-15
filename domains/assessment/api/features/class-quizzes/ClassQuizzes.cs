using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ClassQuizzes;

// Slice: GET /classes/{class_id}/mcq/quizzes?page&pageSize -> a class's published quizzes with the caller's own attempt. Contract: spec/api.yaml.
// PHP: routes/mcq.php route_quiz_list (:153), McqModel listForStudent. Order: quizzes:take ON THE CLASS (403: access's enrolled scope, so a student who left, one whose enrolment is not active, a teacher, a stranger and a closed class's student are all 403, not 404),
// gender (400), a current student of the class (404 "Class not found or not enrolled"), then the page. Published quizzes only, deactivated ones included (a student who answered still sees the score); newest published first.
// Exposes per quiz: id, code, name, topic, classId, publishedAt, questionCount, attempted, and the caller's own score, total (question count) and percent (a float over total) only once attempted; null before. No question, option or answer.

internal static class ClassQuizzesSlice
{
    internal sealed record Item(int Id, string Code, string Name, string? Topic, int ClassId, string? PublishedAt, int QuestionCount, bool Attempted, int? Score, int? Total, PhpFloat? Percent);

    internal sealed record Body(int Total, long Page, int PageSize, bool HasNext, IReadOnlyList<Item> Items);

    private sealed record Row(int Id, string? Code, string? Name, string? Topic, int ClassId, DateTimeOffset? PublishedAt, int QuestionCount, int Answered, int? Score);

    public static IEndpointRouteBuilder MapClassQuizzes(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/mcq/quizzes", HandleAsync).RequireMember(createsMember: true);
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
        var target = AccessTarget.ForClass((int)Math.Clamp(classId, int.MinValue, int.MaxValue));
        if (!await permissions.CanAsync(caller, "quizzes:take", target, ct))
        {
            return Refusals.NotPermitted();
        }

        if (!await QuizAccess.HasNumericGenderAsync(db, caller, ct))
        {
            return Refusals.GenderNotSet();
        }

        if (!await QuizAccess.IsEnrolledStudentAsync(db, classId, caller.Token, ct))
        {
            return Refusals.ClassNotEnrolled();
        }

        var paging = Paging.From(context);
        var total = await db.Database
            .SqlQuery<int>($"""select count(*)::int as "Value" from assessment.spot_quizzes where class_id = {classId} and published_at is not null""")
            .SingleAsync(ct);
        var token = caller.Token;
        var rows = await db.Database
            .SqlQuery<Row>($"""
                select q.id as "Id", q.code::text as "Code", q.name::text as "Name", q.topic::text as "Topic", q.class_id as "ClassId", q.published_at as "PublishedAt",
                       (select count(*) from assessment.spot_quiz_questions qq where qq.spot_quiz_id = q.id)::int as "QuestionCount",
                       (select count(*) from assessment.spot_quiz_responses r where r.spot_quiz_id = q.id and r.token = {token})::int as "Answered",
                       (select sum(r.is_correct) from assessment.spot_quiz_responses r where r.spot_quiz_id = q.id and r.token = {token})::int as "Score"
                from assessment.spot_quizzes q
                where q.class_id = {classId} and q.published_at is not null
                order by q.published_at desc, q.id desc
                limit {paging.PageSize} offset {paging.Offset}
                """)
            .ToListAsync(ct);
        var hasNext = (decimal)(paging.Page - 1) * paging.PageSize + rows.Count < total;
        return Results.Json(new Body(total, paging.Page, paging.PageSize, hasNext, rows.Select(ToItem).ToList()));
    }

    private static Item ToItem(Row row)
    {
        var attempted = row.Answered > 0;
        var scored = attempted && row.QuestionCount > 0;
        var score = row.Score ?? 0;
        return new Item(
            row.Id, row.Code ?? string.Empty, row.Name ?? string.Empty, QuizResult.TextOrNull(row.Topic), row.ClassId, QuizAccess.Stamp(row.PublishedAt),
            row.QuestionCount, attempted, scored ? score : null, scored ? row.QuestionCount : null, scored ? PhpFloat.Round(score * 100m / row.QuestionCount, 2) : null);
    }
}
