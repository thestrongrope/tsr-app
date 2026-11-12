using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Domain;

/// <summary>What every WhatsApp slice shares: the whatsapp:manage guard, the no-store header of the link routes, their rate limits and the input rules.</summary>
internal static class NotifierAccess
{
    public const int MaxText = 4096;
    public const int MaxFieldText = 500;

    /// <summary>PHP api_require refusal.</summary>
    public static IResult NotPermitted() => Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to do that");

    /// <summary>The caller when signed in and allowed whatsapp:manage (PHP api_authenticate then api_require), else the refusal.</summary>
    public static async Task<(Caller? Caller, IResult? Refusal)> RequireManagerAsync(HttpContext context, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return (null, Problem.Unauthenticated());
        }

        return await permissions.CanAsync(caller, "whatsapp:manage", AccessTarget.None, ct) ? (caller, null) : (null, NotPermitted());
    }

    /// <summary>A route precheck: Cache-Control no-store is sent before the sign-in, so even a refusal is never cached (the QR code is a live credential). Never refuses.</summary>
    public static IResult? NoStore(HttpContext context)
    {
        context.Response.Headers.CacheControl = "no-store";
        return null;
    }

    /// <summary>The link routes' per-member limit, PHP api_whatsapp_link_limit: the refusal when over it.</summary>
    public static IResult? LinkLimit(MemberRateLimit limit, Caller caller, string bucket, int perMinute) =>
        limit.Allow(bucket, caller.Token, perMinute, 60)
            ? null
            : Problem.Detail(StatusCodes.Status429TooManyRequests, "Too many requests. Please wait a minute and try again.");

    /// <summary>PHP (int) of a path segment: numeric prefix, else 0; a 0 never names a reminder or run.</summary>
    public static long IdOf(string segment) => PhpValue.IntOfText(segment);

    /// <summary>422 text when a value to forward holds a NUL byte or is longer than <paramref name="max"/> characters; else null.</summary>
    public static string? TextProblem(string name, string value, int max)
    {
        if (value.Contains('\0', StringComparison.Ordinal))
        {
            return $"{name} must not contain a NUL byte";
        }

        return PhpText.CodePointCount(value) > max ? $"{name} must be {max} characters or fewer" : null;
    }

    /// <summary>The first 422 text over the strings of a value (any depth), else null.</summary>
    public static string? JsonTextProblem(string name, JsonElement value, int max)
    {
        switch (value.ValueKind)
        {
            case JsonValueKind.String:
                return TextProblem(name, value.GetString()!, max);
            case JsonValueKind.Array:
                return value.EnumerateArray().Select(item => JsonTextProblem(name, item, max)).FirstOrDefault(problem => problem is not null);
            case JsonValueKind.Object:
                return value.EnumerateObject().Select(item => JsonTextProblem(name, item.Value, max) ?? TextProblem(name, item.Name, max)).FirstOrDefault(problem => problem is not null);
            default:
                return null;
        }
    }
}
