using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.ClassAccessMember;

// Slice: GET /admin/class-access/members/{token} -> {member, version, fromRole, rules}: the member's live rules, each with the classes it reaches (at most 200, with the count), and the version a write echoes back.
// Order as PHP (routes/class_access.php route_class_access_member :218, ClassAccessModel::forMember): sign-in (401), class-access:manage (403), the member (404 unknown or token 0),
// the member's gender one the operator manages (403 "This member belongs to the other gender", also for a member with no recorded gender). The rules listed are those whose gender the operator manages: a gender admin
// never sees a rule of either gender, but the version covers every live rule. The classes come from the same matcher the engine uses (RuleMatcher over the port IClassScopes). Contract: spec/api.yaml.

internal static class ClassAccessMemberSlice
{
    public static IEndpointRouteBuilder MapClassAccessMember(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/class-access/members/{token}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string token, HttpContext context, AccessContext db, Permissions permissions, IClassScopes classes, CancellationToken ct)
    {
        var (op, refusal) = await ClassAccessOperator.RequireAsync(context, permissions, ct);
        if (op is null)
        {
            return refusal!;
        }

        var view = await ClassAccessStore.MemberViewAsync(db, permissions, classes, op, AdminMembers.TokenOf(token), ct);
        return view.Failed ? view.Refusal!.ToResult() : Results.Json(view.Value, AccessJson.Answers.ClassAccessView);
    }
}
