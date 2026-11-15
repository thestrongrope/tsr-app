using System.Data.Common;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.ClassAccessGrant;

// Slice: POST /admin/class-access/members/{token}/rules {gender, conditions, reason, version, previewHash} -> {saved: true} and the refreshed member view (as GET /admin/class-access/members/{token}).
// PHP: routes/class_access.php route_class_access_grant (:272), ClassAccessModel::grant. Order: sign-in (401), class-access:manage (403), the body (422 Invalid JSON), gender a whole number (422), conditions a list (422),
// reason text (422), version and previewHash required text (422); then the model: the reason 1 to 300 characters (422), gender 1 or 2 or left out (422), the conditions valid, IN only, levels that exist (422), the member
// (404), the operator's guards (own access 422 "You cannot change your own access"; the rule's gender and the member's gender both ones the operator manages, 403 "This member belongs to the other gender"; stricter than PHP: only a super admin adds a rule to a super admin or a gender admin, 403 "You do not have permission to do that"), each
// city, country and tag one the operator is offered (422). Then one transaction under the member's lock (class 6001; PHP's UPDATE users row lock): the member read again and the guards again, the version the client saw
// (409 member_changed), a Finance member (422), the same access already held (409 already_has_access), the access reaches no class (422), the classes still hash to previewHash (409 preview_changed, with the classes now
// reached), then the rule and its conditions are written, and a member whose role is 0 becomes a class admin (role 5; any other role stays; PHP's UPDATE users SET roleid = 5 where roleid = 0). The operator is recorded as
// granted_by. Event access.class_access_rule_created (ruleId, token, gender, grantedBy). A failure before the commit is a 500 "Nothing was changed". Contract: spec/api.yaml.

internal static class ClassAccessGrantSlice
{
    internal sealed record RuleCreated(int RuleId, int Token, int? Gender, int GrantedBy);

    private sealed record Draft(int? Gender, IReadOnlyList<RuleCondition> Conditions, string Reason, string Version, string PreviewHash);

    public static IEndpointRouteBuilder MapClassAccessGrant(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/class-access/members/{token}/rules", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string token, HttpContext context, AccessContext db, Permissions permissions, IClassScopes classes, TimeProvider clock, ILoggerFactory loggers, CancellationToken ct)
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

        var shape = ReadShape(body!);
        if (shape.Failed)
        {
            return shape.Refusal!.ToResult();
        }

        var logger = loggers.CreateLogger("Tsr.Access.ClassAccess");
        var memberToken = AdminMembers.TokenOf(token);
        try
        {
            var failure = await GrantAsync(db, permissions, classes, op, clock, memberToken, shape.Value!, ct);
            return failure is not null
                ? failure.ToResult()
                : await ClassAccessStore.SavedAsync(db, permissions, classes, op, memberToken, logger, ct);
        }
        catch (Exception e) when (e is DbException or DbUpdateException)
        {
            return ClassAccessStore.NothingChanged(logger, e);
        }
    }

    // The route's own checks, in PHP's order: the shape of each field. The conditions are checked later, by the model.
    private static Outcome<(int? Gender, IReadOnlyList<RawCondition> Raw, string Reason, string Version, string Hash)> ReadShape(JsonBody body)
    {
        var gender = ClassAccessInput.Gender(body);
        var conditions = ClassAccessInput.Conditions(body);
        var reason = ClassAccessInput.Text(body, "reason");
        var version = ClassAccessInput.Version(body);
        var hash = ClassAccessInput.PreviewHash(body);
        var failed = new Refusal?[] { gender.Refusal, conditions.Refusal, reason.Refusal, version.Refusal, hash.Refusal }.FirstOrDefault(r => r is not null);
        return failed is not null
            ? Outcome<(int?, IReadOnlyList<RawCondition>, string, string, string)>.Fail(failed)
            : Outcome<(int?, IReadOnlyList<RawCondition>, string, string, string)>.Ok((gender.Value, conditions.Value!, reason.Value!, version.Value!, hash.Value!));
    }

    private static async Task<Refusal?> GrantAsync(
        AccessContext db,
        Permissions permissions,
        IClassScopes classes,
        ClassAccessOperator op,
        TimeProvider clock,
        int token,
        (int? Gender, IReadOnlyList<RawCondition> Raw, string Reason, string Version, string Hash) input,
        CancellationToken ct)
    {
        var reason = GrantRules.CheckedReason(input.Reason);
        var range = ClassAccessRules.CheckedGender(input.Gender);
        if (reason.Failed || range is not null)
        {
            return reason.Refusal ?? range;
        }

        var conditions = await ClassAccessStore.CheckedConditionsAsync(db, input.Raw, ct);
        if (conditions.Failed)
        {
            return conditions.Refusal;
        }

        var found = await ClassAccessStore.MemberAsync(db, token, ct);
        if (found is null)
        {
            return new Refusal(StatusCodes.Status404NotFound, "Member not found");
        }

        var guard = await op.GuardAsync(found.Value.Member, found.Value.RoleId, input.Gender, ct);
        if (guard is not null)
        {
            return guard;
        }

        var offered = await ClassAccessStore.OfferedConditionsAsync(classes, op, conditions.Value!, ct);
        if (offered.Failed)
        {
            return offered.Refusal;
        }

        var draft = new Draft(input.Gender, offered.Value!, reason.Value!, input.Version, input.Hash);
        return await WriteAsync(db, classes, op, clock, token, draft, ct);
    }

    private static async Task<Refusal?> WriteAsync(AccessContext db, IClassScopes classes, ClassAccessOperator op, TimeProvider clock, int token, Draft draft, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await MemberLock.TakeAsync(db, token, ct);
        var locked = await ClassAccessStore.MemberAsync(db, token, ct);
        if (locked is null)
        {
            return new Refusal(StatusCodes.Status404NotFound, "Member not found");
        }

        var (member, roleId) = locked.Value;
        var guard = await op.GuardAsync(member, roleId, draft.Gender, ct);
        var rules = await ClassAccessStore.LiveRulesAsync(db, token, ct);
        var refused = guard ?? await RefuseAsync(classes, roleId, rules, draft, ct);
        if (refused is not null)
        {
            return refused;
        }

        var ruleId = await InsertAsync(db, clock, member, roleId, draft, op.Caller.UserId, ct);
        await Outbox.WriteAsync(db, "access.class_access_rule_created", new RuleCreated(ruleId, token, draft.Gender, op.Caller.UserId), clock, ct);
        await transaction.CommitAsync(ct);
        return null;
    }

    // guardVersion then guardGrantable: the version (409), Finance (422), the same access held (409), no class reached (422), the classes changed since the preview (409).
    private static async Task<Refusal?> RefuseAsync(IClassScopes classes, int roleId, IReadOnlyList<StoredRule> rules, Draft draft, CancellationToken ct)
    {
        if (ClassAccessRules.VersionOf(roleId, rules.Select(r => r.Id)) != draft.Version)
        {
            return ClassAccessMessages.MemberChanged();
        }

        if (roleId == ClassAccessRules.RoleFinance)
        {
            return new Refusal(422, "A Finance member cannot be made a class admin");
        }

        var key = ClassAccessRules.AccessKey(draft.Gender, draft.Conditions);
        if (rules.Any(r => ClassAccessRules.AccessKey(r.Gender, r.Conditions) == key))
        {
            return Refusal.Coded(409, "This member already has this access", "already_has_access");
        }

        var reached = ClassAccessRules.Reach(draft.Gender, draft.Conditions, await classes.ActiveClassesAsync(ct));
        if (reached.Count == 0)
        {
            return new Refusal(422, "This access reaches no class");
        }

        var hash = ClassAccessRules.PreviewHash(reached.Select(c => c.Id));
        return ClassAccessRules.SameHash(hash, draft.PreviewHash) ? null : ClassAccessMessages.PreviewChanged(reached, hash);
    }

    private static async Task<int> InsertAsync(AccessContext db, TimeProvider clock, MemberRow member, int roleId, Draft draft, int operatorId, CancellationToken ct)
    {
        if (roleId == ClassAccessRules.RoleMember)
        {
            db.UserRoles.Add(new UserRole { UserId = member.UserId, RoleId = ClassAccessRules.RoleClassAdmin });
        }

        var rule = new ClassAccessRule
        {
            Token = member.Token,
            Gender = draft.Gender,
            Note = ClassAccessRules.NoteFor(draft.Gender, draft.Conditions),
            CreatedAt = clock.GetUtcNow(),
            GrantedBy = operatorId,
            Reason = draft.Reason,
        };
        db.ClassAccessRules.Add(rule);
        await db.SaveChangesAsync(ct);

        foreach (var condition in draft.Conditions)
        {
            db.ClassAccessRuleConditions.Add(new ClassAccessRuleCondition
            {
                RuleId = rule.Id,
                Field = condition.Field,
                Negate = false,
                Value = condition.Field == "level" ? null : condition.Value,
                LevelId = condition.Field == "level" ? condition.LevelId : null,
            });
        }

        await db.SaveChangesAsync(ct);
        return rule.Id;
    }
}
