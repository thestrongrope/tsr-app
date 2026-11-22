using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
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
        routes.MapPost("/admin/permissions/grants/{id}/revoke", HandleAsync).RequireMember(createsMember: true).AnswersUnavailable();
        return routes;
    }

    private static async Task<IResult> HandleAsync(string id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
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
        var grant = await FindAsync(source, grantId, ct);
        if (grant is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Grant not found");
        }

        if (grant.RevokedAt is not null)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "That grant is already revoked");
        }

        var operatorId = context.GetCaller()!.UserId;
        if (!await RevokeAsync(source, clock, grantId, grant, reason.Value!, operatorId, ct))
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "That grant is already revoked");
        }

        var view = await PermissionGrants.ViewAsync(source, permissions, grant.Token, ct);
        return view is null ? Problem.Detail(StatusCodes.Status404NotFound, "Member not found") : Results.Json(view, AccessJson.Answers.GrantMemberView);
    }

    private static async Task<GrantRow?> FindAsync(NpgsqlDataSource source, int grantId, CancellationToken ct)
    {
        if (grantId <= 0)
        {
            return null;
        }

        var rows = await source.ListAsync(
            $"""
                select g.user_id as "UserId", u.token as "Token", g.permission as "Permission", g.revoked_at as "RevokedAt"
                from access.user_permissions g
                join identity.v_users u on u.id = g.user_id
                where g.id = {grantId}
                limit 1
                """,
            row => new GrantRow(row.Int("UserId"), row.Int("Token"), row.Text("Permission"), row.InstantOrNull("RevokedAt")),
            ct);
        return rows.Count == 0 ? null : rows[0];
    }

    // False when another request revoked the grant between the read and the update: nothing is written.
    private static async Task<bool> RevokeAsync(NpgsqlDataSource source, TimeProvider clock, int grantId, GrantRow grant, string reason, int operatorId, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await using var tx = await source.BeginAsync(ct);
        var changed = await tx.ExecuteAsync(
            $"update access.user_permissions set revoked_at = {now}, revoked_by = {operatorId}, revoke_reason = {reason} where id = {grantId} and revoked_at is null",
            ct);
        if (changed == 0)
        {
            return false;
        }

        await Outbox.WriteAsync(tx, "access.permission_revoked", new PermissionRevoked(grantId, grant.Token, grant.Permission, operatorId), AccessJson.Default.PermissionRevoked, clock, ct);
        await tx.CommitAsync(ct);
        return true;
    }
}
