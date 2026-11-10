using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api.Features.LinkAccount;

// One vertical slice: POST /auth/link, the app's first call after Firebase sign-in. The middleware has
// already verified the token and created or found the member (a create route); this answers with who they are.
// Contract: domains/identity/spec/api.yaml. Behaviour is proven by domains/identity/spec/tests.

/// <summary>Only the identity-owned fields of PHP's <c>me</c>. Profile and role fields arrive with membership and access.</summary>
internal sealed record Me(int Id, int Token, string? Email);

internal sealed record LinkAccountResponse(Me Me);

internal static class LinkAccountEndpoint
{
    public static IEndpointRouteBuilder MapLinkAccount(this IEndpointRouteBuilder routes)
    {
        routes.MapPost(
            "/auth/link",
            async (HttpContext context, IdentityContext db) =>
            {
                var caller = context.GetCaller();
                if (caller is null)
                {
                    return Problem.Unauthenticated();
                }

                var me = await db.Users.AsNoTracking()
                    .Where(u => u.Id == caller.UserId)
                    .Select(u => new Me(u.Id, u.Token, u.Email))
                    .FirstAsync(context.RequestAborted);
                return Results.Ok(new LinkAccountResponse(me));
            })
            .RequireMember(createsMember: true);
        return routes;
    }
}
