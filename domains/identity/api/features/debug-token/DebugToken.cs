using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Tsr.Identity.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api.Features.DebugToken;

// Slice: POST /auth/debug-token (PHP routes/auth.php route_auth_debug_token): echoes what the bearer token decoded to, for developers. Public route (no member, no database: it works for a valid
// token whose user has no row yet), so the middleware never sees it. NEVER served in Production: the host environment is read on every request and Production (also the default when none is
// set) answers 404 "Not found" first, before the token is looked at. Otherwise: no/odd Authorization header 401 "Not authenticated"; a token that does not verify 401 "Invalid auth token";
// else {status: success, email, uid (the subject), name, provider}, each null when the token lacks it. provider is ALWAYS null, as PHP's: its verifier hands on no `firebase` claim, so PHP never reads sign_in_provider (a PHP bug, copied; test phase decision). Nothing is written or logged from the token.

internal static partial class DebugTokenSlice
{
    public static IEndpointRouteBuilder MapDebugToken(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/auth/debug-token", HandleAsync);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, IHostEnvironment environment, ILoggerFactory loggers)
    {
        if (environment.IsProduction())
        {
            LogBlocked(loggers.CreateLogger("Tsr.Identity.Api.DebugToken"));
            return Problem.Detail(StatusCodes.Status404NotFound, "Not found");
        }

        if (!FirebaseVerifier.BearerHeader().IsMatch(context.Request.Headers.Authorization.ToString().Trim()))
        {
            return Problem.Detail(StatusCodes.Status401Unauthorized, "Not authenticated");
        }

        var result = await context.AuthenticateAsync(JwtBearerDefaults.AuthenticationScheme);
        if (!result.Succeeded || string.IsNullOrEmpty(result.Principal.FindFirstValue("sub")))
        {
            return Problem.Detail(StatusCodes.Status401Unauthorized, "Invalid auth token");
        }

        var principal = result.Principal;
        return Results.Json(new Dictionary<string, object?>
        {
            ["status"] = "success",
            ["email"] = TextClaim(principal, "email"),
            ["uid"] = principal.FindFirstValue("sub"),
            ["name"] = TextClaim(principal, "name"),
            ["provider"] = null,
        }, IdentityJson.Answers.Answer);
    }

    private static string? TextClaim(ClaimsPrincipal principal, string type) =>
        principal.FindFirst(type) is { ValueType: ClaimValueTypes.String, Value: var value } ? value : null;

    [LoggerMessage(Level = LogLevel.Warning, Message = "auth.debug_token_blocked")]
    private static partial void LogBlocked(ILogger logger);
}
