using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Domain;

/// <summary>
/// The member working the class access screens, and what they may do there (PHP ClassAccessModel::mayManage and guardOperator): gender is a scope of
/// <c>class-access:manage</c>. A super admin holds <c>all</c> (both genders); a gender admin holds their own gender only. The operator is the
/// signed-in caller, never a value from the request.
/// </summary>
internal sealed class ClassAccessOperator(Permissions permissions, Caller caller)
{
    public const string Action = "class-access:manage";
    public const string OtherGender = "This member belongs to the other gender";
    public const string Denied = "You do not have permission to do that";

    public Caller Caller { get; } = caller;

    /// <summary>The guard every class access route shares: signed in (401), then <c>class-access:manage</c> in any scope (403). The operator, or the refusal.</summary>
    public static async Task<(ClassAccessOperator? Operator, IResult? Refusal)> RequireAsync(HttpContext context, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return (null, Problem.Unauthenticated());
        }

        if (!await permissions.CanAsync(caller, Action, AccessTarget.None, ct))
        {
            return (null, Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to do that"));
        }

        return (new ClassAccessOperator(permissions, caller), null);
    }

    public Task<bool> MayManageAsync(int gender, CancellationToken ct) =>
        permissions.CanAsync(Caller, Action, AccessTarget.ForGender(gender), ct);

    /// <summary>The genders this operator may manage (the options the add sheet offers).</summary>
    public async Task<IReadOnlyList<int>> GendersAsync(CancellationToken ct)
    {
        var genders = new List<int>();
        foreach (var gender in ClassAccessRules.Genders)
        {
            if (await MayManageAsync(gender, ct))
            {
                genders.Add(gender);
            }
        }

        return genders;
    }

    /// <summary>A rule of either gender (null) needs both genders.</summary>
    public async Task<bool> MayManageRuleAsync(int? ruleGender, CancellationToken ct)
    {
        if (ruleGender is int only)
        {
            return await MayManageAsync(only, ct);
        }

        foreach (var gender in ClassAccessRules.Genders)
        {
            if (!await MayManageAsync(gender, ct))
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// May the operator change this member's access with a rule of <paramref name="ruleGender"/>? Never their own (422); the rule's gender and the member's
    /// gender must both be ones the operator manages (403), so a gender admin always has them equal. Null when allowed.
    /// </summary>
    public async Task<Refusal?> GuardAsync(DbTx tx, MemberRow member, int memberRoleId, int? ruleGender, CancellationToken ct)
    {
        if (Caller.Token != 0 && Caller.Token == member.Token)
        {
            return new Refusal(422, "You cannot change your own access");
        }

        if (!await MayManageRuleAsync(ruleGender, ct))
        {
            return new Refusal(403, OtherGender);
        }

        var memberGender = AdminMembers.GenderOf(member.Gender);
        if (memberGender is not int g || !await MayManageAsync(g, ct))
        {
            return new Refusal(403, OtherGender);
        }

        // Stricter than PHP: only a super admin changes the access of a super admin or a gender admin.
        var protectedMember = memberRoleId is ClassAccessRules.RoleSuperAdmin or ClassAccessRules.RoleGentsAdmin or ClassAccessRules.RoleLadiesAdmin;
        return protectedMember && !await IsSuperAdminAsync(tx, ct) ? new Refusal(403, Denied) : null;
    }

    /// <summary>Stricter than PHP: a rule is removed by the operator who granted it or by a super admin (403 otherwise). Null when allowed.</summary>
    public async Task<Refusal?> RevokeGuardAsync(DbTx tx, int? grantedBy, CancellationToken ct) =>
        grantedBy == Caller.UserId || await IsSuperAdminAsync(tx, ct) ? null : new Refusal(403, Denied);

    // Read on the caller's transaction, never on a second connection of the data source (no path holds two).
    private async Task<bool> IsSuperAdminAsync(DbTx tx, CancellationToken ct) =>
        await ClassAccessStore.RoleOfAsync(tx, Caller.UserId, ct) == ClassAccessRules.RoleSuperAdmin;
}
