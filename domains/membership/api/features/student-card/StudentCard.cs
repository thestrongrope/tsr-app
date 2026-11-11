using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.StudentCard;

// Slice: GET /students/{token} -> {token, name, gender, classes[{id, code, level}]}: a member with a live enrolment in an active class, showing only the classes the caller's classes:read reaches. Permission classes:read (403);
// a token of 0 or less, an unknown member, a member in no class or in none the caller reaches is 404 "Person not found" (one answer for all). Carries no contact details. Contract: spec/api.yaml.
// PHP: routes/entity_cards.php route_students_card, EntityAccessModel::studentCardFor and currentClasses. Queries: the member, the member's current classes (one query with the level name from classes.v_classes).
// Copied: gender is CardRules.GenderOf; the classes are in code order and a class with no level has the level "" ; two enrolments in one class list it twice; the token is read as PHP's (int) cast.

internal static class StudentCardSlice
{
    private sealed record MemberRow(string? Name, string? Gender);

    private sealed record ClassRow(int Id, string Code, int? Gender, string? Level);

    internal sealed record ClassItem(int Id, string Code, string Level);

    public static IEndpointRouteBuilder MapStudentCard(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/students/{token}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string token, HttpContext context, MembershipContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "classes:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var value = PhpValue.IntOfText(token);
        if (value is <= 0 or > int.MaxValue)
        {
            return NotFound();
        }

        var member = (await db.Database
            .SqlQuery<MemberRow>($"""
                select p.name::text as "Name", p.gender::text as "Gender" from identity.v_users u
                left join membership.member_profiles p on p.user_id = u.id
                where u.token = {(int)value} order by u.id limit 1
                """)
            .ToListAsync(ct)).FirstOrDefault();
        if (member is null)
        {
            return NotFound();
        }

        var reach = await permissions.ReachAsync(caller, "classes:read", ct);
        var current = await db.Database
            .SqlQuery<ClassRow>($"""
                select c.id as "Id", c.code::text as "Code", c.gender as "Gender", c.level_name::text as "Level"
                from classes.v_enrolments cs
                join classes.v_classes c on c.id = cs.class_id and c.status = 'A'
                where cs.token_no = {(int)value} and cs.removed_at is null
                order by c.code::text collate "C"
                limit 200
                """)
            .ToListAsync(ct);
        var classes = current
            .Where(c => CardRules.Reaches(reach.All, reach.Gender, reach.ClassIds, c.Id, c.Gender))
            .Select(c => new ClassItem(c.Id, c.Code, c.Level ?? string.Empty))
            .ToList();
        if (classes.Count == 0)
        {
            return NotFound();
        }

        return Results.Json(new Dictionary<string, object?>
        {
            ["token"] = value,
            ["name"] = member.Name ?? string.Empty,
            ["gender"] = CardRules.GenderOf(member.Gender),
            ["classes"] = classes,
        });
    }

    private static IResult NotFound() => Problem.Detail(StatusCodes.Status404NotFound, "Person not found");
}
