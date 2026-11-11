using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using ClosedXML.Excel;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// The workbook PHP wrote with PhpSpreadsheet (<c>ReportExportModel::xlsx</c>): one sheet, the title in bold at 14 points, then per section a bold
/// heading, a bold header row and the rows, with a blank row after each section. Numbers are numbers; every other value is text, so a member's
/// name that starts with = is shown as text and never runs as a formula. A null or empty value leaves the cell empty.
/// </summary>
internal static partial class ReportXlsx
{
    /// <summary>A cell holds 32767 characters; PhpSpreadsheet cuts longer text, ClosedXML throws, so it is cut here.</summary>
    private const int MaxCellCharacters = 32767;
    private const int MaxSheetName = 31;
    private const string FallbackSheetName = "Report";

    [GeneratedRegex(@"[\[\]:*?/\\]")]
    private static partial Regex ForbiddenInSheetName();

    /// <summary>Excel allows 31 characters, none of []:*? / \ and no apostrophe at either end (PHP replaces the forbidden ones with a space).</summary>
    public static string SheetName(string title)
    {
        ArgumentNullException.ThrowIfNull(title);
        var name = ForbiddenInSheetName().Replace(title, " ");
        if (name.Length > MaxSheetName)
        {
            var cut = char.IsHighSurrogate(name[MaxSheetName - 1]) ? MaxSheetName - 1 : MaxSheetName;
            name = name[..cut];
        }

        if (name.StartsWith('\''))
        {
            name = " " + name[1..];
        }

        if (name.EndsWith('\''))
        {
            name = name[..^1] + " ";
        }

        return string.IsNullOrWhiteSpace(name) ? FallbackSheetName : name;
    }

    public static byte[] Build(string title, IReadOnlyList<ReportSection> sections)
    {
        ArgumentNullException.ThrowIfNull(sections);
        using var book = new XLWorkbook();
        var sheet = book.Worksheets.Add(SheetName(title));

        var row = 1;
        var widest = 0;
        widest = Math.Max(widest, WriteRow(sheet, row, [title]));
        sheet.Cell(row, 1).Style.Font.Bold = true;
        sheet.Cell(row, 1).Style.Font.FontSize = 14;
        row += 2;

        foreach (var section in sections)
        {
            widest = Math.Max(widest, WriteRow(sheet, row, [section.Heading]));
            sheet.Cell(row, 1).Style.Font.Bold = true;
            row++;
            widest = Math.Max(widest, WriteRow(sheet, row, [.. section.Headers]));
            sheet.Range(row, 1, row, widest).Style.Font.Bold = true;
            row++;
            foreach (var values in section.Rows)
            {
                widest = Math.Max(widest, WriteRow(sheet, row, values));
                row++;
            }

            row++;
        }

        sheet.Columns(1, Math.Max(widest, 1)).AdjustToContents();
        using var stream = new MemoryStream();
        book.SaveAs(stream);
        return stream.ToArray();
    }

    /// <summary>One row of cells; returns the highest column written (0 when none).</summary>
    private static int WriteRow(IXLWorksheet sheet, int row, IReadOnlyList<object?> values)
    {
        var highest = 0;
        for (var i = 0; i < values.Count; i++)
        {
            var value = values[i];
            if (value is null || value is string { Length: 0 })
            {
                continue;
            }

            var cell = sheet.Cell(row, i + 1);
            if (ReportCell.IsNumber(value))
            {
                cell.Value = Convert.ToDouble(value, CultureInfo.InvariantCulture);
            }
            else
            {
                cell.Value = XmlSafe(ReportCell.Text(value));
            }

            highest = i + 1;
        }

        return highest;
    }

    /// <summary>Drops the characters XML 1.0 cannot carry (control characters other than tab, line feed and carriage return), which a workbook cannot hold either, and cuts the text to what a cell holds.</summary>
    private static string XmlSafe(string text)
    {
        var clean = new StringBuilder(text.Length);
        foreach (var rune in text.EnumerateRunes())
        {
            var code = rune.Value;
            if (code is 0x9 or 0xA or 0xD || (code >= 0x20 && code != 0xFFFE && code != 0xFFFF))
            {
                clean.Append(rune);
            }
        }

        if (clean.Length > MaxCellCharacters)
        {
            clean.Length = char.IsHighSurrogate(clean[MaxCellCharacters - 1]) ? MaxCellCharacters - 1 : MaxCellCharacters;
        }

        return clean.ToString();
    }
}
