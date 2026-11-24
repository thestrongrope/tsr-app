using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassTeachers;

// Slice: GET /classes/{class_id}/teachers?q= -> candidates for the class's teacher. Contract: spec/api.yaml.
// PHP: api/mobile/routes/class_manage.php route_class_teachers_search (:346). Guards: active complete class (404), classes:update on the class (403). The pool is domain/TeacherSearch.cs;
// the class's gender decides the teaching rule (a gents class takes gents).

internal static class ClassTeachersSlice
{
    private const int GenderGents = 1;

    public static IEndpointRouteBuilder MapClassTeachers(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/teachers", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
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

        var q = context.Request.Query["q"];
        return await TeacherSearch.RunAsync(source, q.Count == 0 ? null : q[^1], head.Gender == GenderGents, ct);
    }
}
