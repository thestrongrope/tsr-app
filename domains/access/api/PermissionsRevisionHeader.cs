using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api;

/// <summary>
/// Tells the app which permissions revision the signed-in member is on, so it can notice that the answer it saved from
/// GET /me/permissions is out of date (PHP lib/auth.php api_authenticate, lib/permissions_snapshot.php). It runs after
/// identity's middleware, as PHP does at the end of its sign-in: only a request whose sign-in passed gets the header, and
/// the value is the member's revision BEFORE the route runs, whatever the route then answers or writes. The resolution is
/// the request's one (<see cref="Permissions"/> keeps it), so the route's own checks read nothing again. Permissions that
/// cannot be loaded leave the header out and never fail the request: the route that needs them reports the failure.
/// </summary>
internal sealed partial class PermissionsRevisionHeader(RequestDelegate next, ILogger<PermissionsRevisionHeader> logger)
{
    public const string Name = "X-Permissions-Revision";

    // Permissions is scoped, so it arrives per request here, never in the (singleton) constructor.
    public async Task InvokeAsync(HttpContext context, Permissions permissions)
    {
        var caller = context.GetCaller();
        if (caller is not null)
        {
            var revision = await RevisionOrNullAsync(permissions, caller, context.RequestAborted);
            if (revision is not null)
            {
                context.Response.Headers[Name] = revision;
            }
        }

        await next(context);
    }

    private async Task<string?> RevisionOrNullAsync(Permissions permissions, Caller caller, CancellationToken ct)
    {
        try
        {
            var access = await permissions.ForUserOrUnavailableAsync(caller, ct);
            return PermissionsSnapshot.RevisionOf(PermissionsSnapshot.PayloadVersion, access, PermissionsSnapshot.NavigationOf(access));
        }
        catch (PermissionsUnavailableException e)
        {
            LogLeftOut(logger, (e.InnerException ?? e).GetType().Name);
            return null;
        }
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "permissions.revision_header_left_out error={Type}")]
    private static partial void LogLeftOut(ILogger logger, string type);
}
