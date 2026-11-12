using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Domain;

/// <summary>
/// PHP's <c>api_whatsapp_ask</c>: a notifier answer of 400 or more becomes the notifier's own status with its <c>error</c> text (the setting that was invalid, the run already in flight,
/// WhatsApp not linked) or, when it has none, "The reminder service could not do that. Please try again."; a lower status gives the decoded JSON when it is an array or object, else nothing.
/// PHP forwards the notifier's error text as is, including the text of an internal failure of the notifier (flagged in docs/specs/initial-build/lane-whatsapp-notes.md).
/// </summary>
internal static class NotifierAsk
{
    private const string Fallback = "The reminder service could not do that. Please try again.";
    private const string Unreachable = "The reminder service cannot be reached right now. Trying again.";

    /// <summary>The decoded data, or the refusal to send. Exactly one is set (the data is <c>default</c> when the answer held none).</summary>
    public static (JsonElement Data, IResult? Refusal) Interpret(NotifierAnswer answer)
    {
        var decoded = Decode(answer.Body);
        if (answer.Status < 400)
        {
            return (decoded, null);
        }

        var error = Field(decoded, "error");
        var text = error.ValueKind == JsonValueKind.String && error.GetString()!.Length > 0 ? error.GetString()! : Fallback;
        return (default, Problem.Detail(answer.Status, text));
    }

    /// <summary>The 503 of the link routes when the notifier cannot be asked.</summary>
    public static IResult LinkUnreachable() => Problem.Detail(StatusCodes.Status503ServiceUnavailable, Unreachable);

    /// <summary>The decoded body when it is a JSON array or object (PHP is_array), otherwise <c>default</c>.</summary>
    public static JsonElement Decode(string body)
    {
        try
        {
            using var document = JsonDocument.Parse(body);
            return document.RootElement.ValueKind is JsonValueKind.Array or JsonValueKind.Object ? document.RootElement.Clone() : default;
        }
        catch (JsonException)
        {
            return default;
        }
    }

    private static JsonElement Field(JsonElement data, string name) => NotifierRows.Field(data, name);
}
