using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Identity.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.ChildrenLinkAccept;

// Slice: POST /me/children/link/{code} {relationship} -> {child_token, relationship, status: "active"}. The caller becomes the child's
// parent through a one-time invite. Permission children:link. Contract: spec/api.yaml.
// PHP: routes/children.php route_children_link_accept, GuardiansModel::acceptInvite and activateInvite. The status the route maps
// is the model's status, not its http_code: an unknown child is a 404 "Invite not found", a shared token a 422, and so on.

internal static class ChildrenLinkAcceptEndpoint
{
    public const string Permission = "children:link";

    public static IEndpointRouteBuilder MapChildrenLinkAccept(this IEndpointRouteBuilder routes)
    {
        routes.MapPost(
            "/me/children/link/{code}",
            (HttpContext context, string code, ChildrenLinkAcceptHandler handler) =>
                handler.HandleAsync(context.GetCaller(), code, context.Request, context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed class ChildrenLinkAcceptHandler(MembershipContext db, Permissions permissions, UserDirectory users, TimeProvider clock)
{
    public async Task<IResult> HandleAsync(Caller? caller, string code, HttpRequest request, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, ChildrenLinkAcceptEndpoint.Permission, AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var raw = await BodyReader.ReadAsync(request, ct);
        if (raw is null)
        {
            return Problem.Detail(StatusCodes.Status413PayloadTooLarge, "Request body too large");
        }

        var parsed = JsonBody.Parse(raw);
        if (!parsed.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, parsed.Error!);
        }

        var typed = PhpValue.Text(parsed.Value!.Get("relationship"));
        var link = await FindAsync(code, ct);
        if (link is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, GuardianRules.InviteNotFound);
        }

        if (!GuardianRules.IsUsable(link.Status, link.ExpiresAt, clock.GetUtcNow()))
        {
            return Problem.Detail(StatusCodes.Status410Gone, GuardianRules.InviteUsed);
        }

        return await CheckAndActivateAsync(caller, link, typed, ct);
    }

    // The checks that need no lock, in PHP's order; then the locked half.
    private async Task<IResult> CheckAndActivateAsync(Caller caller, UserGuardian link, string typed, CancellationToken ct)
    {
        if (await IsAmbiguousAsync(caller.Token, ct) || link.ChildToken == caller.Token)
        {
            return Invalid();
        }

        var creatorToken = await GuardianChecks.TokenOfUserAsync(users, link.CreatedBy, ct);
        if (creatorToken == caller.Token || GuardianRules.Relationship(typed) is not { } relationship)
        {
            return Invalid();
        }

        var child = await users.ByTokenAsync(link.ChildToken, ct);
        if (child.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, GuardianRules.InviteNotFound);
        }

        if (child.Count > 1)
        {
            return Invalid();
        }

        return await ActivateAsync(caller, link.Code!, relationship, child[0].Id, ct);
    }

    // PHP's validateMemberToken for the caller: a token shared by several members is refused (the caller's own row is one of them).
    private async Task<bool> IsAmbiguousAsync(int token, CancellationToken ct) => (await users.ByTokenAsync(token, ct)).Count > 1;

    private async Task<IResult> ActivateAsync(Caller caller, string code, string relationship, int childUserId, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await GuardianLock.TakeAsync(db, childUserId, ct);

        // The invite is read again under the lock, so a code used or cancelled since the first read is refused.
        var link = await FindAsync(code, ct);
        if (link is null || !GuardianRules.IsUsable(link.Status, link.ExpiresAt, clock.GetUtcNow()))
        {
            return Problem.Detail(StatusCodes.Status410Gone, GuardianRules.InviteUsed);
        }

        var creator = new Caller(link.CreatedBy, await GuardianChecks.TokenOfUserAsync(users, link.CreatedBy, ct));
        if (await GuardianChecks.RemovedByChildBlocksAsync(db, users, permissions, caller.Token, link.ChildToken, childUserId, creator, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, GuardianRules.RemovedByChild);
        }

        if (await db.UserGuardians.AnyAsync(g => g.ParentToken == caller.Token && g.ChildToken == link.ChildToken && g.Status == "active", ct))
        {
            return Problem.Detail(StatusCodes.Status409Conflict, GuardianRules.AlreadyLinked);
        }

        var now = clock.GetUtcNow();
        var changed = await db.UserGuardians
            .Where(g => g.Id == link.Id && g.Status == "invited")
            .ExecuteUpdateAsync(
                set => set
                    .SetProperty(g => g.ParentToken, caller.Token)
                    .SetProperty(g => g.Relationship, relationship)
                    .SetProperty(g => g.Status, "active")
                    .SetProperty(g => g.ActivatedAt, now),
                ct);
        if (changed == 0)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, GuardianRules.AlreadyLinked);
        }

        await transaction.CommitAsync(ct);
        return Results.Json(new JsonObject { ["child_token"] = link.ChildToken, ["relationship"] = relationship, ["status"] = "active" });
    }

    private static IResult Invalid() => Problem.Detail(StatusCodes.Status422UnprocessableEntity, GuardianRules.InvalidLink);

    // A code is 32 characters; a longer one cannot match a row, so it is not looked up.
    private async Task<UserGuardian?> FindAsync(string code, CancellationToken ct) =>
        code.Length > MembershipContext.CodeLength
            ? null
            : await db.UserGuardians.AsNoTracking().Where(g => g.Code == code).FirstOrDefaultAsync(ct);
}
