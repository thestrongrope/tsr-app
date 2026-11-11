using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>Refusals the class slices share, in PHP's words.</summary>
internal static class Refusals
{
    /// <summary>PHP's <c>api_require()</c> refusal: 403 "You do not have permission to do that".</summary>
    public static IResult NotPermitted() => Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to do that");

    /// <summary>PHP's <c>api_find_class()</c> refusal.</summary>
    public static IResult ClassNotFound() => Problem.Detail(StatusCodes.Status404NotFound, "Class not found");

    /// <summary>PHP's <c>api_require_identity()</c> refusal: the member's gender is not a number.</summary>
    public static IResult GenderNotSet() => Problem.Detail(StatusCodes.Status400BadRequest, "User gender not set; update profile first");
}
