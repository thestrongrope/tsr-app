using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>Refusals every membership operation shares, in PHP's words.</summary>
internal static class Refusals
{
    /// <summary>PHP's <c>api_require()</c> refusal: 403 "You do not have permission to do that" (shared Problem.Forbidden says "Not allowed").</summary>
    public static IResult NotPermitted() => Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to do that");
}
