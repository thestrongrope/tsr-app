using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class ReportCsvTests
{
    [TestCase("=1+1", "'=1+1")]
    [TestCase("+x", "'+x")]
    [TestCase("-cmd", "'-cmd")]
    [TestCase("@SUM", "'@SUM")]
    [TestCase("\tx", "'\tx")]
    [TestCase("\rx", "'\rx")]
    [TestCase("-5", "-5")]
    [TestCase("-0.5000", "-0.5000")]
    [TestCase("+5", "+5")]
    [TestCase(" =x", " =x")]
    [TestCase("", "")]
    [TestCase("plain", "plain")]
    public void A_text_that_would_run_as_a_formula_gets_a_leading_quote_and_a_number_does_not(string value, string expected) =>
        Assert.That(ReportCsv.Cell(value), Is.EqualTo(expected));

    [Test]
    public void A_field_is_quoted_when_it_holds_a_comma_a_quote_a_space_a_tab_or_a_line_break_and_quotes_are_doubled()
    {
        var csv = ReportCsv.Build(
            ["A B", "C"],
            [["x,y", null], ["say \"hi\"", "a\nb"], ["=z", "-5"], ["t\tb", "plain"]]);
        Assert.That(csv, Is.EqualTo("\"A B\",C\n\"x,y\",\n\"say \"\"hi\"\"\",\"a\nb\"\n'=z,-5\n\"t\tb\",plain\n"));
    }

    [Test]
    public void The_header_cells_pass_the_formula_rule_too()
    {
        Assert.That(ReportCsv.Build(["=H"], [["v"]]), Is.EqualTo("'=H\nv\n"));
    }

    [Test]
    public void No_rows_is_no_file()
    {
        Assert.That(ReportCsv.Build(["A"], []), Is.Null);
    }
}
