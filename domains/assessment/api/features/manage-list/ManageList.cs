using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageList;

// Slice: GET /classes/{class_id}/mcq/manage -> a class's quizzes, drafts and deactivated included, newest first, for a member who may manage them. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_list (:76), McqModel getAllByClassId (:501). Order: caller (401), the class active (404 "Class not found"), mcqs:manage on the class
// (403 "You do not have permission to manage MCQs for this class": the class teacher, a current class admin student, a super admin), then the page.
// page = max(1, (int) page); pageSize = min(50, max(1, (int) pageSize)), default 20. Per quiz the counts are all questions and the DISTINCT members who answered; link only once published.
// A quiz row is read from the table by class id and carries no answer text, so a student can never be shown anything by this route (it is refused before any read).

internal static class ManageListSlice
{
    internal sealed record Item(
        int Id, string Code, string Name, string? Topic, int ClassId, string? CreatedAt, string? PublishedAt, string? DeactivatedAt, int RestrictToClass, int QuestionCount, int SubmittedCount, string? Link);

    internal sealed record Body(int Total, long Page, int PageSize, bool HasNext, IReadOnlyList<Item> Items);

    private sealed record Row(
        int Id, string? Code, string? Name, string? Topic, int ClassId, DateTimeOffset CreatedAt, DateTimeOffset? PublishedAt, DateTimeOffset? DeactivatedAt, int RestrictToClass, int QuestionCount, int SubmittedCount);

    public static IEndpointRouteBuilder MapManageList(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/mcq/manage", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, IConfiguration configuration, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var classId = PhpValue.IntOfText(class_id);
        if (await ManageAccess.ActiveClassAsync(source, classId, ct) is null)
        {
            return ManageAccess.ClassNotFound();
        }

        if (!await ManageAccess.CanAsync(permissions, caller, "mcqs:manage", classId, ct))
        {
            return ManageAccess.NotPermitted();
        }

        var paging = Paging.From(context, maxSize: 50);
        var total = (await source.ListAsync(
            $"""select count(*)::int as "Value" from assessment.spot_quizzes where class_id = {classId}""",
            row => row.Int("Value"),
            ct)).Single();
        var rows = await source.ListAsync(
            $"""
                select q.id as "Id", q.code::text as "Code", q.name::text as "Name", q.topic::text as "Topic", q.class_id as "ClassId", q.created_at as "CreatedAt",
                       q.published_at as "PublishedAt", q.deactivated_at as "DeactivatedAt", q.restrict_to_class::int as "RestrictToClass",
                       (select count(*) from assessment.spot_quiz_questions qq where qq.spot_quiz_id = q.id)::int as "QuestionCount",
                       (select count(distinct r.token) from assessment.spot_quiz_responses r where r.spot_quiz_id = q.id)::int as "SubmittedCount"
                from assessment.spot_quizzes q
                where q.class_id = {classId}
                order by q.id desc
                limit {paging.PageSize} offset {paging.Offset}
                """,
            row => new Row(
                row.Int("Id"), row.TextOrNull("Code"), row.TextOrNull("Name"), row.TextOrNull("Topic"), row.Int("ClassId"), row.Instant("CreatedAt"), row.InstantOrNull("PublishedAt"),
                row.InstantOrNull("DeactivatedAt"), row.Int("RestrictToClass"), row.Int("QuestionCount"), row.Int("SubmittedCount")),
            ct);
        var hasNext = (decimal)(paging.Page - 1) * paging.PageSize + rows.Count < total;
        var items = rows.Select(r => ToItem(r, configuration)).ToList();
        return Results.Json(new Body(total, paging.Page, paging.PageSize, hasNext, items), AssessmentJson.Answers.ManageList);
    }

    private static Item ToItem(Row r, IConfiguration configuration) =>
        new(r.Id, r.Code ?? string.Empty, r.Name ?? string.Empty, QuizResult.TextOrNull(r.Topic), r.ClassId, QuizAccess.Stamp(r.CreatedAt), QuizAccess.Stamp(r.PublishedAt),
            QuizAccess.Stamp(r.DeactivatedAt), r.RestrictToClass, r.QuestionCount, r.SubmittedCount, ManageAccess.Link(configuration, r.Code, r.PublishedAt));
}
