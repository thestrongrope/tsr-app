using ClosedXML.Excel;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Validation;
using NUnit.Framework;

namespace Tsr.Platform.Api.Domain;

/// <summary>The signature of <see cref="ReportXlsx.Build"/>, so a test runs on both writers until the swap (plan, tasks 4 to 8).</summary>
internal delegate byte[] BuildFunc(string title, IReadOnlyList<ReportSection> sections);

[TestFixture]
internal sealed class ReportXlsxTests
{
    private static IEnumerable<TestCaseData> Builders()
    {
        yield return new TestCaseData(new BuildFunc(ReportXlsx.Build)).SetArgDisplayNames("Build");
        yield return new TestCaseData(new BuildFunc(ReportXlsx.BuildNew)).SetArgDisplayNames("BuildNew");
    }

    /// <summary>Every case on each writer: the writer is the first argument.</summary>
    private static IEnumerable<TestCaseData> EachBuilder(IEnumerable<TestCaseData> cases) =>
        cases.SelectMany(
            _ => Builders(),
            (c, b) => new TestCaseData([b.Arguments[0], .. c.Arguments]).SetArgDisplayNames(((BuildFunc)b.Arguments[0]!).Method.Name, c.TestName ?? string.Join(" / ", c.Arguments.Select(a => Convert.ToString(a, System.Globalization.CultureInfo.InvariantCulture)))));

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

    [TestCaseSource(nameof(Builders))]
    public void The_layout_is_title_then_per_section_heading_headers_rows_and_a_blank_row(BuildFunc build)
    {
        var bytes = build("My title", [Section("Gents", ["Token", "Name"], [1, "A"], [2, "B"]), Section("Ladies", ["X"], ["y"])]);

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

    [TestCaseSource(nameof(Builders))]
    public void Numbers_are_numbers_and_every_other_value_is_text_and_null_or_empty_is_no_cell(BuildFunc build)
    {
        var bytes = build("T", [Section("S", ["h", "h", "h", "h", "h"], [7, 2.5, "007", null, string.Empty])]);

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

    [TestCaseSource(nameof(Builders))]
    public void A_text_starting_with_an_equals_sign_is_stored_as_text_never_as_a_formula(BuildFunc build)
    {
        var bytes = build("=HYPERLINK(\"http://x\",\"t\")", [Section("=1+1", ["=A1"], ["=HYPERLINK(\"http://evil\",\"click\")"], ["+cmd"], ["@SUM(1)"])]);

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

    [TestCaseSource(nameof(Builders))]
    public void Right_to_left_text_and_control_characters_do_not_break_the_file(BuildFunc build)
    {
        var bytes = build("T", [Section("S", ["h"], ["محمد"], ["bad\u0001char"])]);

        using var book = Open(bytes);
        Assert.That(book.Worksheet(1).Cell("A5").GetString(), Is.EqualTo("محمد"));
        Assert.That(book.Worksheet(1).Cell("A6").GetString(), Is.EqualTo("badchar"));
    }

    [TestCaseSource(nameof(Builders))]
    public void A_text_longer_than_a_cell_can_hold_is_cut_to_32767_characters_instead_of_failing(BuildFunc build)
    {
        var bytes = build("T", [Section("S", ["h"], [new string('x', 40000)])]);

        using var book = Open(bytes);
        Assert.That(book.Worksheet(1).Cell("A5").GetString(), Has.Length.EqualTo(32767));
    }

    [TestCaseSource(nameof(Builders))]
    public void The_file_is_an_xlsx_package(BuildFunc build)
    {
        var bytes = build("T", []);
        Assert.That(bytes.Take(2).ToArray(), Is.EqualTo((byte[])[(byte)'P', (byte)'K']));
    }

    // ---- Characterisation of today's file (task 3). Each reads the parts of the workbook, not ClosedXML's view of them. ----

    private static readonly string[] FixedPartNames =
    [
        "[Content_Types].xml", "_rels/.rels", "docProps/app.xml", "xl/workbook.xml", "xl/_rels/workbook.xml.rels",
        "xl/sharedStrings.xml", "xl/styles.xml", "xl/theme/theme1.xml", "xl/worksheets/sheet1.xml",
    ];

    private static readonly string[] SheetElementOrder = ["sheetPr", "dimension", "sheetViews", "sheetFormatPr", "cols", "sheetData", "printOptions", "pageMargins", "pageSetup", "headerFooter", "tableParts"];
    private static readonly string[] OnlyA1 = ["A1"];
    private static readonly string[] EmptyTextAddresses = ["C5", "D5", "E5", "F5"];
    private static readonly string[] TitleHeadingAndTwoHeaders = ["A1", "A3", "A4", "B4"];
    private static readonly bool[] FontBold = [false, true, true];
    private static readonly string[] FontSizes = ["11", "14", "11"];
    private static readonly string[] MarginNames = ["left", "right", "top", "bottom", "header", "footer"];
    private static readonly string[] MarginValues = ["0.75", "0.75", "0.75", "0.5", "0.5", "0.75"];
    private static readonly string[] CorePropertyElements = ["coreProperties", "created", "modified"];
    private static readonly string[] WorksheetAndNamedRangeCounts = ["1", "2"];
    private static readonly double[] LimitWidths = [7, 6, 255];
    private static readonly double[] AccessLogWidths = [44, 18, 27, 27];
    private static readonly double[] TitleOnlyWidth = [24];
    private static readonly double[] LineNumberEmptyAndCarriageReturnWidths = [6, 2, 9, 6];

    private static XlsxXml Read(string title, params ReportSection[] sections) => Read(ReportXlsx.Build, title, sections);

    private static XlsxXml Read(BuildFunc build, string title, params ReportSection[] sections) => XlsxXml.Read(build(title, sections));

    private static XlsxXml One(BuildFunc build, object? value) => Read(build, "T", Section("S", ["h"], [value]));

    private static XlsxCell CellOf(BuildFunc build, object? value) => One(build, value).Cell("A5");

    private static string Rep(char c, int count) => new(c, count);

    [Test]
    public void The_package_holds_these_ten_parts_and_the_core_properties_part_has_a_random_name()
    {
        var names = Read("T", Section("S", ["h"], ["x"])).PartNames.ToList();

        Assert.That(names, Has.Count.EqualTo(10));
        Assert.That(names, Is.SupersetOf(FixedPartNames));
        Assert.That(names.Single(n => n.StartsWith("package/services/metadata/core-properties/", StringComparison.Ordinal)), Does.EndWith(".psmdcp"));
    }

    private static readonly string[] NewPartNames =
    [
        "[Content_Types].xml", "_rels/.rels", "docProps/app.xml", "docProps/core.xml", "xl/workbook.xml", "xl/_rels/workbook.xml.rels",
        "xl/styles.xml", "xl/theme/theme1.xml", "xl/worksheets/sheet1.xml",
    ];

    [Test]
    public void The_new_package_holds_these_nine_parts_with_fixed_names_and_no_byte_order_mark()
    {
        var xml = Read(ReportXlsx.BuildNew, "T", Section("S", ["h"], ["x"]));

        Assert.That(xml.PartNames, Is.EquivalentTo(NewPartNames));
        foreach (var name in xml.PartNames)
        {
            Assert.That(xml.RawPart(name).Take(3).ToArray(), Is.Not.EqualTo((byte[])[0xEF, 0xBB, 0xBF]), name);
        }
    }

    [TestCaseSource(nameof(Builders))]
    public void The_sheet_holds_its_elements_in_this_order_and_an_empty_tableParts_may_be_left_out(BuildFunc build)
    {
        var order = Read(build, "T", Section("S", ["h"], ["x"])).Sheet.Root!.Elements().Select(e => e.Name.LocalName);

        Assert.That(order, Is.EqualTo(SheetElementOrder.Where(n => n != "tableParts")).Or.EqualTo(SheetElementOrder));
    }

    [TestCaseSource(nameof(Builders))]
    public void Header_rows_hold_empty_bold_cells_up_to_the_widest_column_so_far(BuildFunc build)
    {
        var xml = Read(build, "T", Section("A", ["a", "b", "c", "d", "e"], ["1", "2", "3", "4", "5"]), Section("B", ["only"]));

        Assert.That(xml.Cell("A8").Text, Is.EqualTo("only"));
        foreach (var address in new[] { "B8", "C8", "D8", "E8" })
        {
            var cell = xml.Cell(address);
            Assert.That(cell.Type, Is.Null, address);
            Assert.That(cell.Raw, Is.Null, address);
            Assert.That(cell.Style.Bold, Is.True, address);
        }

        Assert.That(xml.HasCell("F8"), Is.False);
    }

    [TestCaseSource(nameof(Builders))]
    public void A_sheet_of_30_columns_reaches_column_AD(BuildFunc build)
    {
        var headers = Enumerable.Range(1, 30).Select(i => $"h{i}").ToArray();
        var xml = Read(build, "T", Section("S", headers, Enumerable.Range(1, 30).Select(i => (object?)i).ToArray()));

        Assert.That(xml.HasCell("AD5"), Is.True);
        Assert.That(xml.HasCell("AE5"), Is.False);
        Assert.That(xml.Cell("AD4").Text, Is.EqualTo("h30"));
        Assert.That(xml.SheetElement("dimension").Attribute("ref")!.Value, Is.EqualTo("A1:AD5"));
        Assert.That(xml.Widths(), Has.Count.EqualTo(30));
    }

    private static IEnumerable<TestCaseData> NumberCasesOnEachBuilder() => EachBuilder(NumberCases());

    private static IEnumerable<TestCaseData> NotNumberCasesOnEachBuilder() => EachBuilder(NotNumberCases());

    private static IEnumerable<TestCaseData> OtherValueCasesOnEachBuilder() => EachBuilder(OtherValueCases());

    private static IEnumerable<TestCaseData> UnicodeCasesOnEachBuilder() => EachBuilder(UnicodeCases());

    private static IEnumerable<TestCaseData> NumberCases()
    {
        yield return new TestCaseData((byte)7, "7").SetName("byte");
        yield return new TestCaseData((sbyte)-7, "-7").SetName("sbyte");
        yield return new TestCaseData((short)300, "300").SetName("short");
        yield return new TestCaseData((ushort)65535, "65535").SetName("ushort");
        yield return new TestCaseData(7, "7").SetName("int");
        yield return new TestCaseData(uint.MaxValue, "4294967295").SetName("uint");
        yield return new TestCaseData(-3L, "-3").SetName("long");
        yield return new TestCaseData(9000000000L, "9000000000").SetName("long over int");
        yield return new TestCaseData(ulong.MaxValue, "1.84467440737096E+19").SetName("ulong");
        yield return new TestCaseData(1.50m, "1.5").SetName("decimal");
        yield return new TestCaseData(decimal.MaxValue, "7.92281625142643E+28").SetName("decimal max");
        yield return new TestCaseData(0.1f, "0.100000001490116").SetName("float 0.1");
        yield return new TestCaseData(2.5f, "2.5").SetName("float 2.5");
        yield return new TestCaseData(0.1, "0.1").SetName("double 0.1");
        yield return new TestCaseData(2.5, "2.5").SetName("double 2.5");
        yield return new TestCaseData(-0.0, "-0").SetName("double negative zero");
        yield return new TestCaseData(1.0 / 3, "0.333333333333333").SetName("double one third");
    }

    [TestCaseSource(nameof(NumberCasesOnEachBuilder))]
    public void A_number_is_written_with_fifteen_significant_digits(BuildFunc build, object value, string written)
    {
        var cell = CellOf(build, value);

        Assert.That(cell.IsText, Is.False);
        Assert.That(cell.Type, Is.Null);
        Assert.That(cell.Raw, Is.EqualTo(written));
    }

    private static IEnumerable<TestCaseData> NotNumberCases()
    {
        yield return new TestCaseData(double.NaN, "NaN").SetName("double NaN");
        yield return new TestCaseData(double.PositiveInfinity, "Infinity").SetName("double +infinity");
        yield return new TestCaseData(double.NegativeInfinity, "-Infinity").SetName("double -infinity");
        yield return new TestCaseData(float.NaN, "NaN").SetName("float NaN");
        yield return new TestCaseData(float.PositiveInfinity, "Infinity").SetName("float +infinity");
        yield return new TestCaseData(float.NegativeInfinity, "-Infinity").SetName("float -infinity");
    }

    [TestCaseSource(nameof(NotNumberCasesOnEachBuilder))]
    public void Every_number_type_is_a_number_and_nan_and_infinity_are_text(BuildFunc build, object value, string text)
    {
        var cell = CellOf(build, value);

        Assert.That(cell.IsText, Is.True);
        Assert.That(cell.Text, Is.EqualTo(text));
        Assert.That(cell.Raw, Is.Not.EqualTo(text), "the cell holds a string reference or inline text, not the number text");
    }

    private static IEnumerable<TestCaseData> OtherValueCases()
    {
        yield return new TestCaseData(true, "1").SetName("true");
        yield return new TestCaseData(new DateTime(2026, 1, 2, 3, 4, 5), "01/02/2026 03:04:05").SetName("date and time");
        yield return new TestCaseData(new DateOnly(2026, 1, 2), "01/02/2026").SetName("date");
        yield return new TestCaseData(Guid.Parse("A1B2C3D4-0000-4000-8000-0000000000AB"), "a1b2c3d4-0000-4000-8000-0000000000ab").SetName("guid");
    }

    [TestCaseSource(nameof(OtherValueCasesOnEachBuilder))]
    public void Other_values_are_their_invariant_text(BuildFunc build, object value, string text)
    {
        var cell = CellOf(build, value);

        Assert.That(cell.IsText, Is.True);
        Assert.That(cell.Text, Is.EqualTo(text));
    }

    private static readonly string[] FormulaSigns = ["=1+1", "+cmd", "-2+3", "@SUM(1)", "=HYPERLINK(\"http://evil\",\"click\")"];

    private static IEnumerable<TestCaseData> FormulaTexts() => EachBuilder(FormulaSigns.Select(t => new TestCaseData(t)));

    [TestCaseSource(nameof(FormulaTexts))]
    public void A_text_starting_with_a_formula_sign_is_text_and_the_sheet_has_no_formula_element(BuildFunc build, string text)
    {
        var xml = Read(build, text, Section(text, [text], [text]));

        foreach (var address in new[] { "A1", "A3", "A4", "A5" })
        {
            Assert.That(xml.Cell(address).IsText, Is.True, address);
            Assert.That(xml.Cell(address).Text, Is.EqualTo(text), address);
        }

        Assert.That(xml.Sheet.Descendants().Where(e => e.Name.LocalName == "f"), Is.Empty);
    }

    [TestCaseSource(nameof(Builders))]
    public void A_leading_apostrophe_is_removed_and_the_cell_gets_the_quote_prefix(BuildFunc build)
    {
        var xml = Read(build, "T", Section("S", ["'x"], ["'=cmd|calc"], ["''x"], ["'a\nb"], ["plain"]));

        Assert.That(xml.Cell("A4").Text, Is.EqualTo("x"));
        Assert.That(xml.Cell("A4").Style, Is.EqualTo(new XlsxStyle(true, 11, "Calibri", "FF000000", false, true)));
        Assert.That(xml.Cell("A5").Text, Is.EqualTo("=cmd|calc"));
        Assert.That(xml.Cell("A5").Style.QuotePrefix, Is.True);
        Assert.That(xml.Cell("A6").Text, Is.EqualTo("'x"));
        Assert.That(xml.Cell("A6").Style.QuotePrefix, Is.True);
        Assert.That(xml.Cell("A7").Text, Is.EqualTo("a\nb"));
        Assert.That(xml.Cell("A7").Style.QuotePrefix, Is.True);
        Assert.That(xml.Cell("A7").Style.Wrap, Is.True);
        Assert.That(xml.Cell("A8").Style.QuotePrefix, Is.False);
    }

    [TestCaseSource(nameof(Builders))]
    public void A_text_of_33000_characters_is_cut_to_32767_in_the_file(BuildFunc build)
    {
        Assert.That(CellOf(build, Rep('x', 33000)).Text, Has.Length.EqualTo(32767));
        Assert.That(CellOf(build, Rep('x', 32767)).Text, Has.Length.EqualTo(32767));
    }

    [TestCaseSource(nameof(Builders))]
    public void A_cut_never_splits_a_surrogate_pair(BuildFunc build)
    {
        Assert.That(CellOf(build, Rep('x', 32766) + "😀").Text, Is.EqualTo(Rep('x', 32766)));
        Assert.That(CellOf(build, Rep('x', 32765) + "😀" + "y").Text, Is.EqualTo(Rep('x', 32765) + "😀"));
    }

    private static IEnumerable<TestCaseData> UnicodeCases()
    {
        yield return new TestCaseData("a\tb", "a\tb").SetName("tab kept");
        yield return new TestCaseData("a\u0001b\u0008c\u001Fd", "abcd").SetName("control characters dropped");
        yield return new TestCaseData("a￾b￿c", "abc").SetName("U+FFFE and U+FFFF dropped");
        yield return new TestCaseData("lone\ud800x", "lone�x").SetName("a lone high surrogate");
        yield return new TestCaseData("lone\udc00x", "lone�x").SetName("a lone low surrogate");
        yield return new TestCaseData("Zoë 😀 علي", "Zoë 😀 علي").SetName("Latin, emoji and Arabic kept");
        yield return new TestCaseData("a\u007Fb\u0085c", "a\u007Fb\u0085c").SetName("DEL and NEL kept");
    }

    [TestCaseSource(nameof(UnicodeCasesOnEachBuilder))]
    public void Unicode_edge_cases_are_cleaned_as_today(BuildFunc build, string text, string stored)
    {
        Assert.That(CellOf(build, text).Text, Is.EqualTo(stored));
    }

    [TestCaseSource(nameof(Builders))]
    public void Null_and_empty_write_no_cell_and_false_or_cleaned_empty_text_write_an_empty_text_cell(BuildFunc build)
    {
        var xml = Read(build, "T", Section("S", ["h", "h", "h", "h", "h", "h"], [null, string.Empty, false, "\u0001", "'", "\u0001'"]));

        Assert.That(xml.HasCell("A5"), Is.False);
        Assert.That(xml.HasCell("B5"), Is.False);
        foreach (var address in EmptyTextAddresses)
        {
            Assert.That(xml.Cell(address).IsText, Is.True, address);
            Assert.That(xml.Cell(address).Text, Is.Empty, address);
        }

        Assert.That(xml.Cell("C5").Style.QuotePrefix, Is.False);
        Assert.That(xml.Cell("D5").Style.QuotePrefix, Is.False);
        Assert.That(xml.Cell("E5").Style.QuotePrefix, Is.True);
        Assert.That(xml.Cell("F5").Style.QuotePrefix, Is.True, "the text is cleaned first, so the apostrophe is first when the apostrophe rule runs");
    }

    private static IEnumerable<TestCaseData> SheetNameCases() =>
        EachBuilder(new[]
        {
            ("x:y", "x y"), ("a[b", "a b"), ("a]b", "a b"), ("a*b", "a b"), ("a?b", "a b"), ("a/b", "a b"), ("a\\b", "a b"),
            ("'ab", " ab"), ("ab'", "ab "), ("'", "Report"), ("[]", "Report"), ("   ", "Report"), ("Tab\there", "Tab\there"), ("Ab\n", "Ab\n"),
        }.Select(c => new TestCaseData(c.Item1, c.Item2)));

    [TestCaseSource(nameof(SheetNameCases))]
    public void The_sheet_name_follows_the_rules_in_the_workbook_part(BuildFunc build, string title, string name)
    {
        var xml = Read(build, title, Section("S", ["h"]));

        Assert.That(ReportXlsx.SheetName(title), Is.EqualTo(name));
        Assert.That((string)xml.Part("xl/workbook.xml").Descendants().Single(e => e.Name.LocalName == "sheet").Attribute("name")!, Is.EqualTo(name));
    }

    [Test]
    public void A_name_is_cut_at_31_characters_and_never_inside_an_emoji()
    {
        Assert.That(ReportXlsx.SheetName(Rep('x', 31)), Has.Length.EqualTo(31));
        Assert.That(ReportXlsx.SheetName(Rep('x', 32)), Has.Length.EqualTo(31));
        Assert.That(ReportXlsx.SheetName(Rep('x', 30) + "😀"), Is.EqualTo(Rep('x', 30)));
        Assert.That(ReportXlsx.SheetName(Rep('x', 29) + "😀"), Is.EqualTo(Rep('x', 29) + "😀"));
    }

    [TestCaseSource(nameof(Builders))]
    public void The_sheet_name_is_in_the_properties_part(BuildFunc build)
    {
        var app = Read(build, "My title", Section("S", ["h"])).Part("docProps/app.xml");

        Assert.That(app.Descendants().Where(e => e.Name.LocalName == "lpstr").Select(e => e.Value), Does.Contain("My title"));
    }

    [TestCaseSource(nameof(Builders))]
    public void An_empty_report_holds_only_the_title(BuildFunc build)
    {
        var none = Read(build, "Only", []);
        Assert.That(none.CellAddresses(), Is.EqualTo(OnlyA1));
        Assert.That(none.Cell("A1").Text, Is.EqualTo("Only"));

        var noRows = Read(build, "Only", Section("Head", ["a", "b"]));
        Assert.That(noRows.CellAddresses(), Is.EqualTo(TitleHeadingAndTwoHeaders));
        Assert.That(noRows.HasCell("A5"), Is.False);
    }

    [TestCaseSource(nameof(Builders))]
    public void An_empty_title_leaves_the_first_cell_without_text(BuildFunc build)
    {
        var xml = Read(build, string.Empty, []);

        Assert.That(xml.CellAddresses().Select(a => xml.Cell(a)).Where(c => c.Text is { Length: > 0 }), Is.Empty);
        Assert.That(xml.Part("xl/workbook.xml").Descendants().Single(e => e.Name.LocalName == "sheet").Attribute("name")!.Value, Is.EqualTo("Report"));
    }

    [TestCaseSource(nameof(Builders))]
    public void Line_ends_are_line_feeds_and_only_a_line_feed_wraps(BuildFunc build)
    {
        var xml = Read(build, "T", Section("S", ["h"], ["x\ny"], ["c\rd"], ["a\r\nb"], ["e\r\rf"]));

        Assert.That(xml.Cell("A5").Text, Is.EqualTo("x\ny"));
        Assert.That(xml.Cell("A5").Style.Wrap, Is.True);
        Assert.That(xml.Cell("A6").Text, Is.EqualTo("c\nd"));
        Assert.That(xml.Cell("A6").Style.Wrap, Is.False);
        Assert.That(xml.Cell("A7").Text, Is.EqualTo("a\nb"));
        Assert.That(xml.Cell("A7").Style.Wrap, Is.True);
        Assert.That(xml.Cell("A8").Text, Is.EqualTo("e\n\nf"));
        Assert.That(xml.Cell("A8").Style.Wrap, Is.False);
    }

    [TestCaseSource(nameof(Builders))]
    public void The_parts_hold_no_carriage_return_character(BuildFunc build)
    {
        var xml = Read(build, "T", Section("S", ["h"], ["c\rd"], ["a\r\nb"]));

        foreach (var name in xml.PartNames)
        {
            Assert.That(xml.RawPart(name), Does.Not.Contain((byte)'\r'), name);
            Assert.That(System.Text.Encoding.UTF8.GetString(xml.RawPart(name)), Does.Not.Contain("&#xD;"), name);
        }
    }

    [TestCaseSource(nameof(Builders))]
    public void Fonts_are_Calibri_in_black_with_the_title_bold_14_and_headings_and_headers_bold_11(BuildFunc build)
    {
        var xml = Read(build, "Title", Section("Heading", ["Header"], ["Body", 5]));
        var black = "FF000000";

        Assert.That(xml.Cell("A1").Style, Is.EqualTo(new XlsxStyle(true, 14, "Calibri", black, false, false)));
        Assert.That(xml.Cell("A3").Style, Is.EqualTo(new XlsxStyle(true, 11, "Calibri", black, false, false)));
        Assert.That(xml.Cell("A4").Style, Is.EqualTo(new XlsxStyle(true, 11, "Calibri", black, false, false)));
        Assert.That(xml.Cell("A5").Style, Is.EqualTo(new XlsxStyle(false, 11, "Calibri", black, false, false)));
        Assert.That(xml.Cell("B5").Style, Is.EqualTo(new XlsxStyle(false, 11, "Calibri", black, false, false)));
    }

    [TestCaseSource(nameof(Builders))]
    public void The_style_sheet_holds_three_fonts_with_baseline_and_family_2(BuildFunc build)
    {
        var fonts = Read(build, "T", Section("S", ["h"], ["x"])).Part("xl/styles.xml").Descendants().Where(e => e.Name.LocalName == "font").ToList();

        Assert.That(fonts, Has.Count.EqualTo(3));
        Assert.That(fonts.Select(f => f.Elements().Select(e => e.Name.LocalName).Contains("b")), Is.EqualTo(FontBold));
        Assert.That(fonts.Select(f => f.Elements().Single(e => e.Name.LocalName == "sz").Attribute("val")!.Value), Is.EqualTo(FontSizes));
        Assert.That(fonts.Select(f => f.Elements().Single(e => e.Name.LocalName == "vertAlign").Attribute("val")!.Value), Is.All.EqualTo("baseline"));
        Assert.That(fonts.Select(f => f.Elements().Single(e => e.Name.LocalName == "family").Attribute("val")!.Value), Is.All.EqualTo("2"));
    }

    [TestCaseSource(nameof(Builders))]
    public void Print_settings_are_Letter_with_these_margins(BuildFunc build)
    {
        var xml = Read(build, "T", Section("S", ["h"], ["x"]));
        var margins = xml.SheetElement("pageMargins");

        Assert.That(MarginNames.Select(a => margins.Attribute(a)!.Value), Is.EqualTo(MarginValues));
        Assert.That(xml.SheetElement("pageSetup").Attribute("paperSize")!.Value, Is.EqualTo("1"));
        Assert.That(xml.SheetElement("pageSetup").Attribute("orientation")!.Value, Is.EqualTo("default"));
        Assert.That(xml.SheetElement("sheetFormatPr").Attribute("defaultRowHeight")!.Value, Is.EqualTo("15"));
        Assert.That(xml.SheetElement("printOptions").Attributes().Select(a => a.Value), Is.All.EqualTo("0"));
        Assert.That(xml.SheetElement("headerFooter").HasElements, Is.False);
    }

    [TestCaseSource(nameof(Builders))]
    public void The_file_properties_are_Microsoft_Excel_and_the_download_time(BuildFunc build)
    {
        var before = DateTimeOffset.UtcNow.AddSeconds(-1);
        var xml = Read(build, "T", Section("S", ["h"], ["x"]));
        var after = DateTimeOffset.UtcNow.AddSeconds(1);

        var app = xml.Part("docProps/app.xml").Root!.Elements().ToDictionary(e => e.Name.LocalName, e => e.Value, StringComparer.Ordinal);
        Assert.That(app["Application"], Is.EqualTo("Microsoft Excel"));
        Assert.That(app["DocSecurity"], Is.EqualTo("0"));
        Assert.That(app["ScaleCrop"], Is.EqualTo("false"));

        var core = xml.Part(xml.CorePartName).Descendants().ToList();
        Assert.That(core.Select(e => e.Name.LocalName), Is.EquivalentTo(CorePropertyElements));
        foreach (var name in new[] { "created", "modified" })
        {
            var stamp = DateTimeOffset.Parse(core.Single(e => e.Name.LocalName == name).Value, System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.AssumeUniversal);
            Assert.That(stamp, Is.InRange(before, after), name);
        }

        Assert.That(core.Single(e => e.Name.LocalName == "created").Value, Does.EndWith("Z"));
    }

    [TestCaseSource(nameof(Builders))]
    public void The_theme_part_is_the_one_in_today_s_file(BuildFunc build)
    {
        var theme = Read(build, "T", Section("S", ["h"], ["x"])).RawPart("xl/theme/theme1.xml");

        Assert.That(theme, Has.Length.EqualTo(7096));
        Assert.That(Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(theme)), Is.EqualTo("7B6FE2FA569D58D754F94573C372E5CB9A4522847D5531B18B975F9AFE1271C7"));
    }

    [TestCaseSource(nameof(Builders))]
    public void A_title_with_a_control_character_fails_as_today(BuildFunc build)
    {
        Assert.That(() => build("bad\u0001title", []), Throws.TypeOf<ArgumentException>().With.Message.Contain("0x01"));
    }

    [TestCaseSource(nameof(Builders))]
    public void A_title_with_a_line_feed_keeps_it_in_the_sheet_name_and_wraps_the_first_cell(BuildFunc build)
    {
        var xml = Read(build, "Ab\n", []);

        Assert.That(xml.Cell("A1").Text, Is.EqualTo("Ab\n"));
        Assert.That(xml.Cell("A1").Style.Wrap, Is.True);
    }

    /// <summary>Bold 14 plus wrap is style 4, plus the quote prefix 10: the three bits of the index in one cell each.</summary>
    [Test]
    public void The_style_index_is_the_font_plus_3_for_a_line_feed_plus_6_for_a_removed_apostrophe()
    {
        var xml = Read(ReportXlsx.BuildNew, "'T\n", Section("'h\ni", ["h"], ["'x"], ["y\nz"], ["plain"]));

        Assert.That(xml.Cell("A1").StyleIndex, Is.EqualTo(1 + 3 + 6));
        Assert.That(xml.Cell("A3").StyleIndex, Is.EqualTo(2 + 3 + 6));
        Assert.That(xml.Cell("A5").StyleIndex, Is.EqualTo(0 + 6));
        Assert.That(xml.Cell("A6").StyleIndex, Is.EqualTo(0 + 3));
        Assert.That(xml.Cell("A7").StyleIndex, Is.EqualTo(0));
    }

    /// <summary>R17: the writer holds no cell list, so 500,000 cells cost far less than the 2,307 MB and 2.2 s of the ClosedXML writer.</summary>
    [Test]
    public void A_report_of_50000_rows_and_10_columns_is_built_in_bounds()
    {
        var headers = Enumerable.Range(1, 10).Select(i => $"h{i}").ToArray();
        var rows = Enumerable.Range(1, 50000)
            .Select(i => (IReadOnlyList<object?>)new object?[] { i, "Synthetic Member " + i, $"member{i}@test.invalid", i * 1.5, "x\ny", null, "'q", true, "plain text", "https://example.invalid/r" })
            .ToList();
        var section = new ReportSection("S", headers, rows);

        var allocatedBefore = GC.GetAllocatedBytesForCurrentThread();
        var clock = System.Diagnostics.Stopwatch.StartNew();
        var bytes = ReportXlsx.BuildNew("Big", [section]);
        clock.Stop();
        var allocatedMb = (GC.GetAllocatedBytesForCurrentThread() - allocatedBefore) / (1024.0 * 1024.0);

        TestContext.Out.WriteLine($"R17: {clock.ElapsedMilliseconds} ms, {allocatedMb:F0} MB allocated, {bytes.Length} bytes");
        Assert.That(allocatedMb, Is.LessThan(1000));
        Assert.That(clock.Elapsed, Is.LessThan(TimeSpan.FromSeconds(10)));
    }

    private static IEnumerable<TestCaseData> ValidatorCases() => EachBuilder(ValidatorInputs());

    private static IEnumerable<TestCaseData> ValidatorInputs()
    {
        yield return new TestCaseData("My title", new[] { Section("Gents", ["Token", "Name"], [1, "A"], [2, "B"]), Section("Ladies", ["X"], ["y"]) }).SetName("layout");
        yield return new TestCaseData("Values", new[] { Section("Kinds", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"], [7, 2.5, 0.1f, decimal.MaxValue, double.NaN, true, false, new DateTime(2026, 1, 2, 3, 4, 5), Guid.Empty, null, string.Empty], ["=1+1", "'q", "'", "a\nb", "c\rd", "\u0001", Rep('x', 33000), "😀", "lone\ud800", "محمد", "a\tb"]) }).SetName("every value kind");
        yield return new TestCaseData("No sections", Array.Empty<ReportSection>()).SetName("no sections");
        yield return new TestCaseData(string.Empty, Array.Empty<ReportSection>()).SetName("empty title");
        yield return new TestCaseData("Ab\n", new[] { Section("S", ["h"]) }).SetName("title with a line feed and a section with no rows");
    }

    [TestCaseSource(nameof(ValidatorCases))]
    public void Each_workbook_passes_the_open_xml_validator(BuildFunc build, string title, ReportSection[] sections)
    {
        using var document = SpreadsheetDocument.Open(new MemoryStream(build(title, sections)), false);
        var errors = new OpenXmlValidator(FileFormatVersions.Microsoft365).Validate(document).Select(e => $"{e.Path?.XPath}: {e.Description}").ToList();

        Assert.That(errors, Is.Empty);
    }

    [Test]
    public void Each_column_is_its_longest_line_plus_two_capped_at_255()
    {
        var xml = Read(ReportXlsx.BuildNew, "One", Section("Gents", ["Token", "Name"], [1, "A", Rep('x', 33000)], [2, "B"]));

        Assert.That(xml.Widths(), Is.EqualTo(LimitWidths));
        Assert.That(xml.Columns(), Has.Count.EqualTo(3), "one col element per column");
        Assert.That(xml.Columns().Select(c => (string)c.Attribute("customWidth")!), Is.All.EqualTo("1"));
    }

    [Test]
    public void Widths_follow_the_text_of_the_sheet_and_not_the_fonts_installed()
    {
        var headers = Enumerable.Range(1, 10).Select(i => $"h{i}").ToArray();
        var row = new object?[] { null, null, "Synthetic Member", "member927100@test.invalid", null, null, null, null, null, "https://example.invalid/r" };
        var widths = Read(ReportXlsx.BuildNew, "Admin access log", Section("Admin access log, last 30 days, 2026-11-21", headers, row)).Widths();

        Assert.That(widths, Has.Count.EqualTo(10));
        Assert.That(new[] { widths[0], widths[2], widths[3], widths[9] }, Is.EqualTo(AccessLogWidths));
        Assert.That(Read(ReportXlsx.BuildNew, "Active teachers: Gents", []).Widths(), Is.EqualTo(TitleOnlyWidth));
    }

    [Test]
    public void A_width_counts_the_longest_line_the_text_of_a_number_and_gives_an_empty_column_2()
    {
        var xml = Read(ReportXlsx.BuildNew, "T", Section("S", ["h"], ["ab\ncdef", null, 12345.5, "c\rdefg"]));

        Assert.That(xml.Widths(), Is.EqualTo(LineNumberEmptyAndCarriageReturnWidths));
    }

    [Test]
    public void The_cols_elements_cover_columns_1_to_the_widest_without_gaps_each_with_a_custom_width()
    {
        var columns = Read("T", Section("S", ["a", "bbbbbbbbbbbbbbbbbbbb", "c", "d"], ["1", "2", "3", "4"])).Columns();

        Assert.That(columns.Select(c => (string)c.Attribute("customWidth")!), Is.All.EqualTo("1"));
        Assert.That(columns.Select(c => (string)c.Attribute("style")!), Is.All.EqualTo("0"));
        var next = 1;
        foreach (var column in columns)
        {
            Assert.That(int.Parse((string)column.Attribute("min")!, System.Globalization.CultureInfo.InvariantCulture), Is.EqualTo(next));
            next = int.Parse((string)column.Attribute("max")!, System.Globalization.CultureInfo.InvariantCulture) + 1;
        }

        Assert.That(next, Is.EqualTo(5));
    }

    [TestCaseSource(nameof(Builders))]
    public void The_properties_part_lists_the_sheet_and_its_two_print_names_and_counts_two_named_ranges(BuildFunc build)
    {
        var app = Read(build, "My title", Section("S", ["h"])).Part("docProps/app.xml");

        var names = app.Descendants().Where(e => e.Name.LocalName == "lpstr").Select(e => e.Value).ToList();
        Assert.That(names, Is.EqualTo(PropertyNames("My title")));
        Assert.That(app.Descendants().Where(e => e.Name.LocalName == "i4").Select(e => e.Value), Is.EqualTo(WorksheetAndNamedRangeCounts));
    }

    private static string[] PropertyNames(string sheet) => [sheet, sheet + "!Print_Area", sheet + "!Print_Titles", "Worksheets", "Named Ranges"];
}
