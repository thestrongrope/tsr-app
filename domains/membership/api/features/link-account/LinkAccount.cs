using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Identity.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.LinkAccount;

// Slice: POST /auth/link, the app's first call after Firebase sign-in. identity's middleware has already verified the token and created
// or found the member (a create route); this answers {"me": <profile>}, the same sixteen fields as GET /me, which the app reads at once.
// It lives here, not in identity, because the profile is membership's. No permission is checked, as in PHP (routes/auth.php route_auth_link).
// Contract: domains/identity/spec/tests/link-account.hurl (the sign-in cases) and db/tests/ProfileTests.cs (me equals GET /me).

internal static class LinkAccountEndpoint
{
    public static IEndpointRouteBuilder MapLinkAccount(this IEndpointRouteBuilder routes)
    {
        routes.MapPost(
            "/auth/link",
            async (HttpContext context, MembershipContext db, UserDirectory users, Permissions permissions) =>
            {
                var caller = context.GetCaller();
                if (caller is null)
                {
                    return Problem.Unauthenticated();
                }

                var ct = context.RequestAborted;
                var profile = await db.MemberProfiles.AsNoTracking().Where(p => p.UserId == caller.UserId).FirstOrDefaultAsync(ct);
                var me = await ProfileAnswer.BuildAsync(caller, profile, users, permissions, ct);
                return Results.Json(new JsonObject { ["me"] = me });
            })
            .RequireMember(createsMember: true);
        return routes;
    }
}
