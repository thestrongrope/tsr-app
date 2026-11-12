using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.AdminPermissionRevoke;

// Slice: POST /admin/permissions/grants/{id}/revoke {reason} -> the member's refreshed view. The row stays, with who revoked it, when and why.
// Order as PHP (routes/permission_grants.php route_admin_permission_revoke :108, PermissionGrantsModel::revoke): sign-in (401), permissions:manage (403), the body (422 Invalid JSON), reason text (422),
// the reason 1 to 300 characters (422), the grant (404 "Grant not found"), already revoked (409), the update (409 if another request revoked it first). Event access.permission_revoked (grantId, token, permission, revokedBy).
// PHP quirk kept: the view is read by the member's token afterwards, so a grant of a user with token 0 is revoked and then answers 404 "Member not found". Contract: spec/api.yaml.

internal static class AdminPermissionRevokeSlice
{
    internal sealed record PermissionRevoked(int GrantId, int Token, string Permission, int RevokedBy);

    private sealed record GrantRow(int UserId, int Token, string Permission, DateTimeOffset? RevokedAt);

    public static IEndpointRouteBuilder MapAdminPermissionRevoke(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/permissions/grants/{id}/revoke", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string id, HttpContext context, AccessContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var refusal = await PermissionGrants.GuardAsync(context, permissions, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var typed = PermissionGrants.TextField(body!, "reason");
        var reason = typed.Failed ? typed : GrantRules.CheckedReason(typed.Value!);
        if (reason.Failed)
        {
            return reason.Refusal!.ToResult();
        }

        var grantId = AdminMembers.IdOf(id);
        var grant = await FindAsync(db, grantId, ct);
        if (grant is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Grant not found");
        }

        if (grant.RevokedAt is not null)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "That grant is already revoked");
        }

        var operatorId = context.GetCaller()!.UserId;
        if (!await RevokeAsync(db, clock, grantId, grant, reason.Value!, operatorId, ct))
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "That grant is already revoked");
        }

        var view = await PermissionGrants.ViewAsync(db, permissions, grant.Token, ct);
        return view is null ? Problem.Detail(StatusCodes.Status404NotFound, "Member not found") : Results.Json(view);
    }

    private static async Task<GrantRow?> FindAsync(AccessContext db, int grantId, CancellationToken ct)
    {
        if (grantId <= 0)
        {
            return null;
        }

        var rows = await db.Database
            .SqlQuery<GrantRow>($"""
                select g.user_id as "UserId", u.token as "Token", g.permission as "Permission", g.revoked_at as "RevokedAt"
                from access.user_permissions g
                join identity.v_users u on u.id = g.user_id
                where g.id = {grantId}
                limit 1
                """)
            .ToListAsync(ct);
        return rows.Count == 0 ? null : rows[0];
    }

    // False when another request revoked the grant between the read and the update: nothing is written.
    private static async Task<bool> RevokeAsync(AccessContext db, TimeProvider clock, int grantId, GrantRow grant, string reason, int operatorId, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var changed = await db.UserPermissions
            .Where(g => g.Id == grantId && g.RevokedAt == null)
            .ExecuteUpdateAsync(set => set.SetProperty(g => g.RevokedAt, now).SetProperty(g => g.RevokedBy, operatorId).SetProperty(g => g.RevokeReason, reason), ct);
        if (changed == 0)
        {
            return false;
        }

        await Outbox.WriteAsync(db, "access.permission_revoked", new PermissionRevoked(grantId, grant.Token, grant.Permission, operatorId), clock, ct);
        await transaction.CommitAsync(ct);
        return true;
    }
}
