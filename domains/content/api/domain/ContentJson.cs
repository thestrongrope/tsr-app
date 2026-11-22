using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using Tsr.Content.Api.Features.HolyQuran;
using Tsr.Content.Api.Features.ListPublishedArticles;

namespace Tsr.Content.Api.Domain;

/// <summary>
/// The two answers of content that are written from a value, without reflection (web defaults, as the host's <c>Results.Json</c> uses).
/// The six <c>/api/v1/</c> answers and the copy's hash are written by hand with <c>Utf8JsonWriter</c> and need nothing here. Content writes no event.
/// <c>ContentJson.Tests.cs</c> writes each with reflection off.
/// </summary>
[JsonSourceGenerationOptions(JsonSerializerDefaults.Web)]
[JsonSerializable(typeof(List<HolyQuranSlice.SurahItem>), TypeInfoPropertyName = "SurahList")]
[JsonSerializable(typeof(ListPublishedArticlesResponse))]
internal sealed partial class ContentJson : JsonSerializerContext
{
    /// <summary>
    /// For the answers: the host's own options (web defaults and the relaxed encoder ASP.NET Core's JSON options use, so '+' and the Arabic surah names stay as written, not \uXXXX).
    /// </summary>
    public static ContentJson Answers { get; } = new(new JsonSerializerOptions(JsonSerializerDefaults.Web) { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping });
}
