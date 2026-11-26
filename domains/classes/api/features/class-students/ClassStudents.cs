using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassStudents;

// Slice: GET /classes/{class_id}/students -> the active roster of a class. Contract: spec/api.yaml.
// PHP: api/mobile/routes/class_manage.php route_class_students_list (:279), ClassStudentsModel::getStudents. Guards: active complete class (404), class-students:read on the class (403).
// A caller who may not update the class gets email, mobile and notes as null (PHP's `[null...] + $s`: those three keys come first). joinedOn is the day of the first enrolment row's created_at (UTC).
// The query and the wire form are domain/ClassRoster.cs (the management slices answer with the same students).

internal static class ClassStudentsSlice
{
    public static IEndpointRouteBuilder MapClassStudents(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/students", HandleAsync).RequireMember(createsMember: true);
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

        var target = AccessTarget.ForClass(head.Id);
        if (!await permissions.CanAsync(caller, "class-students:read", target, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to view this class's students");
        }

        var rows = await ClassRoster.ActiveAsync(source, head.Id, ct);
        var withContacts = await permissions.CanAsync(caller, "classes:update", target, ct);
        return Results.Json(new Dictionary<string, object?> { ["students"] = rows.Select(r => ClassRoster.StudentWire(r, withContacts)).ToList() }, ClassesJson.Answers.Answer);
    }
}
