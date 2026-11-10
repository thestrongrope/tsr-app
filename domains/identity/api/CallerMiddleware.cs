using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>
/// Runs once per request, before any endpoint: verifies the credentials and maps the token to
/// a registered member (users.id, token, roleid). A request without a verified member continues
/// with no caller; each slice decides whether it needs one. token = 0 is a guest, never a member.
/// </summary>
internal sealed class CallerMiddleware(RequestDelegate next, ICallerVerifier verifier)
{
    // The context is scoped, so it arrives per request here, never in the (singleton) constructor.
    public async Task InvokeAsync(HttpContext context, IdentityContext db)
    {
        var token = await verifier.VerifyAsync(context.Request, context.RequestAborted);
        if (token is int value)
        {
            var caller = await FindMemberAsync(db, value, context.RequestAborted);
            if (caller is not null)
            {
                context.SetCaller(caller);
            }
        }

        await next(context);
    }

    private static Task<Caller?> FindMemberAsync(IdentityContext db, int token, CancellationToken ct) =>
        db.Users.AsNoTracking()
            .Where(u => u.Token == token && u.Token > 0)
            .Select(u => new Caller(u.Id, u.Token, u.RoleId))
            .FirstOrDefaultAsync(ct);
}
