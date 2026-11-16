using System.Text;
using System.Text.RegularExpressions;
using System.Xml;
using System.Xml.Linq;
using Tsr.Shared.Site;

namespace Tsr.Content.Site;

/// <summary>
/// The body of an article as the present website shows it. The API sends the body as HTML it has already rendered from the
/// Markdown and made safe (plain CommonMark, raw HTML dropped; domains/content/api/domain/ArticleHtml.cs), so this is not a
/// Markdown renderer: it reads that HTML strictly and writes it again with the classes and rules of tsr-web's
/// MarkdownRenderer.tsx. Presentation only.
///
/// Nothing passes through unread: an element this class does not know stops the build, an attribute it does not know is
/// dropped, and every text and attribute value is escaped again on the way out. What it returns is the only unescaped
/// text an article page writes.
///
/// Not reproduced, because the API's HTML no longer holds it (docs/specs/website-port/slice-1-notes.md): tables, footnotes
/// and bare links of GitHub-flavoured Markdown, raw HTML written in an article, and the website's joining of broken
/// reference lines, which works on the Markdown.
/// </summary>
public static partial class ArticleBody
{
    private const string Paragraph = "text-gray-900 dark:text-gray-100 leading-relaxed mb-4";
    private const string ArabicText = "arabic-text";
    private const string ArabicMixed = "arabic-mixed";
    private const string Link = "text-blue-600 dark:text-blue-400 hover:underline";
    private const string ImageFrame = "inline-block max-w-sm mr-4 mb-4 float-left";
    private const string Image = "rounded-lg shadow-md w-full h-auto";
    private const string ImageCaption = "text-xs text-gray-600 dark:text-gray-400 mt-1 block text-center italic";
    private const string CodeBlock = "text-gray-900 dark:text-gray-100 text-sm font-mono";
    private const string CodeInline = "bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 px-1.5 py-0.5 rounded text-sm font-mono";

    /// <summary>Bound on one body (MUST 2): the API stores at most 100,000 characters of Markdown; its HTML is a few times that.</summary>
    private const int MaxCharacters = 2_000_000;

    /// <summary>The elements written with a start and an end tag, each with the classes MarkdownRenderer.tsx gives it (none: written bare).</summary>
    private static readonly Dictionary<string, string> Containers = new(StringComparer.Ordinal)
    {
        ["h1"] = "text-3xl font-bold text-gray-900 dark:text-gray-100 mb-4 mt-8 clear-both",
        ["h2"] = "text-2xl font-bold text-gray-900 dark:text-gray-100 mb-3 mt-6 clear-both",
        ["h3"] = "text-xl font-bold text-gray-900 dark:text-gray-100 mb-3 mt-5 clear-both",
        ["h4"] = string.Empty,
        ["h5"] = string.Empty,
        ["h6"] = string.Empty,
        ["ul"] = "list-disc list-outside ml-6 text-gray-900 dark:text-gray-100 mb-4 space-y-2",
        ["ol"] = "list-decimal list-outside ml-6 text-gray-900 dark:text-gray-100 mb-4 space-y-2",
        ["li"] = "text-gray-900 dark:text-gray-100 leading-relaxed",
        ["blockquote"] = "border-l-4 border-blue-500 dark:border-blue-400 pl-4 py-2 my-4 italic text-gray-800 dark:text-gray-200 bg-blue-50 dark:bg-blue-900/20 rounded-r",
        ["pre"] = "bg-gray-100 dark:bg-gray-900 p-4 rounded-lg overflow-x-auto my-4",
        ["strong"] = "text-gray-900 dark:text-gray-100",
        ["em"] = "text-gray-900 dark:text-gray-100",
    };

    /// <summary>Every class string this renderer can write, so the stylesheet test can see them (hosts/site/tests/StylesheetTests.cs).</summary>
    public static IEnumerable<string> AllClasses =>
        Containers.Values.Concat([Paragraph, ArabicText, ArabicMixed, Link, ImageFrame, Image, ImageCaption, CodeBlock, CodeInline, RuleClasses]);

    private const string RuleClasses = "my-8 border-gray-300 dark:border-gray-700";

    /// <summary>MarkdownRenderer.tsx removes the text's own "Reading Time" line: the page header shows the reading time.</summary>
    [GeneratedRegex(@"Reading Time:\s*[<>]?\s*\d+\s*minutes?\s*\n*", RegexOptions.IgnoreCase, matchTimeoutMilliseconds: 2000)]
    private static partial Regex ReadingTimeLine();

    [GeneratedRegex(@"\s+")]
    private static partial Regex WhiteSpace();

    [GeneratedRegex(@"^language-[\w-]+$")]
    private static partial Regex LanguageClass();

    /// <summary>The body as HTML, safe to write into the page. Throws <see cref="SiteBuildException"/> for HTML it does not know.</summary>
    public static string Render(string html)
    {
        ArgumentNullException.ThrowIfNull(html);
        var html5 = new StringBuilder();
        foreach (var node in Parse(html).Nodes())
        {
            Write(html5, node, insidePre: false);
        }

        return html5.ToString();
    }

    /// <summary>The renderer walks the body by recursion, so the depth it accepts is bounded. No real article comes near it.</summary>
    private const int MaxDepth = 64;

    private static XElement Parse(string html)
    {
        var settings = new XmlReaderSettings
        {
            DtdProcessing = DtdProcessing.Prohibit,
            XmlResolver = null,
            CheckCharacters = false,
            MaxCharactersInDocument = MaxCharacters,
        };
        try
        {
            using var text = new StringReader("<body>" + html + "</body>");
            using var reader = XmlReader.Create(text, settings);
            var body = XElement.Load(reader, LoadOptions.PreserveWhitespace);
            if (body.Descendants().Any(element => element.Ancestors().Take(MaxDepth + 1).Count() > MaxDepth))
            {
                throw new SiteBuildException($"An article body is nested deeper than {MaxDepth} elements; the site is not built.");
            }

            return body;
        }
        catch (XmlException e)
        {
            throw new SiteBuildException("An article body is not the well-formed HTML the API sends (" + e.Message + "); the site is not built.");
        }
    }

    private static void Write(StringBuilder html, XNode node, bool insidePre)
    {
        switch (node)
        {
            case XText text:
                html.Append(Escape(insidePre ? text.Value : ReadingTimeLine().Replace(text.Value, string.Empty)));
                break;
            case XElement element:
                WriteElement(html, element, insidePre);
                break;
            default:
                throw new SiteBuildException($"An article body holds a {node.NodeType} node; the site is not built.");
        }
    }

    private static void WriteElement(StringBuilder html, XElement element, bool insidePre)
    {
        var name = element.Name.LocalName;
        switch (name)
        {
            case "p":
                WriteParagraph(html, element);
                break;
            case "a":
                WriteLink(html, element);
                break;
            case "img":
                WriteImage(html, element);
                break;
            case "code":
                WriteCode(html, element);
                break;
            case "br":
                html.Append("<br>");
                break;
            case "hr":
                html.Append("<hr class=\"").Append(RuleClasses).Append("\">");
                break;
            default:
                WriteContainer(html, element, insidePre || name == "pre");
                break;
        }
    }

    private static void WriteContainer(StringBuilder html, XElement element, bool insidePre)
    {
        var name = element.Name.LocalName;
        if (!Containers.TryGetValue(name, out var classes))
        {
            throw new SiteBuildException($"An article body holds a <{name}> element, which the site does not render; the site is not built.");
        }

        html.Append('<').Append(name);
        if (name == "ol" && int.TryParse(element.Attribute("start")?.Value, out var start))
        {
            html.Append(" start=\"").Append(start).Append('"');
        }

        AppendClass(html, classes);
        html.Append('>');
        WriteChildren(html, element, insidePre);
        html.Append("</").Append(name).Append('>');
    }

    private static void WriteChildren(StringBuilder html, XElement element, bool insidePre)
    {
        foreach (var child in element.Nodes())
        {
            Write(html, child, insidePre);
        }
    }

    /// <summary>
    /// MarkdownRenderer.tsx's p: "arabic-text" when more than half of the characters that are not white space are Arabic script,
    /// "arabic-mixed" when some are. A paragraph that held only the reading time line is not written.
    /// </summary>
    private static void WriteParagraph(StringBuilder html, XElement element)
    {
        var inner = new StringBuilder();
        WriteChildren(inner, element, insidePre: false);
        var text = ReadingTimeLine().Replace(element.Value, string.Empty);
        if (text != element.Value && string.IsNullOrWhiteSpace(text))
        {
            return;
        }

        html.Append("<p");
        AppendClass(html, (Paragraph + " " + ArabicClass(text)).TrimEnd());
        html.Append('>').Append(inner).Append("</p>");
    }

    private static string ArabicClass(string text)
    {
        var arabic = TitleText.ArabicScript().Count(text);
        if (arabic == 0)
        {
            return string.Empty;
        }

        var characters = WhiteSpace().Replace(text, string.Empty).Length;
        return arabic * 2 > characters ? ArabicText : ArabicMixed;
    }

    private static void WriteLink(StringBuilder html, XElement element)
    {
        var address = element.Attribute("href")?.Value;
        var safe = address is not null && IsSafeAddress(address);
        html.Append("<a");
        if (safe)
        {
            AppendAttribute(html, "href", address!);
        }

        AppendAttribute(html, "title", element.Attribute("title")?.Value);
        AppendClass(html, Link);
        if (safe && address!.StartsWith("http", StringComparison.Ordinal))
        {
            html.Append(" target=\"_blank\" rel=\"noopener noreferrer\"");
        }

        html.Append('>');
        WriteChildren(html, element, insidePre: false);
        html.Append("</a>");
    }

    /// <summary>MarkdownRenderer.tsx's img: a floated frame, the picture, and its alternative text as a caption. No address: nothing.</summary>
    private static void WriteImage(StringBuilder html, XElement element)
    {
        var address = element.Attribute("src")?.Value;
        if (string.IsNullOrEmpty(address) || !IsSafeAddress(address))
        {
            return;
        }

        var caption = element.Attribute("alt")?.Value ?? string.Empty;
        html.Append("<span");
        AppendClass(html, ImageFrame);
        html.Append("><img");
        AppendAttribute(html, "src", address);
        AppendAttribute(html, "alt", caption);
        AppendAttribute(html, "title", element.Attribute("title")?.Value);
        AppendClass(html, Image);
        html.Append('>');
        if (caption.Length > 0)
        {
            html.Append("<span");
            AppendClass(html, ImageCaption);
            html.Append('>').Append(Escape(caption)).Append("</span>");
        }

        html.Append("</span>");
    }

    /// <summary>MarkdownRenderer.tsx's code: a block carries a language class or spans lines; anything else is inline.</summary>
    private static void WriteCode(StringBuilder html, XElement element)
    {
        var language = element.Attribute("class")?.Value;
        var hasLanguage = language is not null && LanguageClass().IsMatch(language);
        var isBlock = hasLanguage || element.Value.Contains('\n', StringComparison.Ordinal);
        var style = isBlock ? CodeBlock : CodeInline;
        html.Append("<code");
        AppendClass(html, hasLanguage ? language + " " + style : style);
        html.Append('>');
        WriteChildren(html, element, insidePre: true);
        html.Append("</code>");
    }

    /// <summary>
    /// The API's own rule again (ArticleHtml.IsSafeAddress), so a page never depends on it alone: the scheme is http, https
    /// or mailto, or there is none. White space and control characters are dropped first, as a browser drops them.
    /// </summary>
    private static bool IsSafeAddress(string address)
    {
        var compact = string.Concat(address.Where(c => !char.IsWhiteSpace(c) && !char.IsControl(c)));
        var colon = compact.IndexOf(':', StringComparison.Ordinal);
        if (colon < 0)
        {
            return true;
        }

        var pathStart = compact.IndexOfAny(['/', '?', '#']);
        if (pathStart >= 0 && pathStart < colon)
        {
            return true;
        }

        return compact[..colon].ToLowerInvariant() is "http" or "https" or "mailto";
    }

    private static void AppendClass(StringBuilder html, string classes) =>
        AppendAttribute(html, "class", classes.Length == 0 ? null : classes);

    private static void AppendAttribute(StringBuilder html, string name, string? value)
    {
        if (value is null)
        {
            return;
        }

        html.Append(' ').Append(name).Append("=\"").Append(Escape(value)).Append('"');
    }

    private static string Escape(string text) =>
        text.Replace("&", "&amp;", StringComparison.Ordinal)
            .Replace("<", "&lt;", StringComparison.Ordinal)
            .Replace(">", "&gt;", StringComparison.Ordinal)
            .Replace("\"", "&quot;", StringComparison.Ordinal);
}
