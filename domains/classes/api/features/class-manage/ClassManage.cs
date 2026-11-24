using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassManage;

// Slice: GET /classes/{class_id}/manage -> everything the manage screen needs (domain/ManagePayload.cs). Contract: spec/api.yaml.
// PHP: api/mobile/routes/class_manage.php route_class_manage_get (:335). Guards: active complete class (404), classes:update on the class (403, "manage this class").
// Audit: a privileged caller gets an admin_access_log row through platform's published command (PHP: api_log_admin_action).

internal static class ClassManageSlice
{
    public static IEndpointRouteBuilder MapClassManage(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/manage", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, IConfiguration configuration, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var head = await ClassGuards.FindActiveClassAsync(source, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "classes:update", AccessTarget.ForClass(head.Id), ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to manage this class");
        }

        await ClassGuards.LogAdminAccessAsync(context, permissions, caller, ct);
        return Results.Json(await ManagePayload.BuildAsync(source, permissions, configuration, caller, head.Id, ct), ClassesJson.Answers.Answer);
    }
}
