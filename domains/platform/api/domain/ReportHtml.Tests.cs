using NUnit.Framework;

namespace Tsr.Platform.Api.Domain;

[TestFixture]
internal sealed class ReportHtmlTests
{
    private static ReportSection Section(string heading, string[] headers, params object?[][] rows) =>
        new(heading, headers, rows.Select(r => (IReadOnlyList<object?>)r).ToList());

    [Test]
    public void The_page_has_the_title_then_each_section_as_a_heading_and_a_table()
    {
        var html = ReportHtml.Build("Active teachers: Gents", [Section("Gents", ["Token", "Name"], [1, "A"], [2, null])]);

        Assert.That(html, Does.StartWith("<html><head><meta charset=\"UTF-8\"><style>"));
        Assert.That(html, Does.Contain("<h1>Active teachers: Gents</h1>"));
        Assert.That(html, Does.Contain("<h2>Gents</h2><table><tr><th>Token</th><th>Name</th></tr><tr><td>1</td><td>A</td></tr><tr><td>2</td><td></td></tr></table>"));
        Assert.That(html, Does.EndWith("</body></html>"));
    }

    [TestCase("<script>alert(1)</script>")]
    [TestCase("<img src=\"http://evil/x.png\">")]
    [TestCase("<link rel=\"stylesheet\" href=\"http://evil/x.css\">")]
    [TestCase("<iframe src=\"http://evil\"></iframe>")]
    [TestCase("\"><b onmouseover='x'>")]
    public void Every_value_is_escaped_so_no_value_can_inject_markup(string hostile)
    {
        var html = ReportHtml.Build(hostile, [Section(hostile, [hostile], [hostile])]);

        Assert.That(html, Does.Not.Contain("<script"));
        Assert.That(html, Does.Not.Contain("<img"));
        Assert.That(html, Does.Not.Contain("<link"));
        Assert.That(html, Does.Not.Contain("<iframe"));
        Assert.That(html, Does.Not.Contain("<b "));
        Assert.That(html, Does.Contain("&lt;").Or.Contain("&quot;"));
    }

    [Test]
    public void The_template_itself_names_no_external_resource()
    {
        var html = ReportHtml.Build("T", [Section("S", ["h"], ["v"])]);

        Assert.That(html, Does.Not.Contain("http:"));
        Assert.That(html, Does.Not.Contain("https:"));
        Assert.That(html, Does.Not.Contain("url("));
        Assert.That(html, Does.Not.Contain("@import"));
        Assert.That(html, Does.Not.Contain("<script"));
    }

    [Test]
    public void Right_to_left_text_passes_through_untouched()
    {
        var arabic = "محمد علي";
        var html = ReportHtml.Build(arabic, [Section(arabic, [arabic], [arabic])]);

        Assert.That(html, Does.Contain("<h1>" + arabic + "</h1>"));
        Assert.That(html, Does.Contain("<td>" + arabic + "</td>"));
    }

    [Test]
    public void Numbers_are_written_with_the_invariant_culture()
    {
        var html = ReportHtml.Build("T", [Section("S", ["h"], [2.5], [1234567])]);

        Assert.That(html, Does.Contain("<td>2.5</td>"));
        Assert.That(html, Does.Contain("<td>1234567</td>"));
    }
}
