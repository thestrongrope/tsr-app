using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Identity.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.ChildrenLinkInspect;

// Slice: GET /me/children/link/{code} -> {state}: not_found, expired, or valid with the child's first name. Writes nothing.
// Permission children:link, then a rate limit (60 per hour per member, every call counts). Contract: spec/api.yaml.
// PHP: routes/children.php route_children_link_inspect, GuardiansModel::inspectInvite.

internal static class ChildrenLinkInspectEndpoint
{
    public const string Permission = "children:link";
    public const string Bucket = "parent_invite_inspect";
    public const int MaxCalls = 60;
    public const int WindowSeconds = 3600;

    public static IEndpointRouteBuilder MapChildrenLinkInspect(this IEndpointRouteBuilder routes)
    {
        routes.MapGet(
            "/me/children/link/{code}",
            (HttpContext context, string code, ChildrenLinkInspectHandler handler) =>
                handler.HandleAsync(context.GetCaller(), code, context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed partial class ChildrenLinkInspectHandler(
    MembershipContext db,
    Permissions permissions,
    UserDirectory users,
    MemberRateLimit limit,
    TimeProvider clock,
    ILogger<ChildrenLinkInspectHandler> logger)
{
    public async Task<IResult> HandleAsync(Caller? caller, string code, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, ChildrenLinkInspectEndpoint.Permission, AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        if (!limit.Allow(ChildrenLinkInspectEndpoint.Bucket, caller.Token, ChildrenLinkInspectEndpoint.MaxCalls, ChildrenLinkInspectEndpoint.WindowSeconds))
        {
            LogRateLimited(logger);
            return Problem.Detail(StatusCodes.Status429TooManyRequests, GuardianRules.TooManyLookups);
        }

        var link = await FindAsync(code, ct);
        var state = GuardianRules.InspectState(link?.Status, link?.ExpiresAt, clock.GetUtcNow());
        if (state != "valid")
        {
            return Results.Json(new JsonObject { ["state"] = state });
        }

        return Results.Json(new JsonObject { ["state"] = state, ["first_name"] = await FirstNameAsync(link!.ChildToken, ct) });
    }

    // A code is 32 characters; a longer one cannot match a row, so it is not looked up.
    private async Task<UserGuardian?> FindAsync(string code, CancellationToken ct) =>
        code.Length > MembershipContext.CodeLength
            ? null
            : await db.UserGuardians.AsNoTracking().Where(g => g.Code == code).FirstOrDefaultAsync(ct);

    // PHP: LEFT JOIN users ON token ... LIMIT 1: the first holder of the child's token, whose first name may be null.
    private async Task<string?> FirstNameAsync(int childToken, CancellationToken ct)
    {
        var holders = await users.ByTokenAsync(childToken, ct);
        if (holders.Count == 0)
        {
            return null;
        }

        var holderId = holders[0].Id;
        return await db.MemberProfiles.AsNoTracking().Where(p => p.UserId == holderId).Select(p => p.FirstName).FirstOrDefaultAsync(ct);
    }

    // PHP: log_event('parent_invite_inspect.rate_limited'). No member token in the log line.
    [LoggerMessage(Level = LogLevel.Warning, Message = "parent_invite_inspect.rate_limited")]
    private static partial void LogRateLimited(ILogger logger);
}
