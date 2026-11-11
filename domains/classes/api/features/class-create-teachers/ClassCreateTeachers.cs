using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassCreateTeachers;

// Slice: GET /classes/teachers?gender=&q= -> candidates for the teacher of a class not yet created. Contract: spec/api.yaml.
// PHP: api/mobile/routes/class_manage.php route_class_create_teachers (:577). gender is 2 only when the text is exactly "2", else 1 (gents). Guard: classes:create for that gender (403).
// The pool is domain/TeacherSearch.cs.

internal static class ClassCreateTeachersSlice
{
    private const int GenderGents = 1;
    private const int GenderLadies = 2;

    public static IEndpointRouteBuilder MapClassCreateTeachers(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/teachers", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var genders = context.Request.Query["gender"];
        var gender = genders.Count > 0 && genders[^1] == "2" ? GenderLadies : GenderGents;
        if (!await permissions.CanAsync(caller, "classes:create", AccessTarget.ForGender(gender), ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to create a class");
        }

        var q = context.Request.Query["q"];
        return await TeacherSearch.RunAsync(db, q.Count == 0 ? null : q[^1], gender == GenderGents, ct);
    }
}
