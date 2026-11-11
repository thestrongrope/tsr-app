using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.MemberParentLinkCancel;

// Slice: DELETE /members/{child_token}/parent-links/{id} -> 204. Cancels an unused invite (status invited; an expired one too, PHP does not check the expiry). Same guard as the
// invite creation. Only the invite's creator, or a caller holding parents:manage for the child's gender (an (int) cast of the stored text, so Male is 0), may; an unknown, used or
// someone else's invite is 404 "Invite not found". The row becomes revoked, by the caller, now. Contract: spec/api.yaml.
// PHP: routes/children.php route_member_parent_link_cancel, GuardiansModel::cancelInvite. Event membership.parent_invite_cancelled (inviteId, childToken, cancelledBy).

internal static class MemberParentLinkCancelSlice
{
    internal sealed record InviteCancelled(int InviteId, int ChildToken, int CancelledBy);

    private sealed record InviteRow(int CreatedBy, string? ChildGender);

    public static IEndpointRouteBuilder MapMemberParentLinkCancel(this IEndpointRouteBuilder routes)
    {
        routes.MapDelete("/members/{child_token}/parent-links/{id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string child_token,
        string id,
        HttpContext context,
        MembershipContext db,
        Permissions permissions,
        TimeProvider clock,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var childToken = PhpValue.IntOfText(child_token);
        var refusal = await GuardianChecks.RequireParentLinkAsync(db, permissions, caller, childToken, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var linkId = PhpValue.IntOfText(id);
        if (childToken > int.MaxValue || linkId is < 1 or > int.MaxValue || !await MayCancelAsync(db, permissions, caller, (int)linkId, (int)childToken, ct))
        {
            return NotFound();
        }

        var now = clock.GetUtcNow();
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var changed = await db.UserGuardians
            .Where(g => g.Id == (int)linkId && g.Status == "invited")
            .ExecuteUpdateAsync(set => set.SetProperty(g => g.Status, "revoked").SetProperty(g => g.RevokedAt, now).SetProperty(g => g.RevokedBy, caller.UserId), ct);
        if (changed == 0)
        {
            return NotFound();
        }

        await Outbox.WriteAsync(db, "membership.parent_invite_cancelled", new InviteCancelled((int)linkId, (int)childToken, caller.UserId), clock, ct);
        await transaction.CommitAsync(ct);
        return Results.NoContent();
    }

    // The invite must be unused and name this child whose member exists (PHP joins users on the child token; the first holder gives the gender).
    private static async Task<bool> MayCancelAsync(MembershipContext db, Permissions permissions, Caller caller, int linkId, int childToken, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<InviteRow>($"""
                select ug.created_by as "CreatedBy", p.gender as "ChildGender"
                from membership.user_guardians ug
                join identity.v_users cu on cu.token = ug.child_token
                left join membership.member_profiles p on p.user_id = cu.id
                where ug.id = {linkId} and ug.child_token = {childToken} and ug.status = 'invited'
                order by cu.id limit 1
                """)
            .ToListAsync(ct);
        if (rows.Count == 0)
        {
            return false;
        }

        if (rows[0].CreatedBy == caller.UserId)
        {
            return true;
        }

        var gender = (int)PhpValue.IntOfText(rows[0].ChildGender ?? string.Empty);
        return await permissions.CanAsync(caller, "parents:manage", AccessTarget.ForGender(gender), ct);
    }

    private static IResult NotFound() => Problem.Detail(StatusCodes.Status404NotFound, GuardianRules.InviteNotFound);
}
