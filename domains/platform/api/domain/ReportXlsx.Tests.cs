using ClosedXML.Excel;
using NUnit.Framework;

namespace Tsr.Platform.Api.Domain;

[TestFixture]
internal sealed class ReportXlsxTests
{
    private static ReportSection Section(string heading, string[] headers, params object?[][] rows) =>
        new(heading, headers, rows.Select(r => (IReadOnlyList<object?>)r).ToList());

    private static XLWorkbook Open(byte[] bytes) => new(new MemoryStream(bytes));

    [Test]
    public void The_sheet_is_titled_the_title_with_the_characters_Excel_refuses_turned_into_spaces_and_cut_to_31()
    {
        Assert.That(ReportXlsx.SheetName("Active teachers: Gents"), Is.EqualTo("Active teachers  Gents"));
        Assert.That(ReportXlsx.SheetName("a[b]c:d*e?f/g\\h"), Is.EqualTo("a b c d e f g h"));
        Assert.That(ReportXlsx.SheetName(new string('x', 40)), Has.Length.EqualTo(31));
    }

    [Test]
    public void A_title_that_leaves_no_usable_name_gets_a_plain_one()
    {
        Assert.That(ReportXlsx.SheetName(string.Empty), Is.EqualTo("Report"));
        Assert.That(ReportXlsx.SheetName("'quoted'"), Is.EqualTo(" quoted "));
    }

    [Test]
    public void The_layout_is_title_then_per_section_heading_headers_rows_and_a_blank_row()
    {
        var bytes = ReportXlsx.Build("My title", [Section("Gents", ["Token", "Name"], [1, "A"], [2, "B"]), Section("Ladies", ["X"], ["y"])]);

        using var book = Open(bytes);
        var sheet = book.Worksheet(1);
        Assert.That(sheet.Name, Is.EqualTo("My title"));
        Assert.That(sheet.Cell("A1").GetString(), Is.EqualTo("My title"));
        Assert.That(sheet.Cell("A1").Style.Font.Bold, Is.True);
        Assert.That(sheet.Cell("A1").Style.Font.FontSize, Is.EqualTo(14));
        Assert.That(sheet.Cell("A3").GetString(), Is.EqualTo("Gents"));
        Assert.That(sheet.Cell("A3").Style.Font.Bold, Is.True);
        Assert.That(sheet.Cell("A4").GetString(), Is.EqualTo("Token"));
        Assert.That(sheet.Cell("B4").GetString(), Is.EqualTo("Name"));
        Assert.That(sheet.Cell("B4").Style.Font.Bold, Is.True);
        Assert.That(sheet.Cell("A5").GetString(), Is.EqualTo("1"));
        Assert.That(sheet.Cell("B6").GetString(), Is.EqualTo("B"));
        Assert.That(sheet.Cell("A7").IsEmpty(), Is.True);
        Assert.That(sheet.Cell("A8").GetString(), Is.EqualTo("Ladies"));
        Assert.That(sheet.Cell("A9").GetString(), Is.EqualTo("X"));
        Assert.That(sheet.Cell("A10").GetString(), Is.EqualTo("y"));
    }

    [Test]
    public void Numbers_are_numbers_and_every_other_value_is_text_and_null_or_empty_is_no_cell()
    {
        var bytes = ReportXlsx.Build("T", [Section("S", ["h", "h", "h", "h", "h"], [7, 2.5, "007", null, string.Empty])]);

        using var book = Open(bytes);
        var sheet = book.Worksheet(1);
        Assert.That(sheet.Cell("A5").DataType, Is.EqualTo(XLDataType.Number));
        Assert.That(sheet.Cell("A5").GetDouble(), Is.EqualTo(7));
        Assert.That(sheet.Cell("B5").DataType, Is.EqualTo(XLDataType.Number));
        Assert.That(sheet.Cell("B5").GetDouble(), Is.EqualTo(2.5));
        Assert.That(sheet.Cell("C5").DataType, Is.EqualTo(XLDataType.Text));
        Assert.That(sheet.Cell("C5").GetString(), Is.EqualTo("007"));
        Assert.That(sheet.Cell("D5").IsEmpty(), Is.True);
        Assert.That(sheet.Cell("E5").IsEmpty(), Is.True);
    }

    [Test]
    public void A_text_starting_with_an_equals_sign_is_stored_as_text_never_as_a_formula()
    {
        var bytes = ReportXlsx.Build("=HYPERLINK(\"http://x\",\"t\")", [Section("=1+1", ["=A1"], ["=HYPERLINK(\"http://evil\",\"click\")"], ["+cmd"], ["@SUM(1)"])]);

        using var book = Open(bytes);
        var sheet = book.Worksheet(1);
        foreach (var address in new[] { "A1", "A3", "A4", "A5" })
        {
            Assert.That(sheet.Cell(address).HasFormula, Is.False, address);
            Assert.That(sheet.Cell(address).DataType, Is.EqualTo(XLDataType.Text), address);
        }

        Assert.That(sheet.Cell("A5").GetString(), Is.EqualTo("=HYPERLINK(\"http://evil\",\"click\")"));
        Assert.That(sheet.Cell("A6").GetString(), Is.EqualTo("+cmd"));
    }

    [Test]
    public void Right_to_left_text_and_control_characters_do_not_break_the_file()
    {
        var bytes = ReportXlsx.Build("T", [Section("S", ["h"], ["محمد"], ["bad\u0001char"])]);

        using var book = Open(bytes);
        Assert.That(book.Worksheet(1).Cell("A5").GetString(), Is.EqualTo("محمد"));
        Assert.That(book.Worksheet(1).Cell("A6").GetString(), Is.EqualTo("badchar"));
    }

    [Test]
    public void A_text_longer_than_a_cell_can_hold_is_cut_to_32767_characters_instead_of_failing()
    {
        var bytes = ReportXlsx.Build("T", [Section("S", ["h"], [new string('x', 40000)])]);

        using var book = Open(bytes);
        Assert.That(book.Worksheet(1).Cell("A5").GetString(), Has.Length.EqualTo(32767));
    }

    [Test]
    public void The_file_is_an_xlsx_package()
    {
        var bytes = ReportXlsx.Build("T", []);
        Assert.That(bytes.Take(2).ToArray(), Is.EqualTo((byte[])[(byte)'P', (byte)'K']));
    }
}
