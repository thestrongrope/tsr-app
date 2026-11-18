using System.Net;
using System.Text.RegularExpressions;

namespace Tsr.Content.Site;

// The public Library reads as the site uses them (domains/content/spec/api.yaml, capabilities/library-reads.md): copies of the
// contract's shape, not of the api project's types. The site reads the published contract, like any client. A field the
// site needs and the answer lacks stops the build (ContentSite), so every property here may be null until checked.

/// <summary>The answer shape of the routes under /api/v1/.</summary>
public sealed record V1Answer<T>(bool Success, T? Data, V1Pagination? Pagination);

public sealed record V1Pagination(bool HasMore);

/// <summary>An article as a list, or another article's related list, sends it.</summary>
public sealed record ArticleSummary(string? Slug, string? Title, string? Excerpt, IReadOnlyList<string>? Categories, IReadOnlyList<string>? Tags = null, string? PublishedDate = null);

/// <summary>One article as GET /api/v1/articles/{slug} sends it. <see cref="Content"/> is HTML (rendered and made safe by the API).</summary>
public sealed record Article(
    string? Slug,
    string? Title,
    string? Excerpt,
    IReadOnlyList<string>? Categories,
    IReadOnlyList<string>? Tags,
    int ReadingTime,
    string? Content,
    IReadOnlyList<ArticleSummary>? RelatedArticles);

/// <summary>One category of the flat list (hierarchical=false): a child names its parent.</summary>
public sealed record Category(string? Slug, string? Title, string? Parent, int ArticleCount, string? Description = null);

/// <summary>How the present website shows a title: its HTML entities decoded, right to left when it holds Arabic script.</summary>
public static partial class TitleText
{
    /// <summary>The ranges of containsRTLText (tsr-web app/articles/[slug]/page.tsx) and containsArabic (MarkdownRenderer.tsx).</summary>
    [GeneratedRegex(@"[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]")]
    internal static partial Regex ArabicScript();

    public static string Decode(string? title) => WebUtility.HtmlDecode(title ?? string.Empty);

    public static bool IsRightToLeft(string text) => ArabicScript().IsMatch(text);
}
