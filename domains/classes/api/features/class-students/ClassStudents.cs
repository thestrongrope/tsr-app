using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using System.Globalization;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassStudents;

// Slice: GET /classes/{class_id}/students -> the active roster of a class. Contract: spec/api.yaml.
// PHP: api/mobile/routes/class_manage.php route_class_students_list (:279), ClassStudentsModel::getStudents. Guards: active complete class (404), class-students:read on the class (403).
// A caller who may not update the class gets email, mobile and notes as null (PHP's `[null...] + $s`: those three keys come first). joinedOn is the day of the first enrolment row's created_at (UTC).

internal static class ClassStudentsSlice
{
    private const int MaxRows = 5000;

    internal sealed record Row(int Token, string? Name, string? Email, string? Mobile, DateOnly? JoinedOn, string? Notes, bool McqAdmin);

    public static IEndpointRouteBuilder MapClassStudents(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/students", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var head = await ClassGuards.FindActiveClassAsync(db, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        var target = AccessTarget.ForClass(head.Id);
        if (!await permissions.CanAsync(caller, "class-students:read", target, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to view this class's students");
        }

        var rows = await db.Database
            .SqlQuery<Row>($"""
                select m.token as "Token", m.name as "Name", u.email as "Email", m.mobile as "Mobile",
                       (min(cs.created_at) at time zone 'UTC')::date as "JoinedOn", max(cs.notes::text) as "Notes",
                       max(coalesce(cs.mcq_admin, 0)) > 0 as "McqAdmin"
                from classes.class_students cs
                join membership.v_members m on m.token = cs.token_no
                join identity.v_users u on u.id = m.user_id
                where cs.removed_at is null and cs.status = 'A' and cs.class_id = {head.Id}
                group by m.user_id, m.name, m.token, u.email, m.mobile
                order by m.name, m.token
                limit {MaxRows}
                """)
            .ToListAsync(ct);

        var withContacts = await permissions.CanAsync(caller, "classes:update", target, ct);
        return Results.Json(new Dictionary<string, object?> { ["students"] = rows.Select(r => ToWire(r, withContacts)).ToList() });
    }

    private static Dictionary<string, object?> ToWire(Row r, bool withContacts)
    {
        var wire = new Dictionary<string, object?>();
        if (!withContacts)
        {
            wire["email"] = null;
            wire["mobile"] = null;
            wire["notes"] = null;
        }

        wire["token"] = r.Token;
        wire["name"] = PhpText.HtmlDecode(r.Name ?? string.Empty);
        wire["email"] = withContacts ? NullIfEmpty(r.Email) : null;
        wire["mobile"] = withContacts ? NullIfEmpty(r.Mobile) : null;
        wire["joinedOn"] = r.JoinedOn?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        wire["notes"] = withContacts && !string.IsNullOrEmpty(r.Notes) ? PhpText.HtmlDecode(r.Notes) : null;
        wire["mcqAdmin"] = r.McqAdmin;
        return wire;
    }

    // api_cast: a nullable text turns '' into null.
    private static string? NullIfEmpty(string? value) => string.IsNullOrEmpty(value) ? null : value;
}
