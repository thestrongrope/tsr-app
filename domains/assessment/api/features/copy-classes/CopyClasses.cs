using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.CopyClasses;

// Slice: GET /mcq/copy/classes -> the classes the caller may copy quizzes from or to, as a bare array {id, code, level, city, teacher}. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_copy_classes (:539), McqModel copyableClasses (:192), ClassesModel getAll (:202). Order: caller (401), mcqs:copy with NO target (403 "You do not have permission to copy MCQs": a teacher or class admin
// student does not hold it, only a super admin, a gender admin or a coordinator), then, for each gender (1 then 2) the caller holds mcqs:copy for, every ACTIVE class of that gender, ordered by gender, level order, id.
// Copied quirk: getAll also narrows the list to the classes the caller reaches through classes:read when that reach is "assigned only" (a coordinator), so a coordinator sees its assigned classes of the genders it may copy for.
// A gender is held when `mcqs:copy` passes for AccessTarget.ForGender (a coordinator holds it for any gender among its assigned classes: access's own copy of PHP's rule). A class whose level is missing is not listed (PHP's inner join).
// Reads class data through classes.v_classes (code, city, level name and order, gender, status) and the teacher's name through membership.v_members. Deviation: at most 5000 classes.

internal static class CopyClassesSlice
{
    private const int MaxRows = 5000;

    internal sealed record Item(int Id, string Code, string Level, string? City, string? Teacher);

    private sealed record Row(int Id, string? Code, string? Level, string? City, string? Teacher);

    public static IEndpointRouteBuilder MapCopyClasses(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/mcq/copy/classes", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, AssessmentContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "mcqs:copy", AccessTarget.None, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to copy MCQs");
        }

        var genders = new List<int>();
        foreach (var gender in new[] { 1, 2 })
        {
            if (await permissions.CanAsync(caller, "mcqs:copy", AccessTarget.ForGender(gender), ct))
            {
                genders.Add(gender);
            }
        }

        var assignedOnly = (await permissions.ReachAsync(caller, "classes:read", ct)).AssignedOnlyIds;
        var rows = genders.Count == 0 || assignedOnly is { Count: 0 } ? [] : await ReadAsync(db, genders, assignedOnly, ct);
        return Results.Json(rows.Select(r => new Item(r.Id, r.Code ?? string.Empty, r.Level ?? string.Empty, QuizResult.TextOrNull(r.City), QuizResult.TextOrNull(r.Teacher))).ToList());
    }

    private static async Task<List<Row>> ReadAsync(AssessmentContext db, IReadOnlyList<int> genders, IReadOnlyList<int>? assignedOnly, CancellationToken ct)
    {
        var ids = assignedOnly?.ToArray();
        return await db.Database
            .SqlQuery<Row>($"""
                select c.id as "Id", c.code::text as "Code", c.level_name::text as "Level", c.city::text as "City", t.name::text as "Teacher"
                from classes.v_classes c
                left join membership.v_members t on t.token = c.teacher
                where c.status = 'A' and c.level_name is not null and c.gender = any({genders.ToArray()})
                  and ({ids}::int[] is null or c.id = any({ids}))
                order by c.gender, c.level_sort_order, c.id
                limit {MaxRows}
                """)
            .ToListAsync(ct);
    }
}
