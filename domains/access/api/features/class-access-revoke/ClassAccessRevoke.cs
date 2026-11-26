using System.Data.Common;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Npgsql;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.ClassAccessRevoke;

// Slice: POST /admin/class-access/rules/{id}/revoke {reason, version} -> {saved: true} and the refreshed member view. The rule stays, with who removed it, when and why.
// PHP: routes/class_access.php route_class_access_revoke (:297), ClassAccessModel::revoke. Order: sign-in (401), class-access:manage (403), the body (422 Invalid JSON), reason text (422), version required text (422);
// then the model: the reason 1 to 300 characters (422), the rule and its member (404 "Rule not found"), the operator's guards (own access 422; the RULE's gender and the MEMBER's gender both ones the operator manages, 403, so a
// rule of the other gender or of either gender on a member is removed by a super admin only), already removed (409), then one transaction under the member's lock (class 6001): the member read again and the guards again, the
// version (409 member_changed), the update (409 if another request removed it first), and a class admin (role 5) whose last live rule this was returns to role 0 (any other role stays). Event
// access.class_access_rule_revoked (ruleId, token, revokedBy). Stricter than PHP: after the guards, a rule is removed only by the operator who granted it or a super admin (403), and only a super admin changes
// the access of a super admin or a gender admin (also on add: class-access-grant), both repeated inside the lock. A failure before the commit is a 500 "Nothing was changed". Contract: spec/api.yaml.

internal static class ClassAccessRevokeSlice
{
    internal sealed record RuleRevoked(int RuleId, int Token, int RevokedBy);

    private sealed record RuleRow(int Token, int? Gender, int? GrantedBy, DateTimeOffset? RevokedAt);

    private sealed record Revocation(int RuleId, int? RuleGender, int? GrantedBy, string Reason, string Version);

    public static IEndpointRouteBuilder MapClassAccessRevoke(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/class-access/rules/{id}/revoke", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string id, HttpContext context, NpgsqlDataSource source, Permissions permissions, IClassScopes classes, TimeProvider clock, ILoggerFactory loggers, CancellationToken ct)
    {
        var (op, refusal) = await ClassAccessOperator.RequireAsync(context, permissions, ct);
        if (op is null)
        {
            return refusal!;
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var typed = ClassAccessInput.Text(body!, "reason");
        var version = ClassAccessInput.Version(body!);
        var shapeRefusal = typed.Refusal ?? version.Refusal;
        if (shapeRefusal is not null)
        {
            return shapeRefusal.ToResult();
        }

        var logger = loggers.CreateLogger("Tsr.Access.ClassAccess");
        try
        {
            var (failure, token) = await RevokeAsync(source, op, clock, AdminMembers.IdOf(id), typed.Value!, version.Value!, ct);
            return failure is not null
                ? failure.ToResult()
                : await ClassAccessStore.SavedAsync(source, permissions, classes, op, token, logger, ct);
        }
        catch (Exception e) when (e is DbException)
        {
            return ClassAccessStore.NothingChanged(logger, e);
        }
    }

    private static async Task<(Refusal? Failure, int Token)> RevokeAsync(
        NpgsqlDataSource source, ClassAccessOperator op, TimeProvider clock, int ruleId, string rawReason, string version, CancellationToken ct)
    {
        var reason = GrantRules.CheckedReason(rawReason);
        if (reason.Failed)
        {
            return (reason.Refusal, 0);
        }

        var (rule, refusal) = await ReadGuardAsync(source, op, ruleId, ct);
        if (refusal is not null)
        {
            return (refusal, 0);
        }

        var revocation = new Revocation(ruleId, rule!.Gender, rule.GrantedBy, reason.Value!, version);
        return (await WriteAsync(source, op, clock, rule.Token, revocation, ct), rule.Token);
    }

    // The rule, its member and the guards on a short read transaction, ended before the port is called. The guards call Permissions.CanAsync while it is open: that reads
    // only the operator RequireAsync already resolved (a gender target looks no class up), so it opens no second connection; AccessPoolTests fails if that changes.
    private static async Task<(RuleRow? Rule, Refusal? Refusal)> ReadGuardAsync(NpgsqlDataSource source, ClassAccessOperator op, int ruleId, CancellationToken ct)
    {
        await using var read = await source.BeginAsync(ct);
        var rule = ruleId > 0 ? await FindAsync(read, ruleId, ct) : null;
        var found = rule is null ? null : await ClassAccessStore.MemberAsync(read, rule.Token, ct);
        if (rule is null || found is null)
        {
            return (null, new Refusal(StatusCodes.Status404NotFound, "Rule not found"));
        }

        var guard = await GuardAsync(read, op, found.Value.Member, found.Value.RoleId, rule.Gender, rule.GrantedBy, ct);
        if (guard is not null)
        {
            return (null, guard);
        }

        return rule.RevokedAt is not null ? (null, AlreadyRemoved()) : (rule, null);
    }

    private static async Task<RuleRow?> FindAsync(DbTx tx, int ruleId, CancellationToken ct)
    {
        var rows = await tx.ListAsync(
            $"""
            select c.gender as "Gender", c.granted_by as "GrantedBy", c.revoked_at as "RevokedAt", c.token as "Token"
            from access.class_access_rules as c
            where c.id = {ruleId}
            limit 1
            """,
            row => new RuleRow(row.Int("Token"), row.IntOrNull("Gender"), row.IntOrNull("GrantedBy"), row.InstantOrNull("RevokedAt")),
            ct);
        return rows.Count == 0 ? null : rows[0];
    }

    private static async Task<Refusal?> WriteAsync(NpgsqlDataSource source, ClassAccessOperator op, TimeProvider clock, int token, Revocation revocation, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        await MemberLock.TakeAsync(tx, token, ct);
        var locked = await ClassAccessStore.MemberAsync(tx, token, ct);
        if (locked is null)
        {
            return new Refusal(StatusCodes.Status404NotFound, "Member not found");
        }

        var (member, roleId) = locked.Value;
        var guard = await GuardAsync(tx, op, member, roleId, revocation.RuleGender, revocation.GrantedBy, ct);
        if (guard is not null)
        {
            return guard;
        }

        var rules = await ClassAccessStore.LiveRulesAsync(tx, token, ct);
        if (ClassAccessRules.VersionOf(roleId, rules.Select(r => r.Id)) != revocation.Version)
        {
            return ClassAccessMessages.MemberChanged();
        }

        var now = clock.GetUtcNow();
        var operatorId = op.Caller.UserId;
        var changed = await tx.ExecuteAsync(
            $"update access.class_access_rules set revoked_at = {now}, revoked_by = {operatorId}, revoke_reason = {revocation.Reason} where id = {revocation.RuleId} and revoked_at is null",
            ct);
        if (changed != 1)
        {
            return AlreadyRemoved();
        }

        // The last live rule of a class admin: the member goes back to role 0 (no row). Any other role stays.
        await tx.ExecuteAsync(
            $"""
            delete from access.user_roles
            where user_id = {member.UserId} and roleid = {ClassAccessRules.RoleClassAdmin}
              and not exists (select 1 from access.class_access_rules r where r.token = {token} and r.revoked_at is null)
            """,
            ct);
        await Outbox.WriteAsync(tx, "access.class_access_rule_revoked", new RuleRevoked(revocation.RuleId, token, operatorId), AccessJson.Default.RuleRevoked, clock, ct);
        await tx.CommitAsync(ct);
        return null;
    }

    private static async Task<Refusal?> GuardAsync(DbTx tx, ClassAccessOperator op, MemberRow member, int roleId, int? ruleGender, int? grantedBy, CancellationToken ct) =>
        await op.GuardAsync(tx, member, roleId, ruleGender, ct) ?? await op.RevokeGuardAsync(tx, grantedBy, ct);

    private static Refusal AlreadyRemoved() => new(StatusCodes.Status409Conflict, "That access was already removed");
}
