using Microsoft.AspNetCore.Http;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Identity.Api;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>What <see cref="GuardianChecks.ValidateMemberAsync"/> found (PHP GuardiansModel::validateMemberToken).</summary>
internal enum MemberCheck
{
    Ok,
    Guest,
    NotFound,
    Ambiguous,
}

/// <summary>The member a token names, with the gender text as stored (PHP casts it with (int), so Male is 0).</summary>
internal sealed record CheckedMember(MemberCheck Status, int UserId, string? Gender);

/// <summary>
/// The database half of the guardian rules shared by the staff parent-link slices and the invite acceptance (a helper moves here on its
/// second user). PHP: models/guardians.php validateMemberToken, staffMayAddFor, revokedByChildBlocks, tokenOfUser.
/// </summary>
internal static class GuardianChecks
{
    /// <summary>The most active classes of one student whose rules are asked (a student has a handful).</summary>
    public const int MaxClasses = 200;

    public const string StudentNotFound = "Student not found";

    private const string ManageParents = "parents:manage";

    /// <summary>A token of 0 or less is a guest, none holding it is unknown, two or more is ambiguous (the lookup stops at two).</summary>
    public static async Task<CheckedMember> ValidateMemberAsync(NpgsqlDataSource source, UserDirectory users, long token, CancellationToken ct)
    {
        if (token <= 0)
        {
            return new CheckedMember(MemberCheck.Guest, 0, null);
        }

        if (token > int.MaxValue)
        {
            return new CheckedMember(MemberCheck.NotFound, 0, null);
        }

        var holders = await users.ByTokenAsync((int)token, ct);
        if (holders.Count == 0)
        {
            return new CheckedMember(MemberCheck.NotFound, 0, null);
        }

        if (holders.Count > 1)
        {
            return new CheckedMember(MemberCheck.Ambiguous, 0, null);
        }

        var userId = holders[0].Id;
        var gender = (await source.ListAsync($"select gender from membership.member_profiles where user_id = {userId}", row => row.TextOrNull("gender"), ct)).FirstOrDefault();
        return new CheckedMember(MemberCheck.Ok, userId, gender);
    }

    /// <summary>
    /// PHP staffMayAddFor: the student must exist (the first member holding the token gives the gender); the action's reach covers every
    /// class or the student's gender (a gender of 0 never matches); otherwise the action must be allowed on one of the student's active classes.
    /// </summary>
    public static async Task<bool> StaffMayAddForAsync(NpgsqlDataSource source, Permissions permissions, Caller caller, long childToken, bool direct, CancellationToken ct)
    {
        if (childToken is <= 0 or > int.MaxValue)
        {
            return false;
        }

        var token = (int)childToken;
        var rows = await source.ListAsync(
            $"""
            select p.gender as "Gender" from identity.v_users u
            left join membership.member_profiles p on p.user_id = u.id
            where u.token = {token} order by u.id limit 1
            """,
            row => row.TextOrNull("Gender"),
            ct);
        if (rows.Count == 0)
        {
            return false;
        }

        var action = direct ? "parents:add-direct" : "parents:add";
        var gender = PhpValue.IntOfText(rows[0] ?? string.Empty);
        var reach = await permissions.ReachAsync(caller, action, ct);
        if (reach.All || (gender > 0 && reach.Gender == gender))
        {
            return true;
        }

        var classIds = await source.ListAsync(
            $"""
            select distinct c.id as "Value" from classes.v_enrolments cs
            join classes.v_classes c on c.id = cs.class_id
            where cs.token_no = {token} and cs.status = 'A' and cs.removed_at is null and c.status = 'A'
            limit {MaxClasses}
            """,
            row => row.Int("Value"),
            ct);
        foreach (var classId in classIds)
        {
            if (await permissions.CanAsync(caller, action, AccessTarget.ForClass(classId), ct))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// A parent the child ended returns only through someone who manages parents for the child's gender (PHP revokedByChildBlocks). Read
    /// this before the guardian transaction opens: the permission read takes its own connection, so it cannot run inside it.
    /// </summary>
    public static Task<bool> MayManageParentsAsync(Permissions permissions, Caller actor, string? childGender, CancellationToken ct) =>
        permissions.CanAsync(actor, ManageParents, AccessTarget.ForGender((int)PhpValue.IntOfText(childGender ?? string.Empty)), ct);

    /// <summary>The gender text of a member's profile as stored, null when there is none.</summary>
    public static async Task<string?> GenderOfAsync(NpgsqlDataSource source, int userId, CancellationToken ct) =>
        (await source.ListAsync($"select gender from membership.member_profiles where user_id = {userId}", row => row.TextOrNull("gender"), ct)).FirstOrDefault();

    /// <summary>
    /// True when the child ended this pair (a revoked row whose revoked_by is the child's user) and <paramref name="actorMayManage"/> is false.
    /// One read on the caller's transaction (identity's published view), under the guardian lock; no second connection.
    /// </summary>
    public static async Task<bool> RemovedByChildBlocksAsync(DbTx tx, int parentToken, int childToken, bool actorMayManage, CancellationToken ct)
    {
        if (actorMayManage)
        {
            return false;
        }

        var ended = await tx.ListAsync(
            $"""
            select 1 as "Value" from membership.user_guardians g
            join identity.v_users u on u.id = g.revoked_by
            where g.parent_token = {parentToken} and g.child_token = {childToken} and g.status = 'revoked' and u.token = {childToken}
            limit 1
            """,
            row => row.Int("Value"),
            ct);
        return ended.Count > 0;
    }

    /// <summary>PHP tokenOfUser(): the user's token, 0 when there is no such user.</summary>
    public static async Task<int> TokenOfUserAsync(UserDirectory users, int userId, CancellationToken ct)
    {
        var found = await users.ByIdsAsync([userId], ct);
        return found.Count == 0 ? 0 : found[0].Token;
    }

    /// <summary>
    /// PHP api_require_parent_link_create (routes 2 to 4): null when the caller may act for this child, else the refusal. The checks are
    /// <see cref="ParentLinkRules.Decide"/>'s; a student acting for themselves is not checked for existence, as in PHP.
    /// </summary>
    public static async Task<IResult?> RequireParentLinkAsync(NpgsqlDataSource source, Permissions permissions, Caller caller, long childToken, CancellationToken ct)
    {
        var holdsManage = childToken > 0 && caller.Token == childToken && await permissions.CanAsync(caller, ManageParents, AccessTarget.None, ct);
        var staffMay = childToken > 0 && !holdsManage && await StaffMayAddForAsync(source, permissions, caller, childToken, direct: false, ct);
        var holdsAdd = childToken > 0 && !holdsManage && !staffMay && await permissions.CanAsync(caller, "parents:add", AccessTarget.None, ct);
        return ParentLinkRules.Decide(childToken, caller.Token, holdsManage, staffMay, holdsAdd) switch
        {
            LinkGuard.Allowed => null,
            LinkGuard.Forbidden => Refusals.NotPermitted(),
            _ => Problem.Detail(StatusCodes.Status404NotFound, StudentNotFound),
        };
    }
}
