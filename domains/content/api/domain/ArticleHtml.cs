using System.Text.RegularExpressions;
using Markdig;
using Markdig.Syntax;
using Markdig.Syntax.Inlines;

namespace Tsr.Content.Api.Domain;

/// <summary>What the refresh derives from an article's Markdown: its HTML and its reading time.</summary>
internal static partial class ArticleHtml
{
    private const int WordsAMinute = 200;

    // Plain CommonMark, no extension: tsr-web's API renders with remark().use(html) (web/src/lib/markdown.ts:87-89), which has no GitHub-flavoured Markdown.
    private static readonly MarkdownPipeline Pipeline = new MarkdownPipelineBuilder().Build();

    /// <summary>
    /// The article's HTML, safe to put in a page: remark-html sanitises by default, so here raw HTML in the Markdown is dropped (the text between inline tags stays)
    /// and a link or image address that could run script gets an empty address (<see cref="IsSafeAddress"/>).
    /// Throws <see cref="ArgumentException"/> when Markdig finds the text nested past its depth limit; the caller turns that into a failure.
    /// </summary>
    public static string ToHtml(string markdown)
    {
        var document = Markdown.Parse(markdown, Pipeline);
        foreach (var node in document.Descendants().ToList())
        {
            MakeSafe(node);
        }

        return document.ToHtml(Pipeline);
    }

    /// <summary>
    /// True for an address with the scheme <c>http</c>, <c>https</c> or <c>mailto</c>, or with none (site-relative, relative, a query or a fragment).
    /// A browser ignores white space and control characters in a scheme and its case, so they are dropped before the scheme is read.
    /// </summary>
    internal static bool IsSafeAddress(string? address)
    {
        var compact = string.Concat((address ?? string.Empty).Where(c => !char.IsWhiteSpace(c) && !char.IsControl(c)));
        var colon = compact.IndexOf(':', StringComparison.Ordinal);
        if (colon < 0)
        {
            return true;
        }

        // A colon after the path, query or fragment has begun is not a scheme's.
        var pathStart = compact.IndexOfAny(['/', '?', '#']);
        if (pathStart >= 0 && pathStart < colon)
        {
            return true;
        }

        return compact[..colon].ToLowerInvariant() is "http" or "https" or "mailto";
    }

    private static void MakeSafe(MarkdownObject node)
    {
        switch (node)
        {
            case HtmlBlock block:
                block.Parent?.Remove(block);
                break;
            case HtmlInline inline:
                inline.Remove();
                break;
            case LinkInline link when !IsSafeAddress(link.Url):
                link.Url = string.Empty;
                break;
            case AutolinkInline { IsEmail: false } bare when !IsSafeAddress(bare.Url):
                // A bare link shows its own address as its text: the text stays, the address goes.
                var unlinked = new LinkInline { Url = string.Empty };
                unlinked.AppendChild(new LiteralInline(bare.Url));
                bare.ReplaceBy(unlinked);
                break;
        }
    }

    /// <summary>
    /// tsr-web <c>calculateReadingTime</c> (<c>article-service.ts:18-23</c>): the pieces between runs of white space, 200 a minute, rounded up, never under 1.
    /// A piece before leading or after trailing white space is empty and still counts, as there.
    /// </summary>
    public static int ReadingMinutes(string markdown)
    {
        if (markdown.Length == 0)
        {
            return 1;
        }

        var pieces = WhiteSpace().Count(markdown) + 1;
        return Math.Max(1, (pieces + WordsAMinute - 1) / WordsAMinute);
    }

    [GeneratedRegex(@"\s+")]
    private static partial Regex WhiteSpace();
}
