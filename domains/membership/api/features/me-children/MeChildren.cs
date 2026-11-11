using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.MeChildren;

// Slice: GET /me/children -> the caller's active linked children, each with the active classes they are in. Permission children:read. Contract: spec/api.yaml.
// PHP: routes/children.php route_children_list, GuardiansModel::getChildrenForParent. A guest token (0 or less) has no children. One row per (link, member holding the
// child's token): a shared token repeats the child, as PHP's inner join does. Order: link id. gender is PHP's (int) cast of the stored text, so "Male" is 0 (the
// student cards read it differently). Classes: cs.status A, not removed, class active, ordered by class id, NOT distinct (a duplicate enrolment row repeats).
// first_name and last_name are null when empty-null, "" when empty. At most 200 links and 2000 class rows per answer (over all the children; rows past that are left out).

internal static class MeChildrenSlice
{
    private const int MaxLinks = 200;
    private const int MaxClassRows = 2000;

    internal sealed record ChildRow(int Token, string? Relationship, string? Name, string? FirstName, string? LastName, string? Gender);

    internal sealed record ClassRow(int ChildToken, int ClassId, string? ClassName, string? ClassCode);

    public static IEndpointRouteBuilder MapMeChildren(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/me/children", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, MembershipContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "children:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        if (caller.Token <= 0)
        {
            return Results.Json(Array.Empty<object>());
        }

        var parent = caller.Token;
        var children = await db.Database
            .SqlQuery<ChildRow>($"""
                select ug.child_token as "Token", ug.relationship as "Relationship", p.name as "Name", p.first_name as "FirstName", p.last_name as "LastName", p.gender as "Gender"
                from membership.user_guardians ug
                join identity.v_users u on u.token = ug.child_token
                join membership.member_profiles p on p.user_id = u.id
                where ug.parent_token = {parent} and ug.status = 'active'
                order by ug.id, u.id
                limit {MaxLinks}
                """)
            .ToListAsync(ct);
        var tokens = children.Select(c => c.Token).Distinct().ToList();
        var classes = tokens.Count == 0
            ? []
            : await db.Database
                .SqlQuery<ClassRow>($"""
                    select cs.token_no as "ChildToken", c.id as "ClassId", c.name as "ClassName", c.code as "ClassCode"
                    from classes.v_enrolments cs
                    join classes.v_classes c on c.id = cs.class_id
                    where cs.token_no = any({tokens}) and cs.status = 'A' and cs.removed_at is null and c.status = 'A'
                    order by c.id, cs.id
                    limit {MaxClassRows}
                    """)
                .ToListAsync(ct);
        var byChild = classes.ToLookup(c => c.ChildToken);
        var answer = children.Select(child => new Dictionary<string, object?>
        {
            ["token"] = child.Token,
            ["name"] = child.Name ?? string.Empty,
            ["first_name"] = child.FirstName,
            ["last_name"] = child.LastName,
            ["gender"] = PhpValue.IntOfText(child.Gender ?? string.Empty),
            ["relationship"] = child.Relationship ?? string.Empty,
            ["classes"] = byChild[child.Token].Select(c => new Dictionary<string, object?>
            {
                ["class_id"] = c.ClassId,
                ["class_name"] = c.ClassName ?? string.Empty,
                ["class_code"] = c.ClassCode ?? string.Empty,
                ["status"] = "A",
            }).ToList(),
        }).ToList();
        return Results.Json(answer);
    }
}
