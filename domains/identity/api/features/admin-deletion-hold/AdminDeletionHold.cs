using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Identity.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api.Features.AdminDeletionHold;

// Slice: POST /admin/deletion-requests/{request_id}/hold {note?} (PHP route_admin_deletion_request_hold): hold a live request for prize delivery, with a note the member reads.
// Signed in (a create route), deletion-requests:manage (403), the request (404 "Deletion request not found", also for an id that is not a positive number), body (422), note text of at most 500
// characters (422 "note must be text" / "note must be 500 characters or fewer"), then the guarded update; 409 "This request is no longer live" when it is settled. Holding a request that is already held
// replaces the note and is not a state change (no event). Event identity.deletion_held. Contract: spec/api.yaml.

internal static class AdminDeletionHoldSlice
{
    internal sealed record Held(int RequestId, int? Token, int HandledBy);

    public static IEndpointRouteBuilder MapAdminDeletionHold(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/deletion-requests/{request_id}/hold", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string request_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        var refusal = await DeletionRequests.RefuseAsync(caller, permissions, "deletion-requests:manage", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var id = DeletionRequests.ParseId(request_id);
        DeletionRow? found = null;
        if (id is not null)
        {
            await using var read = await source.BeginAsync(ct);
            found = await DeletionRequests.FindAsync(read, id.Value, ct);
        }

        if (found is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Deletion request not found");
        }

        var (body, bad) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bad is not null)
        {
            return bad;
        }

        var (note, noteRefusal) = DeletionRequests.ReadText(body!, "note");
        if (noteRefusal is not null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, noteRefusal);
        }

        if (!await HoldAsync(source, clock, found, note, caller!.Token, ct))
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "This request is no longer live");
        }

        await using var again = await source.BeginAsync(ct);
        var row = await DeletionRequests.FindAsync(again, found.Id, ct) ?? found;
        return Results.Json(new Dictionary<string, object?> { ["request"] = DeletionViews.AdminView(row, await DeletionRequests.DemoTokensAsync(again, ct)) }, IdentityJson.Answers.Answer);
    }

    private static async Task<bool> HoldAsync(NpgsqlDataSource source, TimeProvider clock, DeletionRow found, string? note, int operatorToken, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        var changed = await tx.ExecuteAsync(
            $"""
            update identity.account_deletion_requests
            set status = 'awaiting_prize_delivery', operator_note = {note}, handled_by = {operatorToken}
            where id = {found.Id} and status::text in ('pending', 'awaiting_prize_delivery')
            """,
            ct);
        if (changed == 0)
        {
            return false;
        }

        if (found.Status == DeletionViews.Pending)
        {
            await Outbox.WriteAsync(tx, "identity.deletion_held", new Held(found.Id, found.Token, operatorToken), IdentityJson.Default.Held, clock, ct);
        }

        await tx.CommitAsync(ct);
        return true;
    }
}
