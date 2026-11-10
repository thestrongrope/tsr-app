using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using MySqlConnector;
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
internal sealed class SubmitFeedbackHandler(Db db, Permissions permissions, TimeProvider clock)
{
    private const int DuplicateKey = 1062;

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
        await using var connection = await db.OpenAsync(ct);
        var existing = await FindAsync(connection, caller.UserId, clientId, ct);
        if (existing is int found)
        {
            return found;
        }

        try
        {
            return await InsertAsync(connection, caller, clientId, text, ct);
        }
        catch (MySqlException e) when (e.Number == DuplicateKey)
        {
            // Two sends of the same message at once: the unique key refused the second one.
            return await FindAsync(connection, caller.UserId, clientId, ct)
                ?? throw new InvalidOperationException("Duplicate key without a stored row", e);
        }
    }

    private async Task<int> InsertAsync(
        MySqlConnection connection, Caller caller, ClientId clientId, FeedbackText text, CancellationToken ct)
    {
        await using var transaction = await connection.BeginTransactionAsync(ct);
        await using var insert = new MySqlCommand(
            "insert into feedback (user_id, client_id, message) values (@user, @client, @message)",
            connection,
            transaction);
        insert.Parameters.AddWithValue("@user", caller.UserId);
        insert.Parameters.AddWithValue("@client", clientId.Value);
        insert.Parameters.AddWithValue("@message", text.Value);
        await insert.ExecuteNonQueryAsync(ct);
        var id = checked((int)insert.LastInsertedId);

        var submitted = new FeedbackSubmitted(id, caller.UserId, clock.GetUtcNow());
        await Outbox.WriteAsync(connection, transaction, "platform.feedback_submitted", submitted, clock, ct);
        await transaction.CommitAsync(ct);
        return id;
    }

    private static async Task<int?> FindAsync(
        MySqlConnection connection, int userId, ClientId clientId, CancellationToken ct)
    {
        await using var command = new MySqlCommand(
            "select id from feedback where user_id = @user and client_id = @client limit 1", connection);
        command.Parameters.AddWithValue("@user", userId);
        command.Parameters.AddWithValue("@client", clientId.Value);
        var value = await command.ExecuteScalarAsync(ct);
        return value is null ? null : Convert.ToInt32(value, System.Globalization.CultureInfo.InvariantCulture);
    }
}
