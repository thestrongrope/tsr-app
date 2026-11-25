using System.Globalization;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// Readers the report queries need that <see cref="DbRow"/> has no method for: a <c>timestamp without time zone</c> that is never null, and a day that may be null
/// (selected as <c>to_char(day, 'YYYY-MM-DD')</c>, so the text is always in that form).
/// </summary>
internal static class ReportRead
{
    public static DateTime LocalTimestamp(this DbRow row, string column)
    {
        ArgumentNullException.ThrowIfNull(row);
        return row.LocalTimestampOrNull(column) ?? throw new DbShapeException($"column '{column}' is null; the report query never returns a null here");
    }

    public static DateOnly? DayOrNull(this DbRow row, string column)
    {
        ArgumentNullException.ThrowIfNull(row);
        var text = row.TextOrNull(column);
        return text is null ? null : DateOnly.ParseExact(text, "yyyy-MM-dd", CultureInfo.InvariantCulture);
    }
}
