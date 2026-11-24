using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Identity.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api.Features.DeletionRequestCancel;

// Slice: DELETE /me/deletion-request (PHP route_deletion_request_cancel): the member withdraws their live request. Signed in (a create route), account:delete (403). The update is guarded on the
// live statuses, so a cancel racing a completion cannot undo it. {status: cancelled}; 409 "This account has already been deleted and cannot be restored" when a completed request exists;
// else 404 "No pending deletion request". Event identity.deletion_cancelled. Contract: spec/api.yaml.

internal static class DeletionRequestCancelSlice
{
    internal sealed record Cancelled(int RequestId, int Token);

    public static IEndpointRouteBuilder MapDeletionRequestCancel(this IEndpointRouteBuilder routes)
    {
        routes.MapDelete("/me/deletion-request", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, IdentityContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        var refusal = await DeletionRequests.RefuseAsync(caller, permissions, "account:delete", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        if (!await CancelAsync(db, clock, caller!.Token, ct))
        {
            return await HasCompletedAsync(db, caller.Token, ct)
                ? Problem.Detail(StatusCodes.Status409Conflict, "This account has already been deleted and cannot be restored")
                : Problem.Detail(StatusCodes.Status404NotFound, "No pending deletion request");
        }

        return Results.Json(new Dictionary<string, object?> { ["status"] = "cancelled" }, IdentityJson.Answers.Answer);
    }

    private static async Task<bool> CancelAsync(IdentityContext db, TimeProvider clock, int token, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var active = await DeletionRequests.ActiveForAsync(db, token, ct);
        var changed = await db.Database.ExecuteSqlAsync(
            $"""
            update identity.account_deletion_requests set status = 'cancelled', cancelled_at = {now}
            where token = {token} and status::text in ('pending', 'awaiting_prize_delivery')
            """,
            ct);
        if (changed == 0)
        {
            return false;
        }

        await Outbox.WriteAsync(db, "identity.deletion_cancelled", new Cancelled(active?.Id ?? 0, token), clock, ct);
        await transaction.CommitAsync(ct);
        return true;
    }

    private static async Task<bool> HasCompletedAsync(IdentityContext db, int token, CancellationToken ct) =>
        (await db.Database
            .SqlQuery<int>($"""select 1 as "Value" from identity.account_deletion_requests where token = {token} and status::text = 'completed' limit 1""")
            .ToListAsync(ct)).Count > 0;
}
