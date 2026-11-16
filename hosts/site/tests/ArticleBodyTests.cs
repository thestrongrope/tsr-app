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

    [Test]
    public void White_space_between_blocks_is_kept() =>
        Assert.That(ArticleBody.Render("<p>a</p>\n<p>b</p>\n"), Does.Contain("</p>\n<p "));
}
