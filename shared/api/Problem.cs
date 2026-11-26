using System.Text.Json;
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
        Results.Json(new ProblemBody(detail), ProblemJson.Default.ProblemBody, statusCode: status);

    /// <summary>A refusal that also tells the app where the member's account deletion stands (<c>deletion_status</c>).</summary>
    public static IResult Detail(int status, string detail, string deletionStatus) =>
        Results.Json(new DeletionProblemBody(detail, deletionStatus), ProblemJson.Default.DeletionProblemBody, statusCode: status);

    public static IResult Unauthenticated() => Detail(StatusCodes.Status401Unauthorized, "Sign in required");

    public static IResult Forbidden() => Detail(StatusCodes.Status403Forbidden, "Not allowed");

}

internal sealed record ProblemBody(string Detail);

internal sealed record DeletionProblemBody(string Detail, [property: JsonPropertyName("deletion_status")] string DeletionStatus);

/// <summary>
/// Source-generated serializer for the two error bodies, so no reflection is needed. Web defaults, as the host's JSON options, so the bytes
/// are the ones the reflection serializer wrote (pinned in Problem.Tests.cs).
/// </summary>
[JsonSourceGenerationOptions(JsonSerializerDefaults.Web)]
[JsonSerializable(typeof(ProblemBody))]
[JsonSerializable(typeof(DeletionProblemBody))]
internal sealed partial class ProblemJson : JsonSerializerContext;
