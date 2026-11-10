using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Http;

namespace Tsr.Shared.Api;

/// <summary>
/// Error responses in the shape the store-live app already reads: <c>{"detail": "..."}</c>,
/// the same as the PHP API's api_fail(). Changing this shape breaks installed builds.
/// </summary>
public static class Problem
{
    public static IResult Detail(int status, string detail) =>
        Results.Json(new ProblemBody(detail), statusCode: status);

    /// <summary>A refusal that also tells the app where the member's account deletion stands (<c>deletion_status</c>).</summary>
    public static IResult Detail(int status, string detail, string deletionStatus) =>
        Results.Json(new DeletionProblemBody(detail, deletionStatus), statusCode: status);

    public static IResult Unauthenticated() => Detail(StatusCodes.Status401Unauthorized, "Sign in required");

    public static IResult Forbidden() => Detail(StatusCodes.Status403Forbidden, "Not allowed");

    private sealed record ProblemBody(string Detail);

    private sealed record DeletionProblemBody(string Detail, [property: JsonPropertyName("deletion_status")] string DeletionStatus);
}
