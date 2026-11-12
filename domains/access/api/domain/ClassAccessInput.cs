using System.Text.Json;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Domain;

/// <summary>
/// What the class access routes read from a request before the model judges it (PHP routes/class_access.php api_class_access_*): the shape of each
/// field, each a 422 in PHP's words. The content (is this a valid condition, is the reason long enough) is <see cref="ClassAccessRules"/>.
/// </summary>
internal static class ClassAccessInput
{
    private static Outcome<T> Unprocessable<T>(string detail) => Outcome<T>.Fail(422, detail);

    /// <summary>The search term: text of at most 100 characters (missing is empty), a 422 for another type or a NUL byte (PostgreSQL cannot compare one).</summary>
    public static Outcome<string> Query(string? value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return Outcome<string>.Ok(string.Empty);
        }

        if (value.Contains('\0', StringComparison.Ordinal))
        {
            return Unprocessable<string>("q must be text");
        }

        var trimmed = PhpText.Trim(value);
        return Outcome<string>.Ok(PhpText.CodePointCount(trimmed) <= AdminMembers.MaxQueryLength
            ? trimmed
            : string.Concat(trimmed.EnumerateRunes().Take(AdminMembers.MaxQueryLength).Select(r => r.ToString())));
    }

    /// <summary>A text field of the body: missing or null is empty (the model refuses that), any other type is a 422.</summary>
    public static Outcome<string> Text(JsonBody body, string field) => PermissionGrants.TextField(body, field);

    /// <summary>The version the client saw: required text.</summary>
    public static Outcome<string> Version(JsonBody body) => RequiredText(body, "version");

    /// <summary>The hash of the classes the client was shown: required text. The model compares it.</summary>
    public static Outcome<string> PreviewHash(JsonBody body) => RequiredText(body, "previewHash");

    private static Outcome<string> RequiredText(JsonBody body, string field)
    {
        var value = body.Get(field);
        var text = value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;
        return text.Length == 0 ? Unprocessable<string>(field + " is required") : Outcome<string>.Ok(text);
    }

    /// <summary>The gender of a rule: a whole number, or left out for either. The model checks the range.</summary>
    public static Outcome<int?> Gender(JsonBody body)
    {
        var value = body.Get("gender");
        if (value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null)
        {
            return Outcome<int?>.Ok(null);
        }

        if (!PhpValue.IsInt(value, out var number))
        {
            return Unprocessable<int?>("gender must be a number");
        }

        // A number beyond int is no gender; the model refuses it with the range message.
        return Outcome<int?>.Ok(number is > int.MinValue and < int.MaxValue ? (int)number : 0);
    }

    /// <summary>The conditions of the body: a list (an empty object counts as an empty list, as PHP decodes it). Their content is the model's to judge.</summary>
    public static Outcome<IReadOnlyList<RawCondition>> Conditions(JsonBody body)
    {
        var value = body.Get("conditions");
        var isEmptyObject = value.ValueKind == JsonValueKind.Object && !value.EnumerateObject().Any();
        if (value.ValueKind != JsonValueKind.Array && !isEmptyObject)
        {
            return Unprocessable<IReadOnlyList<RawCondition>>("conditions must be a list");
        }

        var list = new List<RawCondition>();
        foreach (var item in isEmptyObject ? [] : value.EnumerateArray())
        {
            var one = Condition(item);
            if (one.Failed)
            {
                return Outcome<IReadOnlyList<RawCondition>>.Fail(one.Refusal!);
            }

            list.Add(one.Value!);
        }

        return Outcome<IReadOnlyList<RawCondition>>.Ok(list);
    }

    private static Outcome<RawCondition> Condition(JsonElement item)
    {
        var field = item.ValueKind == JsonValueKind.Object && item.TryGetProperty("field", out var f) && f.ValueKind == JsonValueKind.String ? f.GetString() : null;
        if (field is null)
        {
            return Unprocessable<RawCondition>("Each condition needs a field");
        }

        var negate = false;
        if (item.TryGetProperty("negate", out var n) && n.ValueKind != JsonValueKind.Null)
        {
            if (n.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
            {
                return Unprocessable<RawCondition>("negate must be true or false");
            }

            negate = n.ValueKind == JsonValueKind.True;
        }

        item.TryGetProperty("value", out var value);
        if (value.ValueKind == JsonValueKind.String)
        {
            return Outcome<RawCondition>.Ok(new RawCondition(field, negate, value.GetString(), null));
        }

        return PhpValue.IsInt(value, out var number)
            ? Outcome<RawCondition>.Ok(new RawCondition(field, negate, null, number))
            : Unprocessable<RawCondition>("Each condition needs a value");
    }
}
