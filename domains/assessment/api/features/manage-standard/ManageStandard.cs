using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageStandard;

// Slice: GET /classes/{class_id}/mcq/standard -> the standard MCQs a class may copy, grouped by topic then subject, each with its question count and whether the class already has a quiz made from it. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_standard (:608), McqModel getStandardQuizzes (:804). Order: caller (401), the class active (404 "Class not found"), mcqs:manage on the class (403), then the list.
// Which standard MCQs: those of the class's LEVEL and of its language (a class with no language is language 1; language 0 matches none), having at least one question. Ordered by code, then sort order; the groups appear in the order first met
// (so NOT alphabetical by topic), the way PHP's arrays fill. The collation of the order is citext (as the other assessment views), equal to MariaDB's for ASCII codes.
// Copied from PHP and FLAGGED: no standard MCQ or question is filtered by deleted_at (PHP never sets it, the schema has it); `copied` is true for ANY quiz of the class with that mcq_code, a deactivated copy included, and
// questionCount is the question count TIMES the number of such quizzes (PHP counts the rows of a join with the copies, min 1). `class.languageId` is the class's language when the list is not empty (1 when unset), else 1 (PHP's `?? 1`).
// Deviation: at most 5000 standard MCQs. Reads only: no answer key (the standard questions are not selected, only counted).

internal static class ManageStandardSlice
{
    private const int MaxRows = 5000;

    internal sealed record Quiz(int Id, string Code, string Topic, string Subject, string Lesson, string Name, int QuestionCount, bool Copied);

    internal sealed record SubjectGroup(string Subject, IReadOnlyList<Quiz> Quizzes);

    internal sealed record TopicGroup(string Topic, IReadOnlyList<SubjectGroup> Subjects);

    internal sealed record ClassHeader(string Code, int LanguageId);

    internal sealed record Body(ClassHeader Class, IReadOnlyList<TopicGroup> Topics);

    private sealed record Row(int Id, string Code, string Topic, string Subject, string Lesson, string Name, int Count, bool Copied);

    public static IEndpointRouteBuilder MapManageStandard(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/mcq/standard", HandleAsync).RequireMember(createsMember: true);
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
        var target = await ManageAccess.ActiveClassAsync(db, classId, ct);
        if (target is null)
        {
            return ManageAccess.ClassNotFound();
        }

        if (!await ManageAccess.CanAsync(permissions, caller, "mcqs:manage", classId, ct))
        {
            return ManageAccess.NotPermitted();
        }

        var rows = await db.Database
            .SqlQuery<Row>($"""
                select min(m.id) as "Id", m.code::text as "Code", min(m.topic::text) as "Topic", min(m.subject::text) as "Subject", min(m.lesson::text) as "Lesson", min(m.name::text) as "Name",
                       count(q.id)::int as "Count", bool_or(sq.id is not null) as "Copied"
                from assessment.standard_mcqs m
                join assessment.standard_mcq_questions q on q.mcq_code = m.code
                join classes.v_classes c on c.class_level_id = m.level_id and c.id = {classId}
                left join assessment.spot_quizzes sq on sq.class_id = c.id and sq.mcq_code = m.code
                where m.language_id = coalesce(c.language_id, 1)
                group by m.code
                order by m.code, min(m.sort_order)
                limit {MaxRows}
                """)
            .ToListAsync(ct);
        var language = rows.Count > 0 && target.LanguageId > 0 ? target.LanguageId.Value : 1;
        return Results.Json(new Body(new ClassHeader(target.Code, language), Group(rows)));
    }

    private static List<TopicGroup> Group(IReadOnlyList<Row> rows) =>
        rows.GroupBy(r => r.Topic, StringComparer.Ordinal)
            .Select(t => new TopicGroup(
                t.Key,
                t.GroupBy(r => r.Subject, StringComparer.Ordinal)
                    .Select(s => new SubjectGroup(s.Key, s.Select(r => new Quiz(r.Id, r.Code, r.Topic, r.Subject, r.Lesson, r.Name, r.Count, r.Copied)).ToList()))
                    .ToList()))
            .ToList();
}
