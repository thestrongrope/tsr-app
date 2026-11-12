using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.AdminPermissionMember;

// Slice: GET /admin/permissions/members/{token} -> what the member holds from their role and by grant, and what may still be granted. Unknown member or a guest (token 0) is 404 "Member not found".
// Order as PHP (routes/permission_grants.php route_admin_permission_member :80): sign-in (401), permissions:manage (403 "Only super admins can manage permissions"), then the view. Contract: spec/api.yaml.

internal static class AdminPermissionMemberSlice
{
    public static IEndpointRouteBuilder MapAdminPermissionMember(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/permissions/members/{token}", HandleAsync).RequireMember(createsMember: true).AnswersUnavailable();
        return routes;
    }

    private static async Task<IResult> HandleAsync(string token, HttpContext context, AccessContext db, Permissions permissions, CancellationToken ct)
    {
        var refusal = await PermissionGrants.GuardAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var view = await PermissionGrants.ViewAsync(db, permissions, AdminMembers.TokenOf(token), ct);
        return view is null ? Problem.Detail(StatusCodes.Status404NotFound, "Member not found") : Results.Json(view);
    }
}
