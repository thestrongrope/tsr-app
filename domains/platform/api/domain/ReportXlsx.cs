using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// The workbook PHP wrote with PhpSpreadsheet (<c>ReportExportModel::xlsx</c>): one sheet, the title in bold at 14 points, then per section a bold
/// heading, a bold header row and the rows, with a blank row after each section. Numbers are numbers; every other value is text, so a member's
/// name that starts with = is shown as text and never runs as a formula. A null or empty value leaves the cell empty.
/// </summary>
internal static partial class ReportXlsx
{
    /// <summary>A cell holds 32767 characters; PhpSpreadsheet cuts longer text and a workbook cannot hold more, so it is cut here.</summary>
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

    private const string MainNamespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
    private const int MaxColumnWidth = 255;
    private const string RelationshipsNamespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";

    private static readonly UTF8Encoding Utf8 = new(encoderShouldEmitUTF8Identifier: false);

    private static readonly XmlWriterSettings WriterSettings = new()
    {
        Encoding = Utf8,
        NewLineHandling = NewLineHandling.None,
        CloseOutput = false,
    };

    private enum RowKind { Title, Heading, Header, Data }

    /// <summary>One row of the sheet that holds at least one cell, in order. Columns is how many cells it holds, counted from column A.</summary>
    private readonly record struct SheetRow(int Number, RowKind Kind, IReadOnlyList<object?> Values, int Columns);

    /// <summary>What a value is in the file: text cleaned and with line feeds (or the G15 text of a number), and whether the text had an apostrophe removed (Quote) or a line feed (Wrap).</summary>
    private readonly record struct CellContent(string Text, bool IsNumber, bool Quote, bool Wrap);

    /// <summary>
    /// The workbook as an xlsx package, written straight into a zip with <see cref="XmlWriter"/> (no library). Two passes over the sections, no cell list:
    /// pass 1 finds the widest column and the longest line of each column (the widths come before the rows), pass 2 writes the rows.
    /// </summary>
    public static byte[] Build(string title, IReadOnlyList<ReportSection> sections)
    {
        ArgumentNullException.ThrowIfNull(sections);
        var sheetName = SheetName(title);
        var rows = Rows(title, sections).ToList();
        using var output = new MemoryStream();
        using (var zip = new ZipArchive(output, ZipArchiveMode.Create, leaveOpen: true))
        {
            WriteText(zip, "[Content_Types].xml", ContentTypesXml);
            WriteText(zip, "_rels/.rels", PackageRelationshipsXml);
            WriteXml(zip, "docProps/app.xml", w => WriteApp(w, sheetName));
            WriteText(zip, "docProps/core.xml", CoreXml(DateTime.UtcNow));
            WriteXml(zip, "xl/workbook.xml", w => WriteWorkbook(w, sheetName));
            WriteText(zip, "xl/_rels/workbook.xml.rels", WorkbookRelationshipsXml);
            WriteText(zip, "xl/styles.xml", StylesXml);
            WriteText(zip, "xl/theme/theme1.xml", ThemeXml);
            WriteXml(zip, "xl/worksheets/sheet1.xml", w => WriteSheet(w, rows));
        }

        return output.ToArray();
    }

    private static void WriteText(ZipArchive zip, string name, string xml)
    {
        using var stream = zip.CreateEntry(name).Open();
        stream.Write(Utf8.GetBytes(xml));
    }

    private static void WriteXml(ZipArchive zip, string name, Action<XmlWriter> write)
    {
        using var stream = zip.CreateEntry(name).Open();
        using var writer = XmlWriter.Create(stream, WriterSettings);
        writer.WriteStartDocument(standalone: true);
        write(writer);
        writer.WriteEndDocument();
    }

    private static string Inv(FormattableString text) => FormattableString.Invariant(text);

    /// <summary>The fixed parts of an element are written raw; the text that comes from a report goes through <see cref="XmlWriter.WriteString"/>, which refuses a character XML cannot carry.</summary>
    private static void WriteTextElement(XmlWriter w, string tag, string text)
    {
        w.WriteRaw($"<{tag}>");
        w.WriteString(text);
        w.WriteRaw($"</{tag}>");
    }

    private static string CoreXml(DateTime utc)
    {
        var stamp = utc.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture);
        return $"{XmlDeclaration}<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dcterms=\"http://purl.org/dc/terms/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><dcterms:created xsi:type=\"dcterms:W3CDTF\">{stamp}</dcterms:created><dcterms:modified xsi:type=\"dcterms:W3CDTF\">{stamp}</dcterms:modified></cp:coreProperties>";
    }

    /// <summary>The properties as the first (ClosedXML) writer listed them: the sheet and its two print names, and a count of two named ranges (the workbook defines none).</summary>
    private static void WriteApp(XmlWriter w, string sheetName)
    {
        w.WriteStartElement("ap", "Properties", "http://schemas.openxmlformats.org/officeDocument/2006/extended-properties");
        w.WriteAttributeString("xmlns", "vt", null, "http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes");
        w.WriteRaw(AppBeforeTitles);
        WriteTextElement(w, "vt:lpstr", sheetName);
        WriteTextElement(w, "vt:lpstr", sheetName + "!Print_Area");
        WriteTextElement(w, "vt:lpstr", sheetName + "!Print_Titles");
        w.WriteRaw(AppAfterTitles);
        w.WriteEndElement();
    }

    private static void WriteWorkbook(XmlWriter w, string sheetName)
    {
        w.WriteStartElement("workbook", MainNamespace);
        w.WriteAttributeString("xmlns", "r", null, RelationshipsNamespace);
        w.WriteRaw(WorkbookBeforeSheet);
        w.WriteStartElement("sheet");
        WriteNameAttribute(w, sheetName);
        w.WriteAttributeString("sheetId", "1");
        w.WriteAttributeString("r", "id", RelationshipsNamespace, "rId1");
        w.WriteEndElement();
        w.WriteRaw(WorkbookAfterSheet);
        w.WriteEndElement();
    }

    /// <summary>A reader turns a raw tab or line end in an attribute into a space, so they are written as character references (<c>&amp;#x9;</c>, <c>&amp;#xA;</c>).</summary>
    private static void WriteNameAttribute(XmlWriter w, string name)
    {
        w.WriteStartAttribute("name");
        var start = 0;
        for (var i = 0; i < name.Length; i++)
        {
            if (name[i] is not ('\t' or '\n' or '\r'))
            {
                continue;
            }

            w.WriteString(name[start..i]);
            w.WriteCharEntity(name[i]);
            start = i + 1;
        }

        w.WriteString(name[start..]);
        w.WriteEndAttribute();
    }

    /// <summary>The rows that hold a cell, in sheet order: the title, then per section a heading, a header row and the data rows, with a blank row after each section.</summary>
    private static IEnumerable<SheetRow> Rows(string title, IReadOnlyList<ReportSection> sections)
    {
        var row = 1;
        var widest = HighestColumn([title]);
        yield return new SheetRow(row, RowKind.Title, [title], 1);
        row += 2;
        foreach (var section in sections)
        {
            widest = Math.Max(widest, HighestColumn([section.Heading]));
            yield return new SheetRow(row++, RowKind.Heading, [section.Heading], 1);
            widest = Math.Max(widest, HighestColumn(section.Headers));
            if (widest > 0)
            {
                yield return new SheetRow(row, RowKind.Header, [.. section.Headers], widest);
            }

            row++;
            foreach (var values in section.Rows)
            {
                var columns = HighestColumn(values);
                widest = Math.Max(widest, columns);
                if (columns > 0)
                {
                    yield return new SheetRow(row, RowKind.Data, values, columns);
                }

                row++;
            }

            row++;
        }
    }

    /// <summary>The highest column holding a value (0 when none): a null and an empty text write no cell.</summary>
    private static int HighestColumn(IReadOnlyList<object?> values)
    {
        for (var i = values.Count - 1; i >= 0; i--)
        {
            if (values[i] is not (null or string { Length: 0 }))
            {
                return i + 1;
            }
        }

        return 0;
    }

    private static int FontOf(RowKind kind) => kind switch
    {
        RowKind.Title => 1,
        RowKind.Data => 0,
        _ => 2,
    };

    /// <summary>Null for a null or an empty text (no cell). Cleaning runs first, then the apostrophe rule; wrap is decided before a carriage return becomes a line feed.</summary>
    private static CellContent? Content(object? value)
    {
        if (value is null or string { Length: 0 })
        {
            return null;
        }

        if (ReportCell.IsNumber(value))
        {
            return new CellContent(Convert.ToDouble(value, CultureInfo.InvariantCulture).ToString("G15", CultureInfo.InvariantCulture), true, false, false);
        }

        var text = XmlSafe(ReportCell.Text(value));
        var quote = text.StartsWith('\'');
        if (quote)
        {
            text = text[1..];
        }

        return new CellContent(LineFeeds(text), false, quote, text.Contains('\n'));
    }

    /// <summary>A line end is a line feed (<c>\r\n</c> and a lone <c>\r</c> both become one), so no reader depends on how <see cref="XmlWriter"/> writes newlines.</summary>
    private static string LineFeeds(string text) => text.Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n');

    /// <summary>The length in UTF-16 units of the longest line (split on line feed).</summary>
    private static int LongestLine(string text)
    {
        var longest = 0;
        var start = 0;
        for (var end = text.IndexOf('\n', StringComparison.Ordinal); end >= 0; end = text.IndexOf('\n', start))
        {
            longest = Math.Max(longest, end - start);
            start = end + 1;
        }

        return Math.Max(longest, text.Length - start);
    }

    /// <summary>Pass 1: the longest line of any cell in each column.</summary>
    private static int[] LongestLines(List<SheetRow> rows, int columns)
    {
        var longest = new int[columns];
        foreach (var row in rows)
        {
            for (var i = 0; i < row.Values.Count; i++)
            {
                if (Content(row.Values[i]) is { } content)
                {
                    longest[i] = Math.Max(longest[i], LongestLine(content.Text));
                }
            }
        }

        return longest;
    }

    private static void WriteSheet(XmlWriter w, List<SheetRow> rows)
    {
        var columns = rows.Max(r => r.Columns);
        var longest = LongestLines(rows, columns);
        w.WriteStartElement("worksheet", MainNamespace);
        w.WriteRaw(SheetBeforeDimension);
        w.WriteRaw(Inv($"<dimension ref=\"A1:{ColumnName(columns)}{rows[^1].Number}\"/>"));
        w.WriteRaw(SheetBeforeColumns);
        for (var column = 1; column <= columns; column++)
        {
            w.WriteRaw(Inv($"<col min=\"{column}\" max=\"{column}\" width=\"{Math.Min(MaxColumnWidth, longest[column - 1] + 2)}\" customWidth=\"1\"/>"));
        }

        w.WriteRaw("</cols><sheetData>");
        foreach (var row in rows)
        {
            WriteRow(w, row);
        }

        w.WriteRaw("</sheetData>");
        w.WriteRaw(SheetAfterData);
        w.WriteEndElement();
    }

    /// <summary>A header row holds a cell for every column up to the widest so far, empty ones included (bold); a data row holds only the cells that have a value.</summary>
    private static void WriteRow(XmlWriter w, SheetRow row)
    {
        w.WriteRaw(Inv($"<row r=\"{row.Number}\">"));
        for (var column = 0; column < row.Columns; column++)
        {
            var content = column < row.Values.Count ? Content(row.Values[column]) : null;
            if (content is null && row.Kind == RowKind.Data)
            {
                continue;
            }

            WriteCell(w, $"{ColumnName(column + 1)}{row.Number}", FontOf(row.Kind), content);
        }

        w.WriteRaw("</row>");
    }

    /// <summary>The style index is the font, plus 3 when the text wraps, plus 6 when an apostrophe was removed (the 12 cell formats of the style sheet).</summary>
    private static void WriteCell(XmlWriter w, string address, int font, CellContent? content)
    {
        var style = font + (content is { Wrap: true } ? 3 : 0) + (content is { Quote: true } ? 6 : 0);
        var styleAttribute = style == 0 ? string.Empty : Inv($" s=\"{style}\"");
        if (content is not { } cell)
        {
            w.WriteRaw($"<c r=\"{address}\"{styleAttribute}/>");
            return;
        }

        if (cell.IsNumber)
        {
            w.WriteRaw($"<c r=\"{address}\"{styleAttribute}><v>{cell.Text}</v></c>");
            return;
        }

        w.WriteRaw($"<c r=\"{address}\"{styleAttribute} t=\"inlineStr\"><is><t xml:space=\"preserve\">");
        w.WriteString(cell.Text);
        w.WriteRaw("</t></is></c>");
    }

    /// <summary>A, B, ... Z, AA, AB ...</summary>
    private static string ColumnName(int column)
    {
        var name = new StringBuilder();
        for (var n = column; n > 0; n = (n - 1) / 26)
        {
            name.Insert(0, (char)('A' + ((n - 1) % 26)));
        }

        return name.ToString();
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
