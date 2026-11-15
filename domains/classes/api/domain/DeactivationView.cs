using System.Globalization;
using System.Text.Json;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP <c>ClassesModel::deactivatedClasses</c> and <c>deactivationLog</c>: how a closed class and a log row are shown. The audit details (JSON {type, effective_date, reason}) win; a class closed before the audit
/// log falls back to its own columns, comment and deleter. PHP's <c>??</c> falls through only on null, while its <c>!$x</c> tests also treat "" and "0" as missing: each fallback below says which it is.
/// </summary>
internal static class DeactivationView
{
    internal sealed record ClosedClass(
        int Id,
        string? Code,
        string? Level,
        int? Gender,
        string? Teacher,
        string? Details,
        DateOnly? CompletedOn,
        DateOnly? ShutdownOn,
        string? Comments,
        int? DeletedBy,
        DateTime? DeletedAt,
        string? PerformedByName,
        string? DeletedByName,
        DateTime? PerformedAt);

    internal sealed record Summary(int Id, string Code, string Level, int Gender, string Teacher, string Type, string EffectiveDate, string Reason, string PerformedBy, string? PerformedAt);

    internal sealed record LogRow(long Id, int ClassId, string? Code, int? Gender, string? Level, string? Details, int PerformedBy, string? PerformedByName, DateTime PerformedAt);

    internal sealed record LogEntry(long Id, string Code, string Level, int Gender, string Type, string EffectiveDate, string Reason, string PerformedBy, string? PerformedAt);

    public static Summary Summarise(ClosedClass row)
    {
        ArgumentNullException.ThrowIfNull(row);
        using var details = Parse(row.Details);
        var type = Field(details, "type");
        if (type is null or "" or "0")
        {
            type = row.CompletedOn is not null ? "completed" : row.ShutdownOn is not null ? "shutdown" : null;
        }

        var fallbackDate = row.CompletedOn ?? row.ShutdownOn;
        var performer = row.PerformedByName ?? row.DeletedByName;
        if (performer is null or "" or "0" && row.DeletedBy is not (null or 0))
        {
            performer = "#" + row.DeletedBy!.Value.ToString(CultureInfo.InvariantCulture);
        }

        return new Summary(
            row.Id,
            row.Code ?? string.Empty,
            row.Level ?? string.Empty,
            row.Gender ?? 0,
            row.Teacher ?? string.Empty,
            type ?? string.Empty,
            Field(details, "effective_date") ?? fallbackDate?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) ?? string.Empty,
            Field(details, "reason") ?? row.Comments ?? string.Empty,
            performer ?? string.Empty,
            Utc(row.PerformedAt ?? row.DeletedAt));
    }

    public static LogEntry LogOf(LogRow row)
    {
        ArgumentNullException.ThrowIfNull(row);
        using var details = Parse(row.Details);
        return new LogEntry(
            row.Id,
            row.Code ?? "#" + row.ClassId.ToString(CultureInfo.InvariantCulture),
            row.Level ?? string.Empty,
            row.Gender ?? 0,
            Field(details, "type") ?? string.Empty,
            Field(details, "effective_date") ?? string.Empty,
            Field(details, "reason") ?? string.Empty,
            row.PerformedByName ?? "#" + row.PerformedBy.ToString(CultureInfo.InvariantCulture),
            Utc(row.PerformedAt));
    }

    // PHP: !empty($details) ? json_decode($details, true) : null; text that is not a JSON object has no fields.
    private static JsonDocument? Parse(string? details)
    {
        if (details is null or "" or "0")
        {
            return null;
        }

        try
        {
            var document = JsonDocument.Parse(details);
            if (document.RootElement.ValueKind == JsonValueKind.Object)
            {
                return document;
            }

            document.Dispose();
            return null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    // $details[name] ?? null, as the text PHP's (string) makes of it.
    private static string? Field(JsonDocument? details, string name)
    {
        if (details is null || !details.RootElement.TryGetProperty(name, out var value) || value.ValueKind == JsonValueKind.Null)
        {
            return null;
        }

        return PhpValue.Text(value);
    }

    // api_deactivation_utc: the stored UTC value as ISO-8601 with its Z, null when there is none.
    private static string? Utc(DateTime? value) =>
        value?.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture);
}
