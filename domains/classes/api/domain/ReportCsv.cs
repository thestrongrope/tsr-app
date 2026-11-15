using System.Buffers;
using System.Text;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>PHP's hand-built CSV of the reports (<c>MisModel::rowsToCsv</c> with <c>fputcsv</c> and no escape character, and <c>csvSafeCell</c>).</summary>
internal static class ReportCsv
{
    private const string FormulaStarts = "=+-@\t\r";
    private static readonly SearchValues<char> NeedsEnclosure = SearchValues.Create(",\"\n\r\t ");

    /// <summary>PHP <c>csvSafeCell</c>: a text that is not a number and starts with = + - @ tab or CR gets a leading quote, so a spreadsheet does not run it.</summary>
    public static string Cell(string value) =>
        value.Length > 0 && FormulaStarts.Contains(value[0], StringComparison.Ordinal) && !PhpValue.IsNumeric(value) ? "'" + value : value;

    /// <summary>The rows as CSV text (lines end with a line feed), or null when there are none, so nobody is handed an empty file. A null cell is empty.</summary>
    public static string? Build(IReadOnlyList<string> headers, IReadOnlyList<IReadOnlyList<string?>> rows)
    {
        ArgumentNullException.ThrowIfNull(headers);
        ArgumentNullException.ThrowIfNull(rows);
        if (rows.Count == 0)
        {
            return null;
        }

        var csv = new StringBuilder();
        AppendLine(csv, headers.Select(Cell));
        foreach (var row in rows)
        {
            AppendLine(csv, row.Select(cell => cell is null ? string.Empty : Cell(cell)));
        }

        return csv.ToString();
    }

    private static void AppendLine(StringBuilder csv, IEnumerable<string> fields)
    {
        csv.AppendJoin(',', fields.Select(Quote)).Append('\n');
    }

    // fputcsv encloses a field holding the delimiter, the enclosure, a line break, a tab or a space; enclosures are doubled.
    private static string Quote(string field) =>
        field.AsSpan().IndexOfAny(NeedsEnclosure) < 0 ? field : "\"" + field.Replace("\"", "\"\"", StringComparison.Ordinal) + "\"";
}
