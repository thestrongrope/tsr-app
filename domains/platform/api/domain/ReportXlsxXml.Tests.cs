using NUnit.Framework;
using System.IO.Compression;
using System.Xml.Linq;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// Reads a workbook as a zip of XML parts, so a test sees what the file holds and not what a spreadsheet library makes of it
/// (an empty text cell, the text a number was written as, the quote prefix, the column widths).
/// It takes text from a shared string or an inline string and resolves a cell's style index, so one check suits any writer.
/// </summary>
internal sealed class XlsxXml
{
    private static readonly XNamespace Main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";

    private static readonly string[] XmlExtensions = [".xml", ".rels", ".psmdcp"];

    private readonly Dictionary<string, XDocument> _parts = [];
    private readonly Dictionary<string, byte[]> _raw = [];

    private XlsxXml(byte[] bytes)
    {
        using var zip = new ZipArchive(new MemoryStream(bytes), ZipArchiveMode.Read);
        foreach (var entry in zip.Entries)
        {
            using var stream = entry.Open();
            using var copy = new MemoryStream();
            stream.CopyTo(copy);
            _raw[entry.FullName] = copy.ToArray();
            if (XmlExtensions.Any(x => entry.FullName.EndsWith(x, StringComparison.Ordinal)))
            {
                _parts[entry.FullName] = XDocument.Load(new MemoryStream(copy.ToArray()));
            }
        }
    }

    public static XlsxXml Read(byte[] bytes) => new(bytes);

    public IReadOnlyCollection<string> PartNames => _raw.Keys;

    public const string CorePartName = "docProps/core.xml";

    public byte[] RawPart(string name) => _raw[name];

    public XDocument Part(string name) => _parts[name];

    public XDocument Sheet => _parts["xl/worksheets/sheet1.xml"];

    public XElement SheetElement(string name) => Sheet.Root!.Element(Main + name)!;

    public IReadOnlyList<XElement> Columns() => Sheet.Root!.Element(Main + "cols")?.Elements(Main + "col").ToList() ?? [];

    /// <summary>The width of each column 1 to the last, one entry per column: a col element may stand for a range (min to max).</summary>
    public IReadOnlyList<double> Widths()
    {
        var widths = new List<double>();
        foreach (var col in Columns())
        {
            var width = double.Parse((string)col.Attribute("width")!, System.Globalization.CultureInfo.InvariantCulture);
            var count = int.Parse((string)col.Attribute("max")!, System.Globalization.CultureInfo.InvariantCulture) - int.Parse((string)col.Attribute("min")!, System.Globalization.CultureInfo.InvariantCulture) + 1;
            widths.AddRange(Enumerable.Repeat(width, count));
        }

        return widths;
    }

    public XElement? CellElement(string address) =>
        Sheet.Root!.Descendants(Main + "c").SingleOrDefault(c => (string?)c.Attribute("r") == address);

    public bool HasCell(string address) => CellElement(address) is not null;

    public IReadOnlyList<string> CellAddresses() => Sheet.Root!.Descendants(Main + "c").Select(c => (string)c.Attribute("r")!).ToList();

    public XlsxCell Cell(string address)
    {
        var element = CellElement(address) ?? throw new AssertionException($"No cell {address} in sheet1.xml");
        var type = (string?)element.Attribute("t");
        var value = element.Element(Main + "v")?.Value;
        var style = int.Parse((string?)element.Attribute("s") ?? "0", System.Globalization.CultureInfo.InvariantCulture);
        return new XlsxCell(address, type, value, TextOf(element, type, value), style, StyleOf(style));
    }

    /// <summary>The font, wrap and quote prefix a style index (cellXfs) stands for.</summary>
    public XlsxStyle StyleOf(int index)
    {
        var styles = _parts["xl/styles.xml"].Root!;
        var xf = styles.Element(Main + "cellXfs")!.Elements(Main + "xf").ElementAt(index);
        var fontId = int.Parse((string?)xf.Attribute("fontId") ?? "0", System.Globalization.CultureInfo.InvariantCulture);
        var font = styles.Element(Main + "fonts")!.Elements(Main + "font").ElementAt(fontId);
        var bold = font.Element(Main + "b") is { } b && ((string?)b.Attribute("val") ?? "1") is not ("0" or "false");
        var size = double.Parse((string?)font.Element(Main + "sz")?.Attribute("val") ?? "0", System.Globalization.CultureInfo.InvariantCulture);
        var name = (string?)font.Element(Main + "name")?.Attribute("val");
        var color = (string?)font.Element(Main + "color")?.Attribute("rgb");
        var wrap = (string?)xf.Element(Main + "alignment")?.Attribute("wrapText") is "1" or "true";
        var quote = (string?)xf.Attribute("quotePrefix") is "1" or "true";
        return new XlsxStyle(bold, size, name, color, wrap, quote);
    }

    private string? TextOf(XElement cell, string? type, string? value)
    {
        if (type == "inlineStr")
        {
            return string.Concat(cell.Element(Main + "is")!.Elements(Main + "t").Select(t => t.Value));
        }

        if (type == "s")
        {
            var shared = _parts["xl/sharedStrings.xml"].Root!.Elements(Main + "si").ElementAt(int.Parse(value!, System.Globalization.CultureInfo.InvariantCulture));
            return string.Concat(shared.Elements(Main + "t").Select(t => t.Value));
        }

        return null;
    }
}

internal sealed record XlsxStyle(bool Bold, double Size, string? FontName, string? Color, bool Wrap, bool QuotePrefix);

/// <summary>One cell as the file holds it: Text is set for a text cell (shared or inline), Number for a cell without a type, Raw is the text of its value element.</summary>
internal sealed record XlsxCell(string Address, string? Type, string? Raw, string? Text, int StyleIndex, XlsxStyle Style)
{
    public bool IsText => Type is "s" or "inlineStr";

    public string? Number => IsText ? null : Raw;
}
