using Tsr.Shared.Api;
using System.Globalization;
using System.Text.Json;

namespace Tsr.Membership.Api.Domain;

/// <summary>What PHP's PDO makes of a request value when it binds it to a profile column.</summary>
internal static class ProfileColumns
{
    /// <summary>A text column: JSON null is NULL, anything else its string cast (true is "1", 1.9 is "1.9", an array is "Array").</summary>
    public static string? Text(JsonElement value) =>
        value.ValueKind == JsonValueKind.Null ? null : PhpValue.Text(value);

    /// <summary>
    /// The integer <c>language</c> column. MariaDB converts the bound text: a whole number as is, a decimal rounded half away from zero
    /// (2.5 is 3), and text that is not entirely a number refuses the write (a 500). Throws <see cref="InvalidOperationException"/> then.
    /// </summary>
    public static int Language(JsonElement value)
    {
        if (value.ValueKind == JsonValueKind.True)
        {
            return 1;
        }

        var text = value.ValueKind is JsonValueKind.String or JsonValueKind.Number ? PhpValue.Text(value) : null;
        if (text is null || !PhpValue.IsNumeric(text))
        {
            throw new InvalidOperationException("The language value is not a number: the database refuses it (PHP answers a 500).");
        }

        var number = double.Parse(text, NumberStyles.Float, CultureInfo.InvariantCulture);
        return checked((int)Math.Round(number, MidpointRounding.AwayFromZero));
    }
}
