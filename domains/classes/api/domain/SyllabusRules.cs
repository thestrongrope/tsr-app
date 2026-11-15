using System.Text.Json;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// The input rules of the admin syllabus routes (PHP routes/syllabus.php), apart from any database. Texts keep their spaces (trim only decides whether a required text is empty). Deviations from PHP, which
/// has no limits of its own: a text over its column, a NUL byte and a sort order outside a 32-bit integer are 422.
/// </summary>
internal static class SyllabusRules
{
    private const int MaxSubject = 150;
    private const int MaxDescription = 500;
    private const int MaxUrl = 1000;

    internal sealed record NewItemInput(long LevelId, string SubjectName, string Url, string LinkType, int SortOrder, string? Description);

    internal sealed record Edit(string? SubjectName, string? Description, string? LinkType, string? Url, int? SortOrder, int? IsActive)
    {
        public bool IsEmpty => SubjectName is null && Description is null && LinkType is null && Url is null && SortOrder is null && IsActive is null;
    }

    /// <summary>PHP: true, 1, yes, on or false, 0, no, off (trimmed, any case); empty or absent is false; anything else is refused.</summary>
    public static Result<bool> IncludeInactive(string? raw)
    {
        if (string.IsNullOrEmpty(raw))
        {
            return Result.Ok(false);
        }

        var value = PhpText.LowerAscii(PhpText.Trim(raw));
        return value switch
        {
            "true" or "1" or "yes" or "on" => Result.Ok(true),
            "false" or "0" or "no" or "off" => Result.Ok(false),
            _ => Result.Fail<bool>("Invalid include_inactive"),
        };
    }

    public static Result<NewItemInput> NewItem(JsonBody body)
    {
        ArgumentNullException.ThrowIfNull(body);
        var level = body.Get("level_id");
        if (!IsNumeric(level))
        {
            return Result.Fail<NewItemInput>("level_id is required");
        }

        var subject = body.Get("subject_name");
        if (!IsFilledText(subject))
        {
            return Result.Fail<NewItemInput>("subject_name is required");
        }

        var url = body.Get("url");
        if (!IsFilledText(url))
        {
            return Result.Fail<NewItemInput>("url is required");
        }

        var linkValue = Given(body, "link_type");
        var linkType = linkValue is { } link ? LinkTypeOf(link) : "pdf";
        if (linkType is null)
        {
            return Result.Fail<NewItemInput>("link_type must be 'pdf' or 'external'");
        }

        var sort = Given(body, "sort_order");
        if (sort is { } given && !IsNumeric(given))
        {
            return Result.Fail<NewItemInput>("sort_order must be an integer");
        }

        var description = body.Get("description");
        if (description.ValueKind is not (JsonValueKind.Null or JsonValueKind.Undefined or JsonValueKind.String))
        {
            return Result.Fail<NewItemInput>("description must be a string");
        }

        var sortOrder = sort is { } present ? SortOf(present) : 0;
        var text = description.ValueKind == JsonValueKind.String ? description.GetString() : null;
        var failure = sortOrder is null ? "sort_order must be an integer" : TextProblem("subject_name", subject.GetString()!, MaxSubject)
            ?? TextProblem("url", url.GetString()!, MaxUrl) ?? (text is null ? null : TextProblem("description", text, MaxDescription));
        return failure is not null
            ? Result.Fail<NewItemInput>(failure)
            : Result.Ok(new NewItemInput(PhpValue.ToInteger(level), subject.GetString()!, url.GetString()!, linkType, sortOrder!.Value, text));
    }

    public static Result<Edit> Changes(JsonBody body)
    {
        ArgumentNullException.ThrowIfNull(body);
        var subject = Given(body, "subject_name");
        if (subject is { } s && s.ValueKind != JsonValueKind.String)
        {
            return Result.Fail<Edit>("subject_name must be a string");
        }

        var description = Given(body, "description");
        if (description is { } d && d.ValueKind != JsonValueKind.String)
        {
            return Result.Fail<Edit>("description must be a string");
        }

        var linkValue = Given(body, "link_type");
        var linkType = linkValue is { } l ? LinkTypeOf(l) : null;
        if (linkValue is not null && linkType is null)
        {
            return Result.Fail<Edit>("link_type must be 'pdf' or 'external'");
        }

        var url = Given(body, "url");
        if (url is { } u && u.ValueKind != JsonValueKind.String)
        {
            return Result.Fail<Edit>("url must be a string");
        }

        var sortValue = Given(body, "sort_order");
        if (sortValue is { } sv && !IsNumeric(sv))
        {
            return Result.Fail<Edit>("sort_order must be an integer");
        }

        var sort = sortValue is { } sv2 ? SortOf(sv2) : null;
        var active = Given(body, "is_active");
        var edit = new Edit(subject?.GetString(), description?.GetString(), linkType, url?.GetString(), sort, active is { } a ? (IsTruthy(a) ? 1 : 0) : null);
        var failure = sortValue is not null && sort is null ? "sort_order must be an integer"
            : TextProblem("subject_name", edit.SubjectName, MaxSubject) ?? TextProblem("description", edit.Description, MaxDescription) ?? TextProblem("url", edit.Url, MaxUrl);
        return failure is not null ? Result.Fail<Edit>(failure) : Result.Ok(edit);
    }

    // A field is given when it is present and not null (PHP: array_key_exists and !== null).
    private static JsonElement? Given(JsonBody body, string field)
    {
        var value = body.Get(field);
        return value.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined ? null : value;
    }

    private static string? LinkTypeOf(JsonElement value) =>
        value.ValueKind == JsonValueKind.String && value.GetString() is "pdf" or "external" ? value.GetString() : null;

    private static bool IsFilledText(JsonElement value) =>
        value.ValueKind == JsonValueKind.String && PhpText.Trim(value.GetString()!).Length > 0;

    /// <summary>PHP is_numeric: a number, or text that reads as one.</summary>
    private static bool IsNumeric(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Number => true,
        JsonValueKind.String => PhpValue.IsNumeric(value.GetString()!),
        _ => false,
    };

    // (int) of a numeric value, null when it does not fit the column.
    private static int? SortOf(JsonElement value)
    {
        var number = PhpValue.ToInteger(value);
        return number is >= int.MinValue and <= int.MaxValue ? (int)number : null;
    }

    private static string? TextProblem(string field, string? value, int max)
    {
        if (value is null)
        {
            return null;
        }

        if (value.Contains('\0', StringComparison.Ordinal))
        {
            return field + " must not contain a NUL byte";
        }

        return PhpText.CodePointCount(value) > max ? $"{field} must be at most {max} characters" : null;
    }

    /// <summary>PHP truthiness of a decoded value: false, 0, 0.0, "", "0", null and an empty array are false.</summary>
    private static bool IsTruthy(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.True => true,
        JsonValueKind.Number => value.GetDouble() != 0,
        JsonValueKind.String => value.GetString() is not ("" or "0"),
        JsonValueKind.Array => value.GetArrayLength() > 0,
        JsonValueKind.Object => value.EnumerateObject().Any(),
        _ => false,
    };
}
