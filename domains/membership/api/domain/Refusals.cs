using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>Refusals every membership operation shares, in PHP's words.</summary>
internal static class Refusals
{
    /// <summary>PHP's <c>api_require()</c> refusal: 403 "You do not have permission to do that" (shared Problem.Forbidden says "Not allowed").</summary>
    public static IResult NotPermitted() => Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to do that");

    /// <summary>PHP PARENT_AMBIGUOUS_TOKEN_MESSAGE: a token shared by several members, with a machine-readable code beside the detail.</summary>
    public const string AmbiguousTokenText = "More than one member has that token number. Please contact an admin.";

    internal sealed record Coded(string Detail, string Code);

    public static IResult AmbiguousToken() => Results.Json(new Coded(AmbiguousTokenText, "ambiguous_token"), MembershipJson.Answers.Coded, statusCode: StatusCodes.Status422UnprocessableEntity);
}
