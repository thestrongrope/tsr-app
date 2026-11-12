using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api.Features.AdminDeletionConfirmationSent;

// Slice: POST /admin/deletion-requests/{request_id}/confirmation-sent (PHP route_admin_deletion_request_confirmation_sent): record that the operator has sent the member the confirmation
// (the stamp completion refuses to run without). Nothing is sent: the response's request carries the email text while it is still to be sent. Signed in (a create route),
// deletion-requests:manage (403), the request (404). Only a live, unstamped request is stamped: a second send keeps the first time and answers 200; a settled request is 409
// "This request is settled and cannot take a confirmation". No event (not one of the four state changes). Contract: spec/api.yaml.

internal static class AdminDeletionConfirmationSentSlice
{
    public static IEndpointRouteBuilder MapAdminDeletionConfirmationSent(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/deletion-requests/{request_id}/confirmation-sent", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string request_id, HttpContext context, IdentityContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        var refusal = await DeletionRequests.RefuseAsync(caller, permissions, "deletion-requests:manage", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var id = DeletionRequests.ParseId(request_id);
        var found = id is null ? null : await DeletionRequests.FindAsync(db, id.Value, ct);
        if (found is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Deletion request not found");
        }

        var now = clock.GetUtcNow();
        var stamped = await db.Database.ExecuteSqlAsync(
            $"""
            update identity.account_deletion_requests set confirmation_sent_at = {now}, handled_by = {caller!.Token}
            where id = {found.Id} and status::text in ('pending', 'awaiting_prize_delivery') and confirmation_sent_at is null
            """,
            ct) == 1;
        var row = await DeletionRequests.FindAsync(db, found.Id, ct) ?? found;
        if (!stamped && !(DeletionViews.IsLive(row.Status) && row.ConfirmationSentAt is not null))
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "This request is settled and cannot take a confirmation");
        }

        return Results.Json(new Dictionary<string, object?> { ["request"] = DeletionViews.AdminView(row, await DeletionRequests.DemoTokensAsync(db, ct)) });
    }
}
