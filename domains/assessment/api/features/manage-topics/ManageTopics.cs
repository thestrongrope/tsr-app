using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageTopics;

// Slice: GET /classes/{class_id}/mcq/topics -> the distinct topics the class's quizzes use, as a bare array of text. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_topics (:586), McqModel getTopics (:215). Order: caller (401), the class active (404 "Class not found"), mcqs:manage on the class (403, as manage-list).
// PHP selects DISTINCT topic (a PAD SPACE collation: "A" and "A " are one), orders by it, THEN trims each and drops the blank ones. Here the trailing-space merge is done in SQL, the trim in code (ManageAccess.Topics), and the list is capped at 5000.
// Order is the citext order of the database (the same collation the other assessment views use), which equals MariaDB's for ASCII topics; a topic that differs only by case is one topic (either spelling may be shown, as PHP).

internal static class ManageTopicsSlice
{
    public static IEndpointRouteBuilder MapManageTopics(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/mcq/topics", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
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

        return Results.Json(await ManageAccess.TopicsAsync(source, classId, ct), AssessmentJson.Answers.TextList);
    }
}
