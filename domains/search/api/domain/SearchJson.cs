using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using Tsr.Search.Api.Features.Search;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// What search writes and reads as JSON, without reflection: the answer of <c>GET /search</c> (<see cref="Answers"/>) and the document the index returns (<see cref="Default"/>,
/// the index client's source serializer, which needs it in a native build). <c>SearchJson.Tests.cs</c> writes the answer with reflection off.
/// </summary>
[JsonSourceGenerationOptions(JsonSerializerDefaults.Web)]
[JsonSerializable(typeof(SearchSlice.Body))]
[JsonSerializable(typeof(ElasticSearchIndex.IndexedDocument))]
internal sealed partial class SearchJson : JsonSerializerContext
{
    /// <summary>
    /// For the answer: the host's own options (web defaults and the relaxed encoder ASP.NET Core's JSON options use, so '+' and non-ASCII text stay as written, not \uXXXX).
    /// </summary>
    public static SearchJson Answers { get; } = new(new JsonSerializerOptions(JsonSerializerDefaults.Web) { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping });
}
