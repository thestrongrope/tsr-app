using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;

namespace Tsr.Shared.Api;

/// <summary>
/// PHP's router answers an unknown path 404 <c>Not Found</c> and a known path with another verb 405 <c>Method Not Allowed</c>,
/// both in the <c>{"detail": "..."}</c> envelope (web/api/mobile/index.php). ASP.NET answers both with an empty body. This
/// fills in the body, only where there is none: a handler's own 404, such as "User not found", is left as it is.
/// </summary>
public static class RouterErrors
{
    public static IApplicationBuilder UseRouterErrors(this IApplicationBuilder app)
    {
        ArgumentNullException.ThrowIfNull(app);
        return app.UseStatusCodePages(WriteDetailAsync);
    }

    private static Task WriteDetailAsync(StatusCodeContext context)
    {
        var response = context.HttpContext.Response;
        var detail = response.StatusCode switch
        {
            StatusCodes.Status404NotFound => "Not Found",
            StatusCodes.Status405MethodNotAllowed => "Method Not Allowed",
            _ => null,
        };
        return detail is null ? Task.CompletedTask : Problem.Detail(response.StatusCode, detail).ExecuteAsync(context.HttpContext);
    }
}
