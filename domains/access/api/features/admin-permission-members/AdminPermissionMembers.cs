using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.AdminPermissionMembers;

// Slice: GET /admin/permissions/members?q= -> {members: [{token, name}]}: members by name, token, email or mobile (at most 20; under two characters finds nobody; name and token only come back).
// Order as PHP (routes/permission_grants.php route_admin_permission_members :71): sign-in (401), permissions:manage (403 "Only super admins can manage permissions"), then the search.
// A q with a NUL byte is a 422 (PostgreSQL cannot compare it; PHP just finds nobody). Contract: spec/api.yaml.

internal static class AdminPermissionMembersSlice
{
    internal sealed record Found(int Token, object Name);

    internal sealed record GrantMembersAnswer(IReadOnlyList<Found> Members);

    public static IEndpointRouteBuilder MapAdminPermissionMembers(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/permissions/members", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var refusal = await PermissionGrants.GuardAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        string q = AdminMembers.LastQuery(context.Request.Query);
        if (q.Contains('\0', StringComparison.Ordinal))
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "q must be text");
        }

        var members = await AdminMembers.SearchForGrantsAsync(source, q, ct);
        return Results.Json(new GrantMembersAnswer(members.Select(m => new Found(m.Token, Cast.Text(m.Name))).ToList()), AccessJson.Answers.GrantMembersAnswer);
    }
}
