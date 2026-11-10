using Microsoft.AspNetCore.Http;
using MySqlConnector;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>
/// Runs once per request, before any endpoint: verifies the credentials and maps the token to
/// a registered member (users.id, token, roleid). A request without a verified member continues
/// with no caller; each slice decides whether it needs one. token = 0 is a guest, never a member.
/// </summary>
internal sealed class CallerMiddleware(RequestDelegate next, ICallerVerifier verifier, Db db)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var token = await verifier.VerifyAsync(context.Request, context.RequestAborted);
        if (token is int value)
        {
            var caller = await FindMemberAsync(value, context.RequestAborted);
            if (caller is not null)
            {
                context.SetCaller(caller);
            }
        }

        await next(context);
    }

    private async Task<Caller?> FindMemberAsync(int token, CancellationToken ct)
    {
        await using var connection = await db.OpenAsync(ct);
        await using var command = new MySqlCommand(
            "select id, token, roleid from users where token = @token and token > 0 limit 1",
            connection);
        command.Parameters.AddWithValue("@token", token);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct))
        {
            return null;
        }

        return new Caller(reader.GetInt32(0), reader.GetInt32(1), reader.GetInt32(2));
    }
}
