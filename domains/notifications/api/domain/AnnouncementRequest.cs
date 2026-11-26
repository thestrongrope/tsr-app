using System.Text.Json;

namespace Tsr.Notifications.Api.Domain;

/// <summary>A checked announcement: <c>ActionLink</c> is null when none was given ('' when given empty, as PHP keeps it); <c>CriteriaJson</c> is what PHP stores as the audience.</summary>
internal sealed record AnnouncementInput(string Title, string Body, Target Target, string CriteriaJson, string? ActionLink);

/// <summary>
/// The body rules of <c>POST /notifications/send</c> (PHP routes/notifications.php route_notifications_send), in PHP's order. Unlike the class rules nothing is trimmed, the link is
/// always rewritten to an in-app path when it is a pasted article or video link, and the target is a type plus a list. A NUL character is refused (PHP stores it).
/// </summary>
internal static class AnnouncementRequest
{
    public const string TitleError = "title is required and must be at most 255 characters";
    public const string BodyError = "body is required and must be at most 2000 characters";
    public const string TargetError = "target is required";
    public const string TypeError = "target.type must be one of ALL_USERS, CLASS_LEVEL, GENDER, TEACHERS";
    public const string ValueError = "target.value must be a list";

    public static Result<AnnouncementInput> Parse(JsonBody body)
    {
        ArgumentNullException.ThrowIfNull(body);
        var title = Text(body.Get("title"), 255);
        if (title is null)
        {
            return Fail(TitleError);
        }

        var text = Text(body.Get("body"), 2000);
        if (text is null)
        {
            return Fail(BodyError);
        }

        var target = ParseTarget(body.Get("target"));
        if (!target.IsSuccess)
        {
            return Fail(target.Error!);
        }

        var link = Link(body.Get("action_link"));
        if (!link.IsSuccess)
        {
            return Fail(link.Error!);
        }

        var value = body.Get("target").ValueKind == JsonValueKind.Undefined ? default : TargetValue(body.Get("target"));
        var criteria = JsonSerializer.Serialize(new Dictionary<string, JsonElement?>
        {
            ["type"] = JsonSerializer.SerializeToElement(target.Value!.Type, NotificationsJson.Default.String),
            ["value"] = value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null ? null : value,
        }, NotificationsJson.Default.AudienceCriteria);
        return Result.Ok(new AnnouncementInput(title, text, target.Value, criteria, link.Value));
    }

    // PHP: a string, not empty, at most max characters (mb_strlen: code points).
    private static string? Text(JsonElement value, int max)
    {
        if (value.ValueKind != JsonValueKind.String)
        {
            return null;
        }

        var text = value.GetString() ?? string.Empty;
        return text.Length == 0 || PhpText.CodePointCount(text) > max || text.Contains('\0', StringComparison.Ordinal) ? null : text;
    }

    private static JsonElement TargetValue(JsonElement target) =>
        target.ValueKind == JsonValueKind.Object && target.TryGetProperty("value", out var value) ? value : default;

    private static Result<Target> ParseTarget(JsonElement target)
    {
        if (target.ValueKind is not (JsonValueKind.Object or JsonValueKind.Array))
        {
            return Result.Fail<Target>(TargetError);
        }

        var type = target.ValueKind == JsonValueKind.Object && target.TryGetProperty("type", out var raw) && raw.ValueKind == JsonValueKind.String ? raw.GetString() : null;
        if (type is null || !Audience.TargetTypes.Contains(type))
        {
            return Result.Fail<Target>(TypeError);
        }

        var value = TargetValue(target);
        if (value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null)
        {
            return Result.Ok(new Target(type, []));
        }

        if (value.ValueKind is not (JsonValueKind.Array or JsonValueKind.Object))
        {
            return Result.Fail<Target>(ValueError);
        }

        var values = JsonBody.Entries(value).Select(e => e.Value).Where(v => v.ValueKind != JsonValueKind.Null && !(v.ValueKind == JsonValueKind.String && v.GetString() == string.Empty)).ToList();
        return Result.Ok(new Target(type, values));
    }

    private static Result<string?> Link(JsonElement value)
    {
        if (value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null)
        {
            return Result.Ok<string?>(null);
        }

        if (value.ValueKind != JsonValueKind.String || PhpText.CodePointCount(value.GetString()!) > 500 || value.GetString()!.Contains('\0', StringComparison.Ordinal))
        {
            return Result.Fail<string?>(ClassMessage.LinkLengthError);
        }

        var link = value.GetString()!;
        if (link.Length > 0)
        {
            link = ActionLinks.InApp(link);
        }

        return link.Length == 0 || ActionLinks.Allowed(link) ? Result.Ok<string?>(link) : Result.Fail<string?>(ClassMessage.LinkNotAllowedError);
    }

    private static Result<AnnouncementInput> Fail(string error) => Result.Fail<AnnouncementInput>(error);
}
