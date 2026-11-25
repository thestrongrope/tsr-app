using System.Globalization;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// Reads a nullable <c>date</c> column, which <see cref="DbRow"/> has no reader for: the select gives the column as <c>to_char(col, 'YYYY-MM-DD')</c> text and this parses it.
/// </summary>
internal static class ClassFeatureRows
{
    public static DateOnly? DateOrNull(this DbRow row, string column) =>
        row.TextOrNull(column) is { } text ? DateOnly.ParseExact(text, "yyyy-MM-dd", CultureInfo.InvariantCulture) : null;
}
