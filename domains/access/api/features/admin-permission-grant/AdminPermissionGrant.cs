using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.AdminPermissionGrant;

// Slice: POST /admin/permissions/members/{token}/grants {permission, reason} -> the member's refreshed view (as GET /admin/permissions/members/{token}).
// Order as PHP (routes/permission_grants.php route_admin_permission_grant :88, PermissionGrantsModel::grant): sign-in (401), permissions:manage (403), the body (422 Invalid JSON),
// permission a non-empty string (422 "permission is required"), reason text (422), the reason 1 to 300 characters (422), the member (404), the permission grantable (409 held, 422 not grantable:
// only scope `all`, never permissions:manage:all, class-access:manage:all or members:enrol-by-token:all), then in one transaction the live-grant check (409) and the insert. The operator is
// the session's user, recorded as granted_by. Event access.permission_granted (grantId, token, permission, grantedBy). Contract: spec/api.yaml.
// Stricter than PHP: the member's lock (class 6001) is taken first, so two grants at once cannot both insert. Also stricter than PHP: a grant to the operator themself is 422 "You cannot grant a permission to yourself", after the member is found and before any write.

internal static class AdminPermissionGrantSlice
{
    internal sealed record PermissionGranted(int GrantId, int Token, string Permission, int GrantedBy);

    public static IEndpointRouteBuilder MapAdminPermissionGrant(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/permissions/members/{token}/grants", HandleAsync).RequireMember(createsMember: true).AnswersUnavailable();
        return routes;
    }

    private static async Task<IResult> HandleAsync(string token, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
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

        var permissionField = body!.Get("permission");
        var permission = permissionField.ValueKind == System.Text.Json.JsonValueKind.String ? permissionField.GetString() ?? string.Empty : string.Empty;
        if (permission.Length == 0)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "permission is required");
        }

        var typed = PermissionGrants.TextField(body, "reason");
        var reason = typed.Failed ? typed : GrantRules.CheckedReason(typed.Value!);
        if (reason.Failed)
        {
            return reason.Refusal!.ToResult();
        }

        MemberRow? member;
        await using (var read = await source.BeginAsync(ct))
        {
            member = await AdminMembers.FindAsync(read, AdminMembers.TokenOf(token), ct);
        }

        if (member is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Member not found");
        }

        if (member.Token == context.GetCaller()!.Token)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "You cannot grant a permission to yourself");
        }

        var (grantable, held) = await PermissionGrants.GrantableAsync(source, permissions, member, ct);
        var notAllowed = GrantRules.RefuseGrant(permission, grantable, held);
        if (notAllowed is not null)
        {
            return notAllowed.ToResult();
        }

        var conflict = await InsertAsync(source, clock, member, permission, reason.Value!, context.GetCaller()!.UserId, ct);
        if (conflict is not null)
        {
            return conflict.ToResult();
        }

        var view = await PermissionGrants.ViewAsync(source, permissions, member.Token, ct);
        return view is null ? Problem.Detail(StatusCodes.Status404NotFound, "Member not found") : Results.Json(view, AccessJson.Answers.GrantMemberView);
    }

    private static async Task<Refusal?> InsertAsync(NpgsqlDataSource source, TimeProvider clock, MemberRow member, string permission, string reason, int operatorId, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        await MemberLock.TakeAsync(tx, member.Token, ct);
        var live = await tx.ScalarAsync<int>(
            $"select 1 from access.user_permissions where user_id = {member.UserId} and permission = {permission}::citext and revoked_at is null limit 1",
            ct);
        if (live is not null)
        {
            return new Refusal(StatusCodes.Status409Conflict, "The member already holds that permission");
        }

        var grantedAt = clock.GetUtcNow();
        var grantId = await tx.ScalarAsync<int>(
            $"insert into access.user_permissions (user_id, permission, granted_by, granted_at, reason) values ({member.UserId}, {permission}, {operatorId}, {grantedAt}, {reason}) returning id",
            ct);
        await Outbox.WriteAsync(tx, "access.permission_granted", new PermissionGranted(grantId!.Value, member.Token, permission, operatorId), AccessJson.Default.PermissionGranted, clock, ct);
        await tx.CommitAsync(ct);
        return null;
    }
}
