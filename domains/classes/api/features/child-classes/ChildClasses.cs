using System.Globalization;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ChildClasses;

// Slice: GET /me/children/{child_token}/classes -> every class a linked child is or was enrolled in, as a bare array. Contract: spec/api.yaml.
// PHP: routes/children.php route_child_classes (children.php:39), GuardiansModel::getChildClasses. Guards: children-performance:read (403), active guardian link (404 "Child not found").
// Copied quirks: no status or removed filter (a re-enrolled class appears once per row); the class link is never returned; a missing teacher gives "".

internal static class ChildClassesSlice
{
    internal sealed record Row(int ClassId, string ClassName, string ClassCode, int? Gender, string TeacherName, DateOnly? StartedOn, string EnrolmentStatus);

    internal sealed record Item(
        [property: JsonPropertyName("class_id")] int ClassId,
        [property: JsonPropertyName("class_name")] string ClassName,
        [property: JsonPropertyName("class_code")] string ClassCode,
        [property: JsonPropertyName("gender")] int Gender,
        [property: JsonPropertyName("teacher_name")] string TeacherName,
        [property: JsonPropertyName("started_on")] string StartedOn,
        [property: JsonPropertyName("enrolment_status")] string EnrolmentStatus);

    private const int MaxRows = 1000;

    public static IEndpointRouteBuilder MapChildClasses(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/me/children/{child_token}/classes", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string child_token, HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "children-performance:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var childToken = ClassGuards.IdOf(child_token);
        if (!await ChildGuards.IsActiveGuardianAsync(db, caller.Token, childToken, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Child not found");
        }

        var rows = await db.Database
            .SqlQuery<Row>($"""
                select c.id as "ClassId", c.name as "ClassName", c.code as "ClassCode", c.gender as "Gender",
                       coalesce(tu.name, '') as "TeacherName", c.started_on as "StartedOn", cs.status as "EnrolmentStatus"
                from classes.class_students cs
                join classes.classes c on c.id = cs.class_id
                left join membership.v_members tu on tu.token = c.teacher
                where cs.token_no = {childToken}
                order by c.id
                limit {MaxRows}
                """)
            .ToListAsync(ct);
        return Results.Json(rows.Select(r => new Item(
            r.ClassId,
            r.ClassName,
            r.ClassCode,
            r.Gender ?? 0,
            r.TeacherName,
            r.StartedOn?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) ?? string.Empty,
            r.EnrolmentStatus)).ToList());
    }
}
