using System.Text.RegularExpressions;
using Markdig;
using Markdig.Extensions.Tables;
using Markdig.Renderers.Html;
using Markdig.Syntax;
using Markdig.Syntax.Inlines;
using Tsr.Shared.Site;

namespace Tsr.Content.Site;

/// <summary>A link to another fixed page: its slug and its title.</summary>
public sealed record FixedPageLink(string Slug, string Title);

/// <summary>
/// The fixed pages: public content only the site shows, read at build time from <c>content/pages/*.md</c> of the repository
/// (copied beside the program as <c>content-pages/</c>, hosts/site/Tsr.Host.Site.csproj), each shown at <c>/slug/</c>.
/// The files are the organisation's own reviewed text, so raw HTML in them is kept. The page route of the old website
/// (app/[slug]/page.tsx) is mirrored: the title is the meta title when there is one, the previous, next and contents links
/// show when their page exists, and the publications page has its own component. Not reproduced: the footnotes' hover text.
/// </summary>
public static partial class PageFiles
{
    private const string PublicationsPage = "tsr-publications";

    /// <summary>Bounds (MUST 2): the repository holds about 30 pages; the longest file is 125 KB.</summary>
    private const int MaxPages = 200;

    private const long MaxFileBytes = 2_000_000;

    private static readonly MarkdownPipeline Pipeline = new MarkdownPipelineBuilder().UseFootnotes().UsePipeTables().UseAutoLinks().UseEmphasisExtras().Build();

    public static string DefaultFolder => Path.Combine(AppContext.BaseDirectory, "content-pages");

    [GeneratedRegex("^[a-z0-9]+(?:-[a-z0-9]+)*$")]
    private static partial Regex SafeSlug();

    [GeneratedRegex("/uploads/[^\\s)\"'<>?#]+")]
    private static partial Regex UploadAddress();

    private sealed record Page(string Slug, string Title, string MetaTitle, string MetaDescription, string? Parent, string? Previous, string? Next, string Markdown);

    /// <summary>The page of every file in <paramref name="folder"/> but the publications page. A slug that an article also has, a missing folder or a file this cannot read stops the build.</summary>
    public static IReadOnlyList<SitePage> Pages(string folder, IReadOnlyCollection<string> articleSlugs)
    {
        ArgumentNullException.ThrowIfNull(articleSlugs);
        if (!Directory.Exists(folder))
        {
            throw new SiteBuildException($"The fixed pages folder {folder} is missing; the site is not built.");
        }

        var files = Directory.EnumerateFiles(folder, "*.md").Order(StringComparer.Ordinal).Take(MaxPages + 1).ToList();
        if (files.Count > MaxPages)
        {
            throw new SiteBuildException($"The fixed pages folder {folder} holds more than {MaxPages} files; the site is not built.");
        }

        var pages = files.Where(file => Path.GetFileNameWithoutExtension(file) != PublicationsPage).Select(Read).ToDictionary(page => page.Slug, StringComparer.Ordinal);
        var clash = articleSlugs.FirstOrDefault(pages.ContainsKey);
        if (clash is not null)
        {
            throw new SiteBuildException($"The fixed page {clash} and an article have the same slug; the site is not built.");
        }

        return [.. pages.Values.Select(page => ToSitePage(page, pages))];
    }

    private static SitePage ToSitePage(Page page, Dictionary<string, Page> pages)
    {
        var html = Body(page.Markdown);
        var contents = page.Parent is null ? null : page.Parent.Replace("-preface", string.Empty, StringComparison.Ordinal) + "-toc";
        return new SitePage(
            $"/{page.Slug}/",
            page.MetaTitle.Length > 0 ? page.MetaTitle : page.Title,
            typeof(FixedPage),
            new Dictionary<string, object?>
            {
                ["Title"] = page.Title,
                ["Html"] = html,
                ["Wide"] = page.Slug == "accreditation",
                ["Previous"] = Link(page.Previous, pages),
                ["Next"] = Link(page.Next, pages),
                ["Contents"] = Link(contents, pages),
            },
            Description: page.MetaDescription.Length > 0 ? page.MetaDescription : null,
            Files: [.. UploadAddress().Matches(html).Select(match => match.Value).Distinct(StringComparer.Ordinal)]);
    }

    private static FixedPageLink? Link(string? slug, Dictionary<string, Page> pages) =>
        slug is not null && pages.TryGetValue(slug, out var target) ? new FixedPageLink(target.Slug, target.Title) : null;

    private static Page Read(string file)
    {
        var slug = Path.GetFileNameWithoutExtension(file);
        if (!SafeSlug().IsMatch(slug))
        {
            throw new SiteBuildException($"The fixed page file {Path.GetFileName(file)} has a name that is not a slug; the site is not built.");
        }

        if (new FileInfo(file).Length > MaxFileBytes)
        {
            throw new SiteBuildException($"The fixed page file {Path.GetFileName(file)} is larger than {MaxFileBytes} bytes; the site is not built.");
        }

        var text = File.ReadAllText(file).Replace("\r\n", "\n", StringComparison.Ordinal);
        var end = text.StartsWith("---\n", StringComparison.Ordinal) ? text.IndexOf("\n---\n", 3, StringComparison.Ordinal) : -1;
        if (end < 0)
        {
            throw new SiteBuildException($"The fixed page file {Path.GetFileName(file)} has no front matter between two --- lines; the site is not built.");
        }

        var values = FrontMatter(text[4..end]);
        var title = values.GetValueOrDefault("title");
        if (string.IsNullOrWhiteSpace(title))
        {
            throw new SiteBuildException($"The fixed page file {Path.GetFileName(file)} has no title; the site is not built.");
        }

        return new Page(
            slug, title, values.GetValueOrDefault("metaTitle") ?? string.Empty, values.GetValueOrDefault("metaDescription") ?? string.Empty,
            values.GetValueOrDefault("parent"), values.GetValueOrDefault("prevPage"), values.GetValueOrDefault("nextPage"), text[(end + 5)..]);
    }

    /// <summary>The page files write one "key: value" per line, the value bare or in double quotes, with no escapes: split at the first colon and drop one pair of quotes.</summary>
    private static Dictionary<string, string> FrontMatter(string block)
    {
        var values = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var line in block.Split('\n'))
        {
            var colon = line.IndexOf(':', StringComparison.Ordinal);
            if (colon <= 0 || line[0] == ' ' || line[0] == '-')
            {
                continue;
            }

            var value = line[(colon + 1)..].Trim();
            if (value.Length >= 2 && value[0] == '"' && value[^1] == '"')
            {
                value = value[1..^1];
            }

            values[line[..colon]] = value;
        }

        return values;
    }

    /// <summary>MarkdownRenderer.tsx's text clean-up, then Markdown to HTML with raw HTML kept and the classes of ArticleBody on the elements it styles.</summary>
    private static string Body(string markdown)
    {
        var document = Markdown.Parse(Clean(markdown), Pipeline);
        foreach (var node in document.Descendants())
        {
            var classes = ClassesOf(node);
            if (classes.Length > 0)
            {
                node.GetAttributes().AddClass(classes);
            }
        }

        return document.ToHtml(Pipeline);
    }

    private static string ClassesOf(MarkdownObject node) => node switch
    {
        ParagraphBlock paragraph => (ArticleBody.Paragraph + " " + ArticleBody.ArabicClass(PlainText(paragraph))).TrimEnd(),
        HeadingBlock heading => ArticleBody.Containers.GetValueOrDefault("h" + Math.Min(heading.Level, 6), string.Empty),
        ListBlock list => ArticleBody.Containers[list.IsOrdered ? "ol" : "ul"],
        ListItemBlock => ArticleBody.Containers["li"],
        QuoteBlock => ArticleBody.Containers["blockquote"],
        LinkInline { IsImage: false } => ArticleBody.Link,
        LinkInline => ArticleBody.Image,
        Table => ArticleBody.Table,
        TableCell cell => cell.Parent is TableRow { IsHeader: true } ? ArticleBody.HeaderCell : ArticleBody.Cell,
        _ => string.Empty,
    };

    private static string PlainText(ParagraphBlock paragraph) =>
        paragraph.Inline is null ? string.Empty : string.Concat(paragraph.Inline.Descendants<LiteralInline>().Select(literal => literal.Content.ToString()));

    [GeneratedRegex(@"Reading Time:\s*[<>]?\s*\d+\s*minutes?\s*\n*", RegexOptions.IgnoreCase)]
    private static partial Regex ReadingTime();

    [GeneratedRegex(@"^(\d+)\.\s{2,}", RegexOptions.Multiline)]
    private static partial Regex ListSpacing();

    [GeneratedRegex(@",\n(?!\s*[-*#])(vol\.|p\.|H\.)")]
    private static partial Regex JoinTitleVolume();

    [GeneratedRegex(@"(\b(?:vol|p)\.\s*\d+),?\n(?!\s*[-*#\d])")]
    private static partial Regex JoinVolumePage();

    [GeneratedRegex(@"(\bp\.\s*)\n\s*(\d)")]
    private static partial Regex JoinPageNumber();

    [GeneratedRegex(@"(\d+),\s*\n\s*(H\.\s*\d)")]
    private static partial Regex JoinHadithNumber();

    [GeneratedRegex(@"\n(?!\s*[-*#])(vol\.\s*\d+)")]
    private static partial Regex JoinOrphanVolume();

    [GeneratedRegex(@"^(\d+\.\s+[^\n]+)\n\n+(\d+\.\s+)", RegexOptions.Multiline)]
    private static partial Regex JoinListItems();

    /// <summary>The website's clean-up of a page's text before it is rendered (MarkdownRenderer.tsx), in its order: the reading time goes, broken reference lines are joined.</summary>
    private static string Clean(string text)
    {
        text = ReadingTime().Replace(text, string.Empty);
        text = ListSpacing().Replace(text, "$1. ");
        text = JoinTitleVolume().Replace(text, ", $1");
        text = JoinVolumePage().Replace(text, "$1, ");
        text = JoinPageNumber().Replace(text, "$1$2");
        text = JoinHadithNumber().Replace(text, "$1, $2");
        text = JoinOrphanVolume().Replace(text, " $1");
        return JoinListItems().Replace(text, "$1\n$2");
    }
}
