using System.Text.Json;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// JSON decoding that accepts what PHP's json_decode accepts. The one difference to System.Text.Json
/// that matters: a lone surrogate escape ("\ud800") in ANY string or key makes PHP refuse the whole
/// document, while .NET parses it and only throws later, when that one string is read.
/// </summary>
internal static class PhpJson
{
    private static readonly JsonDocumentOptions Options = new() { MaxDepth = 512, AllowDuplicateProperties = true };

    /// <summary>Parses the document; throws <see cref="JsonException"/> when PHP's decoder would return null.</summary>
    public static JsonDocument Parse(byte[] utf8)
    {
        var document = JsonDocument.Parse(utf8, Options);
        try
        {
            RequireValidStrings(utf8);
            return document;
        }
        catch
        {
            document.Dispose();
            throw;
        }
    }

    private static void RequireValidStrings(byte[] utf8)
    {
        var reader = new Utf8JsonReader(utf8, new JsonReaderOptions { MaxDepth = Options.MaxDepth });
        while (reader.Read())
        {
            if (reader.TokenType is not (JsonTokenType.String or JsonTokenType.PropertyName))
            {
                continue;
            }

            try
            {
                reader.GetString();
            }
            catch (InvalidOperationException)
            {
                throw new JsonException("a string holds a lone surrogate escape");
            }
        }
    }
}
