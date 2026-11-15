using System.Text.Json;

namespace Tsr.Notifications.Api.Domain;

/// <summary>PHP's <c>api_device_token</c>: the FCM token of the body under <c>fcmToken</c> or <c>fcm_token</c>, trimmed. Never log or echo it.</summary>
internal static class DeviceToken
{
    public const int MaxLength = 500;

    public const string Required = "fcmToken is required";
    public const string Invalid = "fcmToken must be at most 500 characters and hold no NUL character";

    public static Result<string> Parse(JsonBody body)
    {
        ArgumentNullException.ThrowIfNull(body);
        var value = body.Get("fcmToken");
        if (value.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
        {
            value = body.Get("fcm_token");
        }

        var token = value.ValueKind == JsonValueKind.String ? PhpText.Trim(value.GetString() ?? string.Empty) : string.Empty;
        if (token.Length == 0)
        {
            return Result.Fail<string>(Required);
        }

        if (PhpText.CodePointCount(token) > MaxLength || token.Contains('\0', StringComparison.Ordinal))
        {
            return Result.Fail<string>(Invalid);
        }

        return Result.Ok(token);
    }
}
