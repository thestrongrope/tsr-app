using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.ParentRevoke;

// Slice: DELETE /me/parents/{parent_token} -> 204. A child removes one of their active parents. Permission parents:manage. The row records
// the child as the one who revoked, which is what later makes a return by invite need an admin (children-link-accept). Contract: spec/api.yaml.
// PHP: routes/children.php route_child_parent_revoke, GuardiansModel::revokeForPair.

internal static class ParentRevokeEndpoint
{
    public const string Permission = "parents:manage";

    public static IEndpointRouteBuilder MapParentRevoke(this IEndpointRouteBuilder routes)
    {
        routes.MapDelete(
            "/me/parents/{parentToken}",
            (HttpContext context, string parentToken, ParentRevokeHandler handler) =>
                handler.HandleAsync(context.GetCaller(), parentToken, context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed class ParentRevokeHandler(NpgsqlDataSource source, Permissions permissions, TimeProvider clock)
{
    public async Task<IResult> HandleAsync(Caller? caller, string parentToken, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, ParentRevokeEndpoint.Permission, AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var revoked = await GuardianRevoker.RevokePairAsync(source, PhpValue.IntOfText(parentToken), caller.Token, caller.UserId, clock.GetUtcNow(), ct);
        return revoked
            ? Results.NoContent()
            : Problem.Detail(StatusCodes.Status404NotFound, GuardianRules.ActiveParentLinkNotFound);
    }
}
