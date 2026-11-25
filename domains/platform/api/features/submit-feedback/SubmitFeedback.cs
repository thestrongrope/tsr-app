using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using System.Text.Json;
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
    public const string Permission = "feedback:create";

    public static IEndpointRouteBuilder MapSubmitFeedback(this IEndpointRouteBuilder routes)
    {
        routes.MapPost(
            "/feedback",
            (HttpContext context, SubmitFeedbackHandler handler) =>
                handler.HandleAsync(context.GetCaller(), context.Request, context.RequestAborted))
            .RequireMember();
        return routes;
    }
}

/// <summary>Application layer for this use case: check, validate, store once, publish.</summary>
internal sealed class SubmitFeedbackHandler(NpgsqlDataSource source, Permissions permissions, TimeProvider clock)
{
    public async Task<IResult> HandleAsync(Caller? caller, HttpRequest request, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, SubmitFeedbackEndpoint.Permission, AccessTarget.None, ct))
        {
            return Problem.Forbidden();
        }

        var (body, malformed) = await ReadBodyAsync(request, ct);
        if (malformed is not null)
        {
            return malformed;
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
        return Results.Json(new SubmitFeedbackResponse(id), PlatformJson.Answers.SubmitFeedbackResponse, contentType: null, statusCode: StatusCodes.Status201Created);
    }

    // The body as the framework's binder read it: absent or empty is null (a 422 for the missing fields below); JSON that does not parse as the request is a 400; over a megabyte is a 413.
    private static async Task<(SubmitFeedbackRequest? Body, IResult? Refusal)> ReadBodyAsync(HttpRequest request, CancellationToken ct)
    {
        using var buffer = new MemoryStream();
        var chunk = new byte[8192];
        int read;
        while ((read = await request.Body.ReadAsync(chunk, ct)) > 0)
        {
            if (buffer.Length + read > RequestBodies.MaxBytes)
            {
                return (null, Problem.Detail(StatusCodes.Status413PayloadTooLarge, "Request body too large"));
            }

            buffer.Write(chunk, 0, read);
        }

        if (buffer.Length == 0)
        {
            return (null, null);
        }

        try
        {
            return (JsonSerializer.Deserialize(buffer.ToArray(), PlatformJson.Answers.SubmitFeedbackRequest), null);
        }
        catch (JsonException)
        {
            return (null, Problem.Detail(StatusCodes.Status400BadRequest, "Invalid JSON body"));
        }
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
        catch (PostgresException e) when (e.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            // Two sends of the same message at once: the unique key refused the second one. The
            // transaction is rolled back by now, so the stored row can be read again.
            return await FindAsync(caller.UserId, clientId, ct)
                ?? throw new InvalidOperationException("Duplicate key without a stored row", e);
        }
    }

    private async Task<int> InsertAsync(Caller caller, ClientId clientId, FeedbackText text, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        var id = await tx.ScalarAsync<int>(
            $"insert into platform.feedback (user_id, client_id, message) values ({caller.UserId}, {clientId.Value}, {text.Value}) returning id",
            ct) ?? throw new InvalidOperationException("The feedback insert returned no id");

        var submitted = new FeedbackSubmitted(id, caller.UserId, clock.GetUtcNow());
        await Outbox.WriteAsync(tx, "platform.feedback_submitted", submitted, PlatformJson.Default.FeedbackSubmitted, clock, ct);
        await tx.CommitAsync(ct);
        return id;
    }

    private async Task<int?> FindAsync(int userId, ClientId clientId, CancellationToken ct) =>
        await source.ScalarAsync<int>(
            $"select f.id from platform.feedback f where f.user_id = {userId} and f.client_id = {clientId.Value}::citext limit 1",
            ct);
}
