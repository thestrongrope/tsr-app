using Tsr.Content.Site;
using Tsr.Shared.Site;
using NUnit.Framework;

namespace Tsr.Host.Site.Tests;

/// <summary>
/// The article body: the API's HTML, rewritten with the classes and rules of the present website's MarkdownRenderer.tsx.
/// Every text here is synthetic.
/// </summary>
public sealed class ArticleBodyTests
{
    [Test]
    public void A_paragraph_gets_the_present_site_s_classes() =>
        Assert.That(ArticleBody.Render("<p>Plain text.</p>"),
            Is.EqualTo("<p class=\"text-gray-900 dark:text-gray-100 leading-relaxed mb-4\">Plain text.</p>"));

    [Test]
    public void A_mostly_arabic_paragraph_is_marked_arabic_text() =>
        Assert.That(ArticleBody.Render("<p>نص تجريبي ok</p>"), Does.Contain("mb-4 arabic-text\">"));

    [Test]
    public void A_paragraph_with_some_arabic_is_marked_arabic_mixed() =>
        Assert.That(ArticleBody.Render("<p>A long line of English text with one word نص in it.</p>"), Does.Contain("mb-4 arabic-mixed\">"));

    [TestCase("<h1>T</h1>", "<h1 class=\"text-3xl font-bold text-gray-900 dark:text-gray-100 mb-4 mt-8 clear-both\">T</h1>")]
    [TestCase("<h2>T</h2>", "<h2 class=\"text-2xl font-bold text-gray-900 dark:text-gray-100 mb-3 mt-6 clear-both\">T</h2>")]
    [TestCase("<h4>T</h4>", "<h4>T</h4>")]
    [TestCase("<hr />", "<hr class=\"my-8 border-gray-300 dark:border-gray-700\">")]
    [TestCase("<p>a<br />b</p>", "<p class=\"text-gray-900 dark:text-gray-100 leading-relaxed mb-4\">a<br>b</p>")]
    [TestCase("<ol start=\"3\"><li>x</li></ol>",
        "<ol start=\"3\" class=\"list-decimal list-outside ml-6 text-gray-900 dark:text-gray-100 mb-4 space-y-2\"><li class=\"text-gray-900 dark:text-gray-100 leading-relaxed\">x</li></ol>")]
    public void An_element_is_written_as_the_present_site_writes_it(string html, string expected) =>
        Assert.That(ArticleBody.Render(html), Is.EqualTo(expected));

    [Test]
    public void An_outside_link_opens_in_a_new_tab_and_a_site_link_does_not()
    {
        var outside = ArticleBody.Render("<p><a href=\"https://example.invalid/a?b=1&amp;c=2\">out</a></p>");
        var inside = ArticleBody.Render("<p><a href=\"/articles/x/\">in</a></p>");

        Assert.Multiple(() =>
        {
            Assert.That(outside, Does.Contain(
                "<a href=\"https://example.invalid/a?b=1&amp;c=2\" class=\"text-blue-600 dark:text-blue-400 hover:underline\" target=\"_blank\" rel=\"noopener noreferrer\">out</a>"));
            Assert.That(inside, Does.Contain("<a href=\"/articles/x/\" class=\"text-blue-600 dark:text-blue-400 hover:underline\">in</a>"));
        });
    }

    [TestCase("javascript:alert(1)")]
    [TestCase(" JaVaScript:alert(1)")]
    [TestCase("data:text/html,x")]
    public void A_link_that_could_run_script_loses_its_address(string address) =>
        Assert.That(ArticleBody.Render($"<p><a href=\"{address}\">x</a></p>"), Does.Not.Contain("href"));

    [Test]
    public void An_attribute_the_renderer_does_not_know_is_dropped() =>
        Assert.That(ArticleBody.Render("<p onclick=\"x()\" style=\"color:red\">t</p>"),
            Is.EqualTo("<p class=\"text-gray-900 dark:text-gray-100 leading-relaxed mb-4\">t</p>"));

    [TestCase("<script>alert(1)</script>")]
    [TestCase("<p><iframe src=\"https://example.invalid\"></iframe></p>")]
    [TestCase("<p>not closed")]
    [TestCase("<!DOCTYPE p [<!ENTITY a \"b\">]><p>&a;</p>")]
    public void Html_the_renderer_does_not_know_stops_the_build(string html) =>
        Assert.Throws<SiteBuildException>(() => ArticleBody.Render(html));

    [Test]
    public void A_body_nested_deeper_than_the_bound_stops_the_build()
    {
        // The renderer walks the body by recursion: a body nested without end must stop the build, not the process.
        var deep = string.Concat(Enumerable.Repeat("<blockquote>", 200)) + "<p>x</p>" + string.Concat(Enumerable.Repeat("</blockquote>", 200));

        Assert.Throws<SiteBuildException>(() => ArticleBody.Render(deep));
    }

    [Test]
    public void A_body_nested_within_the_bound_is_rendered()
    {
        var nested = string.Concat(Enumerable.Repeat("<blockquote>", 20)) + "<p>x</p>" + string.Concat(Enumerable.Repeat("</blockquote>", 20));

        Assert.That(ArticleBody.Render(nested), Does.Contain(">x</p>"));
    }

    [Test]
    public void Text_stays_escaped() =>
        Assert.That(ArticleBody.Render("<p>&lt;script&gt; &amp; &quot;q&quot;</p>"), Does.Contain(">&lt;script&gt; &amp; &quot;q&quot;</p>"));

    [Test]
    public void An_image_is_framed_with_its_caption() =>
        Assert.That(ArticleBody.Render("<p><img src=\"/uploads/a.png\" alt=\"A caption\" /></p>"), Does.Contain(
            "<span class=\"inline-block max-w-sm mr-4 mb-4 float-left\"><img src=\"/uploads/a.png\" alt=\"A caption\" class=\"rounded-lg shadow-md w-full h-auto\">"
            + "<span class=\"text-xs text-gray-600 dark:text-gray-400 mt-1 block text-center italic\">A caption</span></span>"));

    [Test]
    public void Inline_code_and_a_code_block_differ()
    {
        var inline = ArticleBody.Render("<p><code>x</code></p>");
        var block = ArticleBody.Render("<pre><code class=\"language-text\">a\nb\n</code></pre>");

        Assert.Multiple(() =>
        {
            Assert.That(inline, Does.Contain("<code class=\"bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 px-1.5 py-0.5 rounded text-sm font-mono\">x</code>"));
            Assert.That(block, Is.EqualTo(
                "<pre class=\"bg-gray-100 dark:bg-gray-900 p-4 rounded-lg overflow-x-auto my-4\">"
                + "<code class=\"language-text text-gray-900 dark:text-gray-100 text-sm font-mono\">a\nb\n</code></pre>"));
        });
    }

    [TestCase("<p>Reading Time: 4 minutes</p><p>Kept.</p>")]
    [TestCase("<p>reading time: &lt; 1 minute</p><p>Kept.</p>")]
    public void The_reading_time_line_of_the_text_is_removed_as_the_header_shows_it(string html) =>
        Assert.That(ArticleBody.Render(html), Is.EqualTo("<p class=\"text-gray-900 dark:text-gray-100 leading-relaxed mb-4\">Kept.</p>"));

    private const string ParagraphStart = "<p class=\"text-gray-900 dark:text-gray-100 leading-relaxed mb-4\">";

    /// <summary>What the API writes for one footnote: the reference in the text, and the notes at the end with the link back.</summary>
    private const string Footnoted =
        "<p>A claim<a id=\"fnref:1\" href=\"#fn:1\" class=\"footnote-ref\"><sup>1</sup></a> in a line.</p>\n"
        + "<div class=\"footnotes\">\n<hr />\n<ol>\n<li id=\"fn:1\">\n"
        + "<p>The <em>source</em> &lt;b&gt; &quot;q&quot;.<a href=\"#fnref:1\" class=\"footnote-back-ref\">&#8617;</a></p>\n"
        + "</li>\n</ol>\n</div>\n";

    [Test]
    public void A_table_is_framed_and_gets_the_present_site_s_classes() =>
        Assert.That(
            ArticleBody.Render("<table>\n<thead>\n<tr>\n<th style=\"text-align: right;\">Day</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>One</td>\n</tr>\n</tbody>\n</table>\n"),
            Is.EqualTo(
                "<div class=\"overflow-x-auto my-4\">"
                + "<table class=\"min-w-full divide-y divide-gray-200 dark:divide-gray-700 border border-gray-200 dark:border-gray-700\">\n<thead>\n<tr>\n"
                + "<th style=\"text-align:right\" class=\"px-4 py-2 bg-gray-100 dark:bg-gray-800 text-left text-gray-900 dark:text-gray-100 font-semibold\">Day</th>\n"
                + "</tr>\n</thead>\n<tbody>\n<tr>\n"
                + "<td class=\"px-4 py-2 border-t border-gray-200 dark:border-gray-700 text-gray-900 dark:text-gray-100\">One</td>\n"
                + "</tr>\n</tbody>\n</table></div>\n"));

    [Test]
    public void A_footnote_reference_is_the_present_site_s_link_with_the_note_s_text_to_show_on_hover() =>
        Assert.That(ArticleBody.Render(Footnoted), Does.StartWith(
            ParagraphStart + "A claim<sup class=\"text-blue-600 dark:text-blue-400\">"
            + "<a href=\"#user-content-fn-1\" class=\"text-blue-600 dark:text-blue-400 hover:underline relative group cursor-pointer\""
            + " id=\"user-content-fnref-1\" data-footnote-ref=\"\" aria-describedby=\"footnote-label\">1"
            + "<span class=\"invisible group-hover:visible absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-3 py-2 bg-gray-900 dark:bg-gray-100 text-white dark:text-gray-900 text-sm rounded-lg shadow-lg max-w-xs z-50 whitespace-normal text-left\">"
            + "The source &lt;b&gt; &quot;q&quot;."
            + "<span class=\"absolute top-full left-1/2 -translate-x-1/2 border-4 border-transparent border-t-gray-900 dark:border-t-gray-100\"></span>"
            + "</span></a></sup> in a line.</p>\n"));

    [Test]
    public void The_hover_text_is_the_first_line_of_the_note_only()
    {
        var html = ArticleBody.Render(
            "<p>x<a id=\"fnref:1\" href=\"#fn:1\" class=\"footnote-ref\"><sup>1</sup></a></p>\n<div class=\"footnotes\">\n<hr />\n<ol>\n<li id=\"fn:1\">\n"
            + "<p>First line\nsecond line</p>\n<p>Second paragraph.<a href=\"#fnref:1\" class=\"footnote-back-ref\">&#8617;</a></p>\n</li>\n</ol>\n</div>\n");

        Assert.That(html, Does.Contain("text-left\">First line<span"));
    }

    [Test]
    public void The_footnotes_are_the_present_site_s_section_with_its_heading_and_links_back() =>
        Assert.That(ArticleBody.Render(Footnoted), Does.EndWith(
            "<section data-footnotes=\"\">"
            + "<h2 class=\"sr-only text-2xl font-bold text-gray-900 dark:text-gray-100 mb-3 mt-6 clear-both\" id=\"footnote-label\">Footnotes</h2>\n\n"
            + "<ol class=\"list-decimal list-outside ml-6 text-gray-900 dark:text-gray-100 mb-4 space-y-2\">\n"
            + "<li class=\"text-gray-900 dark:text-gray-100 leading-relaxed\" id=\"user-content-fn-1\">\n"
            + ParagraphStart + "The <em class=\"text-gray-900 dark:text-gray-100\">source</em> &lt;b&gt; &quot;q&quot;."
            + "<a href=\"#user-content-fnref-1\" class=\"text-blue-600 dark:text-blue-400 hover:underline\" data-footnote-backref=\"\" aria-label=\"Back to reference 1\">↩</a></p>\n"
            + "</li>\n</ol>\n</section>\n"));

    [TestCase("<p>x<a id=\"fnref:1\" href=\"#fn:1&quot; onclick=&quot;run()\" class=\"footnote-ref\"><sup>1</sup></a></p>")]
    [TestCase("<p>x<a id=\"fnref:1\" href=\"#fn:1\" class=\"footnote-ref\"><sup>1&lt;b&gt;</sup></a></p>")]
    [TestCase("<p>x<a id=\"fnref:1\" href=\"#fn:1\" class=\"footnote-ref\"><sup>1</sup></a></p>")]
    [TestCase("<p><a href=\"#fnref:1&quot; onclick=&quot;run()\" class=\"footnote-back-ref\">&#8617;</a></p>")]
    [TestCase("<p><a href=\"javascript:run()\" class=\"footnote-back-ref\">&#8617;</a></p>")]
    [TestCase("<div class=\"other\"><p>x</p></div>")]
    [TestCase("<div><p>x</p></div>")]
    [TestCase("<p>x<sup>1</sup></p>")]
    public void A_footnote_that_is_not_as_the_api_writes_it_stops_the_build(string html) =>
        Assert.Throws<SiteBuildException>(() => ArticleBody.Render(html));

    [Test]
    public void A_footnote_number_in_digits_of_another_script_stops_the_build() =>
        Assert.Throws<SiteBuildException>(() => ArticleBody.Render(Footnoted.Replace("<sup>1</sup>", "<sup>١</sup>", StringComparison.Ordinal)));

    [Test]
    public void A_body_that_its_hover_texts_grow_past_the_bound_stops_the_build()
    {
        var references = string.Concat(Enumerable.Repeat("<a id=\"fnref:1\" href=\"#fn:1\" class=\"footnote-ref\"><sup>1</sup></a>", 300));
        var html = "<p>x" + references + "</p>\n<div class=\"footnotes\">\n<hr />\n<ol>\n<li id=\"fn:1\">\n<p>" + new string('x', 20_000)
            + "<a href=\"#fnref:1\" class=\"footnote-back-ref\">&#8617;</a></p>\n</li>\n</ol>\n</div>\n";

        Assert.That(Assert.Throws<SiteBuildException>(() => ArticleBody.Render(html))!.Message, Does.Contain("2000000 characters"));
    }

    [Test]
    public void Markup_in_a_footnote_id_or_a_table_attribute_is_never_written()
    {
        var item = ArticleBody.Render("<ol><li id=\"fn:1&quot; onmouseover=&quot;run()\">x</li></ol>");
        var cell = ArticleBody.Render(
            "<table onclick=\"run()\"><tbody><tr class=\"x\"><td style=\"text-align: left; background: url(javascript:run())\" onclick=\"run()\" colspan=\"2\">x</td></tr></tbody></table>");

        Assert.Multiple(() =>
        {
            Assert.That(item, Is.EqualTo(
                "<ol class=\"list-decimal list-outside ml-6 text-gray-900 dark:text-gray-100 mb-4 space-y-2\"><li class=\"text-gray-900 dark:text-gray-100 leading-relaxed\">x</li></ol>"));
            Assert.That(cell, Does.Contain("<tbody><tr><td class=\"px-4 py-2 border-t border-gray-200 dark:border-gray-700 text-gray-900 dark:text-gray-100\">x</td></tr></tbody>"));
            Assert.That(cell, Does.Not.Contain("run()").And.Not.Contain("style").And.Not.Contain("colspan"));
        });
    }

    [Test]
    public void A_bare_address_the_api_linked_is_an_ordinary_outside_link() =>
        Assert.That(ArticleBody.Render("<p>See <a href=\"https://example.invalid/page\">https://example.invalid/page</a> now.</p>"), Is.EqualTo(
            ParagraphStart + "See <a href=\"https://example.invalid/page\" class=\"text-blue-600 dark:text-blue-400 hover:underline\" target=\"_blank\" rel=\"noopener noreferrer\">https://example.invalid/page</a> now.</p>"));

    [Test]
    public void A_paragraph_whose_footnote_is_in_arabic_script_counts_the_note_s_text_as_the_present_site_does() =>
        Assert.That(
            ArticleBody.Render("<p>ok<a id=\"fnref:1\" href=\"#fn:1\" class=\"footnote-ref\"><sup>1</sup></a></p>\n<div class=\"footnotes\">\n<hr />\n<ol>\n<li id=\"fn:1\">\n<p>نص تجريبي<a href=\"#fnref:1\" class=\"footnote-back-ref\">&#8617;</a></p>\n</li>\n</ol>\n</div>\n"),
            Does.StartWith("<p class=\"text-gray-900 dark:text-gray-100 leading-relaxed mb-4 arabic-text\">ok<sup"));

    [Test]
    public void White_space_between_blocks_is_kept() =>
        Assert.That(ArticleBody.Render("<p>a</p>\n<p>b</p>\n"), Does.Contain("</p>\n<p "));
}
