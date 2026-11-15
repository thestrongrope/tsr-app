using System.Text.Json;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Domain;

internal sealed record WhatsAppReminder(
    long Id, string Name, string Type, string Gender, string? City, string? Country, string Levels, string Lang,
    long LeewayDays, string Timezone, long? Weekday, string? SendTime, bool ScheduleOn, bool Enabled, string? UpdatedAt);

internal sealed record WhatsAppRun(
    long Id, long? ReminderId, string? FromDate, string? ToDate, string Status, long Sent, long Skipped, long Failed,
    bool DryRun, string? Error, string? StartedAt, string? FinishedAt);

internal sealed record WhatsAppMessage(string Mobile, string? Name, long? Missing, string? Excerpt, string Status, string? Error, string? SentAt);

/// <summary>
/// PHP's api_whatsapp_reminder, api_whatsapp_run and api_whatsapp_message (routes/whatsapp_reminders.php) with api_cast (lib/response.php): what a row of the notifier's answer becomes on the wire.
/// A missing field behaves as null; null or "" is null for a nullable type and the type's zero otherwise.
/// </summary>
internal static class NotifierRows
{
    public static WhatsAppReminder Reminder(JsonElement r) => new(
        Int(Field(r, "id")) ?? 0, Str(Field(r, "name")), Str(Field(r, "type")), Str(Field(r, "gender")),
        StrOrNull(Field(r, "city")), StrOrNull(Field(r, "country")), Str(Field(r, "levels")), Str(Field(r, "lang")),
        Int(Field(r, "leeway_days")) ?? 0, Str(Field(r, "timezone")), Int(Field(r, "weekday")), StrOrNull(Field(r, "send_time")),
        Bool(Field(r, "schedule_on")), Bool(Field(r, "enabled")), Utc(Field(r, "updated_at")));

    public static WhatsAppRun Run(JsonElement r) => new(
        Int(Field(r, "id")) ?? 0, Int(Field(r, "reminder_id")), Date(Field(r, "from_date")), Date(Field(r, "to_date")), Str(Field(r, "status")),
        Int(Field(r, "sent_count")) ?? 0, Int(Field(r, "skipped_count")) ?? 0, Int(Field(r, "failed_count")) ?? 0,
        Bool(Field(r, "dry_run")), Text(Field(r, "error_message")), Utc(Field(r, "started_at")), Utc(Field(r, "finished_at")));

    public static WhatsAppMessage Message(JsonElement m) => new(
        Str(Field(m, "teacher_mobile")), StrOrNull(Field(m, "teacher_name")), Int(Field(m, "total_missing")), Text(Field(m, "message_excerpt")),
        Str(Field(m, "status")), Text(Field(m, "error")), Utc(Field(m, "sent_at")));

    /// <summary>The rows of a decoded answer: its elements when it is an array, none otherwise (PHP would fail on a non-row element; the rows that are not objects are skipped here).</summary>
    public static IEnumerable<JsonElement> Rows(JsonElement data) =>
        data.ValueKind == JsonValueKind.Array ? data.EnumerateArray().Where(row => row.ValueKind == JsonValueKind.Object) : [];

    /// <summary>One named field of an object; <c>default</c> (a missing value) when absent or when the element is not an object.</summary>
    public static JsonElement Field(JsonElement row, string name) =>
        row.ValueKind == JsonValueKind.Object && row.TryGetProperty(name, out var value) ? value : default;

    /// <summary>PHP's <c>empty()</c> of a decoded value.</summary>
    public static bool PhpEmpty(JsonElement v) => v.ValueKind switch
    {
        JsonValueKind.Undefined or JsonValueKind.Null or JsonValueKind.False => true,
        JsonValueKind.String => v.GetString() is "" or "0",
        JsonValueKind.Number => v.GetDouble() == 0,
        JsonValueKind.Array => v.GetArrayLength() == 0,
        JsonValueKind.Object => !v.EnumerateObject().Any(),
        _ => false,
    };

    /// <summary>api_cast_value <c>int</c>: null for null, "" or a value that is not numeric.</summary>
    public static long? Int(JsonElement v)
    {
        if (IsBlank(v))
        {
            return null;
        }

        return v.ValueKind switch
        {
            JsonValueKind.Number => PhpValue.ToInteger(v),
            JsonValueKind.String when PhpValue.IsNumeric(v.GetString()!) => PhpValue.IntOfText(v.GetString()!),
            _ => null,
        };
    }

    public static string Str(JsonElement v) => IsBlank(v) ? string.Empty : PhpValue.Text(v);

    public static string? StrOrNull(JsonElement v) => IsBlank(v) ? null : PhpValue.Text(v);

    /// <summary><c>text?</c>: HTML entities decoded.</summary>
    public static string? Text(JsonElement v) => IsBlank(v) ? null : PhpText.HtmlDecode(PhpValue.Text(v));

    /// <summary><c>date?</c>: MySQL's zero date is null.</summary>
    public static string? Date(JsonElement v)
    {
        var s = StrOrNull(v);
        return s is "0000-00-00" or "0000-00-00 00:00:00" ? null : s;
    }

    /// <summary>api_cast_value <c>bool</c>: 1, "1", true, "true", "Y", "y" and the single byte "\x01".</summary>
    public static bool Bool(JsonElement v)
    {
        if (IsBlank(v))
        {
            return false;
        }

        return v.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.Number => PhpValue.IsInt(v, out var n) && n == 1,
            JsonValueKind.String => v.GetString() is "1" or "true" or "Y" or "y" or "\u0001",
            _ => false,
        };
    }

    /// <summary>api_whatsapp_utc: a stored UTC "Y-m-d H:i:s" as ISO-8601 with its Z; blank and the zero date are null.</summary>
    public static string? Utc(JsonElement v)
    {
        var stored = PhpText.Trim(IsBlank(v) ? string.Empty : PhpValue.Text(v));
        return stored.Length == 0 || stored.StartsWith("0000-00-00", StringComparison.Ordinal) ? null : stored.Replace(' ', 'T') + "Z";
    }

    private static bool IsBlank(JsonElement v) =>
        v.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null || (v.ValueKind == JsonValueKind.String && v.GetString()!.Length == 0);
}
