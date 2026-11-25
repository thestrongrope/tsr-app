using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Http;
using Tsr.Platform.Api.Features.Health;
using Tsr.Platform.Api.Features.SubmitFeedback;

namespace Tsr.Platform.Api.Domain;

/// <summary>The source-generated serializer of this domain: the answers, the one request body and the outbox event (camelCase as the reflection serializer's web defaults wrote them), so nothing is serialized by reflection.</summary>
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[JsonSerializable(typeof(FeedbackSubmitted))]
[JsonSerializable(typeof(SubmitFeedbackRequest))]
[JsonSerializable(typeof(SubmitFeedbackResponse))]
[JsonSerializable(typeof(HealthResponse))]
[JsonSerializable(typeof(Dictionary<string, object?>), TypeInfoPropertyName = "Answer")]
[JsonSerializable(typeof(List<Dictionary<string, object?>>), TypeInfoPropertyName = "AnswerList")]
[JsonSerializable(typeof(int))]
[JsonSerializable(typeof(long))]
[JsonSerializable(typeof(bool))]
[JsonSerializable(typeof(string))]
internal sealed partial class PlatformJson : JsonSerializerContext
{
    /// <summary>
    /// For the answers and the request body: the host's own options (web defaults and the relaxed encoder ASP.NET Core's JSON options use, so '+' and non-ASCII text stay as written, not \uXXXX).
    /// The access log answer is a dictionary holding <c>object</c> values, so every runtime type behind it is listed above (int, long, string, list of dictionaries).
    /// <see cref="Default"/> (the default encoder) is for the outbox event.
    /// </summary>
    public static PlatformJson Answers { get; } = new(new JsonSerializerOptions(JsonSerializerDefaults.Web) { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping });

    /// <summary>
    /// An answer built as a JSON tree (the geo lists): written with the same options and content type as <c>Results.Json</c>. The source generator has no type info for the tree types, and the tree
    /// is written by its own converters, which need no reflection.
    /// </summary>
    public static IResult Text(JsonNode answer) => Results.Text(answer.ToJsonString(Answers.Options), "application/json; charset=utf-8");
}
