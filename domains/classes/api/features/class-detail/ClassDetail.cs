using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassDetail;

// Slice: GET /classes/{class_id} -> one class and its schedule. Contract: spec/api.yaml.
// PHP: routes/classes.php route_class_detail (classes.php:223), ClassesModel::getForUser / getForManager. Guards: active class (404), classes:read on the class (403),
// then three ways in: the teacher; a member the classes:read reach covers (a manager: role conducting, attending or managing); any other member needs a numeric gender (400)
// and must attend the class of their gender (else 404). No gender gate for the teacher.
// Deviation: PHP throws (500) when a class lacks its gender, level or teacher row and the caller is not the teacher; here the manager check then simply does not apply.

internal static class ClassDetailSlice
{
    public static IEndpointRouteBuilder MapClassDetail(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string class_id, HttpContext context, ClassesContext db, Permissions permissions, IConfiguration configuration, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var classId = ClassGuards.IdOf(class_id);
        var teachers = await db.Database
            .SqlQuery<int>($"""select coalesce(teacher, 0) as "Value" from classes.classes where id = {classId} and status = 'A' limit 1""")
            .ToListAsync(ct);
        if (teachers.Count == 0)
        {
            return Refusals.ClassNotFound();
        }

        var id = (int)classId;
        if (!await permissions.CanAsync(caller, "classes:read", AccessTarget.ForClass(id), ct))
        {
            return Refusals.NotPermitted();
        }

        var isTeacher = teachers[0] == caller.Token;
        var manager = !isTeacher && await ReachesAsync(db, permissions, caller, id, ct);
        var gated = !isTeacher && !manager;
        var gender = gated ? await ClassGuards.NumericGenderAsync(db, caller, ct) : 0;
        if (gender is null)
        {
            return Refusals.GenderNotSet();
        }

        var rows = await db.Database
            .SqlQuery<ClassCards.Row>($"""
                select c.id as "Id", c.code as "Code", c.name as "Name", c.class_level_id as "Level", cl.name as "LevelName", c.language_id as "Language",
                       c.gender as "Gender", c.status as "Status", c.location as "Location", c.format as "Format", c.started_on as "StartedOn",
                       t.name as "TeacherName", t.mobile as "TeacherMobile",
                       case when c.teacher = {caller.Token} then 'conducting'
                            when {manager} and not exists (select 1 from classes.class_students cs where cs.class_id = c.id and cs.token_no = {caller.Token}
                                                           and cs.status = 'A' and cs.removed_at is null) then 'managing'
                            else 'attending' end as "Role",
                       case when ({isTeacher} or {manager}) and c.link <> '' then c.link::text end as "JoinCode"
                from classes.classes c
                left join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members t on t.token = c.teacher
                where c.id = {id} and c.status = 'A'
                  and (not {gated}
                       or (c.gender = {gender}
                           and exists (select 1 from classes.class_students cs where cs.class_id = c.id and cs.token_no = {caller.Token}
                                       and cs.status = 'A' and cs.removed_at is null)))
                limit 1
                """)
            .ToListAsync(ct);
        if (rows.Count == 0)
        {
            return Refusals.ClassNotFound();
        }

        var slots = await ClassCards.SlotsAsync(db, [id], ct);
        var body = ClassCards.ToCard(rows[0], configuration);
        body["schedules"] = slots[id].Select(ClassCards.ToSchedule).ToList();
        return Results.Json(body);
    }

    // PHP permissions->reaches(managedReach(classes:read), class): all, the reach's gender, or one of its class ids.
    private static async Task<bool> ReachesAsync(ClassesContext db, Permissions permissions, Caller caller, int classId, CancellationToken ct)
    {
        var reach = await permissions.ReachAsync(caller, "classes:read", ct);
        if (reach.All || reach.ClassIds.Contains(classId))
        {
            return true;
        }

        if (reach.Gender is null)
        {
            return false;
        }

        var genders = await db.Database
            .SqlQuery<int>($"""select coalesce(gender, 0) as "Value" from classes.classes where id = {classId} limit 1""")
            .ToListAsync(ct);
        return genders.Count > 0 && genders[0] == reach.Gender;
    }
}
