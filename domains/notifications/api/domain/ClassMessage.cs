using System.Text.Json;

namespace Tsr.Notifications.Api.Domain;

/// <summary>A class notification's title, body and optional link, as <c>ClassNotificationsModel::message</c> leaves them (trimmed).</summary>
internal sealed record ClassMessageText(string Title, string Body, string? ActionLink);

/// <summary>
/// PHP's <c>ClassNotificationsModel::message</c>: the one rule for what a class notification may say, for a send-now and a scheduled one. Title 1 to 255 and body 1 to 2000
/// characters after trimming (characters are code points, as <c>mb_strlen</c>), link at most 500, rewritten to an in-app path only when asked (scheduling does), then the allow-list.
/// A NUL character in any text is refused (PostgreSQL cannot store it; PHP stores it).
/// </summary>
internal static class ClassMessage
{
    public const string TitleError = "title is required and must be at most 255 characters";
    public const string BodyError = "body is required and must be at most 2000 characters";
    public const string LinkLengthError = "action_link must be at most 500 characters";
    public const string LinkNotAllowedError = "action_link must be an https:// link or an in-app path such as /classes/12/syllabus";

    public static Result<ClassMessageText> Parse(JsonBody body, bool rewriteLink)
    {
        ArgumentNullException.ThrowIfNull(body);
        var title = Trimmed(body.Get("title"), 255);
        if (title is null)
        {
            return Result.Fail<ClassMessageText>(TitleError);
        }

        var text = Trimmed(body.Get("body"), 2000);
        if (text is null)
        {
            return Result.Fail<ClassMessageText>(BodyError);
        }

        var link = Link(body.Get("action_link"), rewriteLink);
        return link.IsSuccess
            ? Result.Ok(new ClassMessageText(title, text, link.Value))
            : Result.Fail<ClassMessageText>(link.Error!);
    }

    private static string? Trimmed(JsonElement value, int maxChars)
    {
        if (value.ValueKind != JsonValueKind.String)
        {
            return null;
        }

        var text = PhpText.Trim(value.GetString() ?? string.Empty);
        return text.Length == 0 || PhpText.CodePointCount(text) > maxChars || text.Contains('\0', StringComparison.Ordinal) ? null : text;
    }

    /// <summary>The link rule alone (a calendar event has a link and no title): absent, null or empty is no link.</summary>
    public static Result<string?> Link(JsonElement value, bool rewriteLink)
    {
        if (value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null || (value.ValueKind == JsonValueKind.String && value.GetString() == string.Empty))
        {
            return Result.Ok<string?>(null);
        }

        if (value.ValueKind != JsonValueKind.String)
        {
            return Result.Fail<string?>(LinkLengthError);
        }

        var link = value.GetString()!;
        if (PhpText.CodePointCount(link) > 500 || link.Contains('\0', StringComparison.Ordinal))
        {
            return Result.Fail<string?>(LinkLengthError);
        }

        if (rewriteLink)
        {
            link = ActionLinks.InApp(link);
        }

        return ActionLinks.Allowed(link) ? Result.Ok<string?>(link) : Result.Fail<string?>(LinkNotAllowedError);
    }
}
