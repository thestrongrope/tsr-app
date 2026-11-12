using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.CopyTopics;

// Slice: GET /mcq/copy/classes/{class_id}/topics -> the distinct topics of a class the caller may copy quizzes from, a bare array of text. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_copy_topics (:548), McqModel getTopics. Order: caller (401), the class active (404 "Class not found"), mcqs:copy on the class (403 "You do not have permission to copy MCQs from this class":
// a super admin, a gender admin for the class's gender, a coordinator for an assigned class; NOT the class teacher or a class admin student), then the topics exactly as manage-topics reads them (ManageAccess.TopicsAsync).

internal static class CopyTopicsSlice
{
    public static IEndpointRouteBuilder MapCopyTopics(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/mcq/copy/classes/{class_id}/topics", HandleAsync).RequireMember(createsMember: true);
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

        return Results.Json(await ManageAccess.TopicsAsync(db, classId, ct));
    }
}
