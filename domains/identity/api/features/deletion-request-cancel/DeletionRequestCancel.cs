using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
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

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        var refusal = await DeletionRequests.RefuseAsync(caller, permissions, "account:delete", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        if (!await CancelAsync(source, clock, caller!.Token, ct))
        {
            await using var read = await source.BeginAsync(ct);
            return await HasCompletedAsync(read, caller.Token, ct)
                ? Problem.Detail(StatusCodes.Status409Conflict, "This account has already been deleted and cannot be restored")
                : Problem.Detail(StatusCodes.Status404NotFound, "No pending deletion request");
        }

        return Results.Json(new Dictionary<string, object?> { ["status"] = "cancelled" }, IdentityJson.Answers.Answer);
    }

    private static async Task<bool> CancelAsync(NpgsqlDataSource source, TimeProvider clock, int token, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await using var tx = await source.BeginAsync(ct);
        var active = await DeletionRequests.ActiveForAsync(tx, token, ct);
        var changed = await tx.ExecuteAsync(
            $"""
            update identity.account_deletion_requests set status = 'cancelled', cancelled_at = {now}
            where token = {token} and status::text in ('pending', 'awaiting_prize_delivery')
            """,
            ct);
        if (changed == 0)
        {
            return false;
        }

        await Outbox.WriteAsync(tx, "identity.deletion_cancelled", new Cancelled(active?.Id ?? 0, token), IdentityJson.Default.Cancelled, clock, ct);
        await tx.CommitAsync(ct);
        return true;
    }

    private static async Task<bool> HasCompletedAsync(DbTx tx, int token, CancellationToken ct) =>
        (await tx.ListAsync(
            $"""select 1 as "Value" from identity.account_deletion_requests where token = {token} and status::text = 'completed' limit 1""",
            row => row.Int("Value"),
            ct)).Count > 0;
}
