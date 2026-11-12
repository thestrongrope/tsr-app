using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Domain;

/// <summary>
/// The answer of a route that shows a member's permissions when they cannot be loaded: 503, never an empty 200
/// (PHP routes/permissions.php and permission_grants.php catch PermissionsUnavailableException). Logged, with the error's type only.
/// </summary>
internal static partial class UnavailableAnswer
{
    public const string Message = "Permissions could not be loaded. Try again.";

    public static RouteHandlerBuilder AnswersUnavailable(this RouteHandlerBuilder route) =>
        route.AddEndpointFilter(async (invocation, next) =>
        {
            try
            {
                return await next(invocation);
            }
            catch (PermissionsUnavailableException e)
            {
                var logger = invocation.HttpContext.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger("Tsr.Access.Permissions");
                LogUnavailable(logger, (e.InnerException ?? e).GetType().Name);
                return Problem.Detail(StatusCodes.Status503ServiceUnavailable, Message);
            }
        });

    [LoggerMessage(Level = LogLevel.Error, Message = "permissions.unavailable error={Type}")]
    private static partial void LogUnavailable(ILogger logger, string type);
}
