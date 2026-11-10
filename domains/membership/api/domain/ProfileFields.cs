using System.Text.Json;
using System.Text.RegularExpressions;

namespace Tsr.Membership.Api.Domain;

/// <summary>
/// The profile fields PATCH /me accepts and PHP's <c>api_validate_profile_field()</c> for each. Every pattern spells out its
/// ASCII classes (PCRE without /u is ASCII; .NET's <c>\d</c> and <c>\s</c> are Unicode), and <c>$</c> keeps PCRE's habit of
/// also matching before a final newline.
/// </summary>
internal static partial class ProfileFields
{
    /// <summary>The updatable fields in the order PHP validates them (the first error wins).</summary>
    public static readonly IReadOnlyList<string> Updatable = ["name", "gender", "age_range", "mobile", "country", "state", "city", "language", "zip"];

    private const int MinLength = 2;
    private const int MaxLength = 50;

    [GeneratedRegex(@"^\+?[0-9]{10,15}$", RegexOptions.CultureInvariant)]
    private static partial Regex Mobile();

    [GeneratedRegex(@"^[0-9A-Za-z \t\n\v\f\r-]{3,12}$", RegexOptions.CultureInvariant)]
    private static partial Regex Zip();

    [GeneratedRegex(@"[\x00-\x1F\x7F]", RegexOptions.CultureInvariant)]
    private static partial Regex ControlCharacter();

    /// <summary>The error message for a value, or null when it is valid. A null value is not validated.</summary>
    public static string? Validate(string field, JsonElement value)
    {
        if (value.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
        {
            return null;
        }

        return field switch
        {
            "gender" => PhpValue.Int(value) is 1 or 2 ? null : "Invalid gender value. Use 1 for Male, 2 for Female.",
            "language" => PhpValue.Int(value) is >= 1 and <= 3 ? null : "Invalid language value. Use 1 for English, 2 for Urdu, 3 for Gujarati.",
            "mobile" => IsEmptyString(value) || Mobile().IsMatch(PhpValue.Text(value)) ? null : "Invalid mobile number",
            "zip" => IsEmptyString(value) || Zip().IsMatch(PhpValue.Text(value)) ? null : "Invalid ZIP code",
            "name" or "city" or "state" or "country" => ValidateText(field, PhpValue.Text(value)),
            _ => null,
        };
    }

    // PHP's `$value === ''`: only the empty JSON string, not false or null.
    private static bool IsEmptyString(JsonElement value) => value.ValueKind == JsonValueKind.String && value.GetString()!.Length == 0;

    private static string? ValidateText(string field, string raw)
    {
        var text = PhpText.Trim(raw);
        if (text.Length == 0)
        {
            return PhpText.UcFirst(field) + " cannot be empty";
        }

        var length = PhpText.CodePointCount(text);
        if (length < MinLength)
        {
            return "Must be at least " + MinLength + " characters";
        }

        if (length > MaxLength)
        {
            return "Must be at most " + MaxLength + " characters";
        }

        return ControlCharacter().IsMatch(text) ? "Contains invalid characters" : null;
    }
}
