using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.ClassAccessMembers;

// Slice: GET /admin/class-access/members?q= -> {members: [{token, name, gender}]}: members by name or token, at most 20, only of the genders the operator may manage
// (a gender admin finds their own gender; a member with no recorded gender is found by nobody; under two characters finds nobody). Contact details are never sent.
// Order as PHP (routes/class_access.php route_class_access_members :206): sign-in (401), class-access:manage in any scope (403), q text of at most 100 characters (422), the search.
// Contract: spec/api.yaml.

internal static class ClassAccessMembersSlice
{
    internal sealed record Found(int Token, object Name, int Gender);

    public static IEndpointRouteBuilder MapClassAccessMembers(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/class-access/members", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, AccessContext db, Permissions permissions, CancellationToken ct)
    {
        var (op, refusal) = await ClassAccessOperator.RequireAsync(context, permissions, ct);
        if (op is null)
        {
            return refusal!;
        }

        var q = ClassAccessInput.Query(context.Request.Query["q"].ToString());
        if (q.Failed)
        {
            return q.Refusal!.ToResult();
        }

        var genders = await op.GendersAsync(ct);
        var members = await AdminMembers.SearchOfGendersAsync(db, q.Value!, genders, ct);
        return Results.Json(new { members = members.Select(m => new Found(m.Token, Cast.Text(m.Name), AdminMembers.GenderOf(m.Gender) ?? 0)).ToList() });
    }
}
