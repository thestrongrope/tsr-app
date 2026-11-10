using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.ChildrenLinkRevoke;

// Slice: DELETE /me/children/{child_token}/link -> 204. A parent ends their own active link to a child. Permission children:link.
// The token in the path is cast like PHP's (int): "abc" is 0. Contract: spec/api.yaml.
// PHP: routes/children.php route_children_link_revoke, GuardiansModel::revokeForPair.

internal static class ChildrenLinkRevokeEndpoint
{
    public const string Permission = "children:link";

    public static IEndpointRouteBuilder MapChildrenLinkRevoke(this IEndpointRouteBuilder routes)
    {
        routes.MapDelete(
            "/me/children/{childToken}/link",
            (HttpContext context, string childToken, ChildrenLinkRevokeHandler handler) =>
                handler.HandleAsync(context.GetCaller(), childToken, context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed class ChildrenLinkRevokeHandler(MembershipContext db, Permissions permissions, TimeProvider clock)
{
    public async Task<IResult> HandleAsync(Caller? caller, string childToken, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, ChildrenLinkRevokeEndpoint.Permission, AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var revoked = await GuardianRevoker.RevokePairAsync(db, caller.Token, PhpValue.IntOfText(childToken), caller.UserId, clock.GetUtcNow(), ct);
        return revoked
            ? Results.NoContent()
            : Problem.Detail(StatusCodes.Status404NotFound, GuardianRules.ActiveLinkNotFound);
    }
}
