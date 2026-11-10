using System.Text.RegularExpressions;
using Tsr.Shared.Site;

namespace Tsr.Content.Site;

/// <summary>content's pages on the static site: the article list and one page per article.</summary>
public static partial class ContentSite
{
    /// <summary>A slug becomes a folder on disk, so only safe characters pass (no '/', no '..').</summary>
    [GeneratedRegex("^[a-z0-9]+(-[a-z0-9]+)*$")]
    private static partial Regex SafeSlug();

    public static async Task<IReadOnlyList<SitePage>> PagesAsync(SiteApi api, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(api);
        var list = await api.GetAsync<ArticleList>("/articles", ct);

        var pages = new List<SitePage>
        {
            new("/articles/", "Articles", typeof(ArticleIndexPage),
                new Dictionary<string, object?> { ["Articles"] = list.Articles }, NavTitle: "Articles"),
        };

        foreach (var article in list.Articles)
        {
            if (!SafeSlug().IsMatch(article.Slug))
            {
                throw new SiteBuildException($"Article slug '{article.Slug}' is not a safe path; the site is not built.");
            }

            pages.Add(new SitePage($"/articles/{article.Slug}/", article.Title, typeof(ArticlePage),
                new Dictionary<string, object?> { ["Article"] = article }));
        }

        return pages;
    }
}
