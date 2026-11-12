using System.Data.Common;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
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

    private sealed record Revocation(int RuleId, int? RuleGender, int? GrantedBy, string Reason, string Version);

    public static IEndpointRouteBuilder MapClassAccessRevoke(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/class-access/rules/{id}/revoke", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string id, HttpContext context, AccessContext db, Permissions permissions, IClassScopes classes, TimeProvider clock, ILoggerFactory loggers, CancellationToken ct)
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
            var (failure, token) = await RevokeAsync(db, op, clock, AdminMembers.IdOf(id), typed.Value!, version.Value!, ct);
            return failure is not null
                ? failure.ToResult()
                : await ClassAccessStore.SavedAsync(db, permissions, classes, op, token, logger, ct);
        }
        catch (Exception e) when (e is DbException or DbUpdateException)
        {
            return ClassAccessStore.NothingChanged(logger, e);
        }
    }

    private static async Task<(Refusal? Failure, int Token)> RevokeAsync(
        AccessContext db, ClassAccessOperator op, TimeProvider clock, int ruleId, string rawReason, string version, CancellationToken ct)
    {
        var reason = GrantRules.CheckedReason(rawReason);
        if (reason.Failed)
        {
            return (reason.Refusal, 0);
        }

        var rule = ruleId > 0 ? await db.ClassAccessRules.AsNoTracking().FirstOrDefaultAsync(r => r.Id == ruleId, ct) : null;
        var found = rule is null ? null : await ClassAccessStore.MemberAsync(db, rule.Token, ct);
        if (rule is null || found is null)
        {
            return (new Refusal(StatusCodes.Status404NotFound, "Rule not found"), 0);
        }

        var guard = await GuardAsync(op, found.Value.Member, found.Value.RoleId, rule.Gender, rule.GrantedBy, ct);
        if (guard is not null)
        {
            return (guard, 0);
        }

        if (rule.RevokedAt is not null)
        {
            return (AlreadyRemoved(), 0);
        }

        var revocation = new Revocation(ruleId, rule.Gender, rule.GrantedBy, reason.Value!, version);
        return (await WriteAsync(db, op, clock, rule.Token, revocation, ct), rule.Token);
    }

    private static async Task<Refusal?> WriteAsync(AccessContext db, ClassAccessOperator op, TimeProvider clock, int token, Revocation revocation, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await MemberLock.TakeAsync(db, token, ct);
        var locked = await ClassAccessStore.MemberAsync(db, token, ct);
        if (locked is null)
        {
            return new Refusal(StatusCodes.Status404NotFound, "Member not found");
        }

        var (member, roleId) = locked.Value;
        var guard = await GuardAsync(op, member, roleId, revocation.RuleGender, revocation.GrantedBy, ct);
        if (guard is not null)
        {
            return guard;
        }

        var rules = await ClassAccessStore.LiveRulesAsync(db, token, ct);
        if (ClassAccessRules.VersionOf(roleId, rules.Select(r => r.Id)) != revocation.Version)
        {
            return ClassAccessMessages.MemberChanged();
        }

        var now = clock.GetUtcNow();
        var operatorId = op.Caller.UserId;
        var changed = await db.ClassAccessRules
            .Where(r => r.Id == revocation.RuleId && r.RevokedAt == null)
            .ExecuteUpdateAsync(set => set.SetProperty(r => r.RevokedAt, now).SetProperty(r => r.RevokedBy, operatorId).SetProperty(r => r.RevokeReason, revocation.Reason), ct);
        if (changed != 1)
        {
            return AlreadyRemoved();
        }

        // The last live rule of a class admin: the member goes back to role 0 (no row). Any other role stays.
        await db.Database.ExecuteSqlAsync(
            $"""
            delete from access.user_roles
            where user_id = {member.UserId} and roleid = {ClassAccessRules.RoleClassAdmin}
              and not exists (select 1 from access.class_access_rules r where r.token = {token} and r.revoked_at is null)
            """,
            ct);
        await Outbox.WriteAsync(db, "access.class_access_rule_revoked", new RuleRevoked(revocation.RuleId, token, operatorId), clock, ct);
        await transaction.CommitAsync(ct);
        return null;
    }

    private static async Task<Refusal?> GuardAsync(ClassAccessOperator op, MemberRow member, int roleId, int? ruleGender, int? grantedBy, CancellationToken ct) =>
        await op.GuardAsync(member, roleId, ruleGender, ct) ?? await op.RevokeGuardAsync(grantedBy, ct);

    private static Refusal AlreadyRemoved() => new(StatusCodes.Status409Conflict, "That access was already removed");
}
