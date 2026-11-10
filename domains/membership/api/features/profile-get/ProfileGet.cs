using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Identity.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.ProfileGet;

// Slice: GET /me -> the member's profile, the 16 fields of the wire contract. Permission profile:read. The one membership route a member
// with a pending account deletion may still call (identity's gate). Contract: spec/api.yaml. PHP: routes/users.php route_me_get.

internal static class ProfileGetEndpoint
{
    public const string Permission = "profile:read";

    public static IEndpointRouteBuilder MapProfileGet(this IEndpointRouteBuilder routes)
    {
        routes.MapGet(
            "/me",
            (HttpContext context, ProfileGetHandler handler) => handler.HandleAsync(context.GetCaller(), context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed class ProfileGetHandler(MembershipContext db, Permissions permissions, UserDirectory users)
{
    public async Task<IResult> HandleAsync(Caller? caller, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, ProfileGetEndpoint.Permission, AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var profile = await db.MemberProfiles.AsNoTracking().Where(p => p.UserId == caller.UserId).FirstOrDefaultAsync(ct);
        return Results.Json(await ProfileAnswer.BuildAsync(caller, profile, users, permissions, ct));
    }
}
