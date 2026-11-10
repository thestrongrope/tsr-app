using System.Text.Encodings.Web;
using System.Text.Json;

namespace Tsr.Platform.Api.Domain;

internal static class AppCatalogJson
{
    public static JsonSerializerOptions Options { get; } = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };
}
