using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Platform.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Features.SubmitFeedback;

// One vertical slice: POST /feedback. Request, endpoint, handler and event live together.
// Contract: domains/platform/spec/api.yaml. Behaviour is proven by domains/platform/spec/tests.

/// <summary>Request body. Both fields are required; nullable so a missing one is a 422, not a 400.</summary>
internal sealed record SubmitFeedbackRequest(string? ClientId, string? Text);

internal sealed record SubmitFeedbackResponse(int Id);

/// <summary>Event written to the outbox when a new message is stored. Carries no message text.</summary>
internal sealed record FeedbackSubmitted(int FeedbackId, int UserId, DateTimeOffset SubmittedAt);

internal static class SubmitFeedbackEndpoint
{
    public const string Permission = "feedback:create:self";

    public static IEndpointRouteBuilder MapSubmitFeedback(this IEndpointRouteBuilder routes)
    {
        routes.MapPost(
            "/feedback",
            (HttpContext context, SubmitFeedbackRequest? body, SubmitFeedbackHandler handler) =>
                handler.HandleAsync(context.GetCaller(), body, context.RequestAborted));
        return routes;
    }
}

/// <summary>Application layer for this use case: check, validate, store once, publish.</summary>
internal sealed class SubmitFeedbackHandler(PlatformContext db, Permissions permissions, TimeProvider clock)
{
    public async Task<IResult> HandleAsync(Caller? caller, SubmitFeedbackRequest? body, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, SubmitFeedbackEndpoint.Permission, ct))
        {
            return Problem.Forbidden();
        }

        var clientId = ClientId.Create(body?.ClientId);
        if (!clientId.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, clientId.Error!);
        }

        var text = FeedbackText.Create(body?.Text);
        if (!text.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, text.Error!);
        }

        var id = await StoreOnceAsync(caller, clientId.Value!, text.Value!, ct);
        return Results.Json(new SubmitFeedbackResponse(id), statusCode: StatusCodes.Status201Created);
    }

    private async Task<int> StoreOnceAsync(Caller caller, ClientId clientId, FeedbackText text, CancellationToken ct)
    {
        var existing = await FindAsync(caller.UserId, clientId, ct);
        if (existing is int found)
        {
            return found;
        }

        try
        {
            return await InsertAsync(caller, clientId, text, ct);
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // Two sends of the same message at once: the unique key refused the second one. The
            // transaction is rolled back by now, so the stored row can be read again.
            db.ChangeTracker.Clear();
            return await FindAsync(caller.UserId, clientId, ct)
                ?? throw new InvalidOperationException("Duplicate key without a stored row", e);
        }
    }

    private async Task<int> InsertAsync(Caller caller, ClientId clientId, FeedbackText text, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var row = new Feedback { UserId = caller.UserId, ClientId = clientId.Value, Message = text.Value };
        db.Feedback.Add(row);
        await db.SaveChangesAsync(ct);

        var submitted = new FeedbackSubmitted(row.Id, caller.UserId, clock.GetUtcNow());
        await Outbox.WriteAsync(db, "platform.feedback_submitted", submitted, clock, ct);
        await transaction.CommitAsync(ct);
        return row.Id;
    }

    private async Task<int?> FindAsync(int userId, ClientId clientId, CancellationToken ct)
    {
        var id = clientId.Value;
        return await db.Feedback.AsNoTracking()
            .Where(f => f.UserId == userId && f.ClientId == id)
            .Select(f => (int?)f.Id)
            .FirstOrDefaultAsync(ct);
    }
}
