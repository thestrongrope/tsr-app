using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>Refusals the quiz slices share, in PHP's words.</summary>
internal static class Refusals
{
    /// <summary>PHP's <c>api_require()</c> refusal.</summary>
    public static IResult NotPermitted() => Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to do that");

    /// <summary>PHP's <c>api_require_identity()</c> refusal: the member's gender is not a number.</summary>
    public static IResult GenderNotSet() => Problem.Detail(StatusCodes.Status400BadRequest, "User gender not set; update profile first");

    public static IResult QuizNotFound() => Problem.Detail(StatusCodes.Status404NotFound, "Quiz not found");

    public static IResult ClassNotEnrolled() => Problem.Detail(StatusCodes.Status404NotFound, "Class not found or not enrolled");
}
