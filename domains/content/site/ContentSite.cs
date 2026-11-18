using System.Globalization;
using System.Text.RegularExpressions;
using Tsr.Shared.Site;

namespace Tsr.Content.Site;

/// <summary>
/// content's pages on the static site: the article list and one page per article, read from the public Library routes
/// under /api/v1/ (capabilities/library-reads.md). Those routes hold published articles only, so no draft can reach a page.
/// The home page also reads the categories and the video route; the publications page reads the publications route. The About
/// and Donate pages are fixed text and read nothing; so are the Self-reflection pages (SelfReflection.cs). Every address and slug that goes into a page is checked here, and an answer
/// the pages cannot show stops the build (a video the home page cannot link is the one exception: it is left out with a warning).
/// </summary>
public static partial class ContentSite
{
    private const string SiteName = "The Strong Rope";

    /// <summary>The Donate page's QR image, as its site address. It is a file of the site host (hosts/site/wwwroot).</summary>
    public const string DonateQrImage = "/images/donate-qr.jpeg";

    /// <summary>The home page's three endorsement photos, as site addresses. They are files of the site host (hosts/site/wwwroot).</summary>
    public static readonly IReadOnlyList<string> HomePhotos =
        ["/uploads/naba-accreditation.png", "/uploads/maulana-zeeshan-haider-zaidi.jpg", "/uploads/kazim-sahab.png"];

    /// <summary>The most the list route gives in one answer.</summary>
    private const int PageSize = 100;

    /// <summary>Bound on the list (MUST 2): 200 answers of 100 are the 20,000 files one refresh of the API reads at most.</summary>
    private const int MaxListPages = 200;

    /// <summary>The present website shows four related articles; the API sends five.</summary>
    private const int RelatedShown = 4;

    /// <summary>A slug as a content file writes it: lower-case letters, digits and percent-encoded bytes, in parts joined by '-'.</summary>
    [GeneratedRegex("^(?:[a-z0-9]|%[0-9a-f]{2})+(?:-(?:[a-z0-9]|%[0-9a-f]{2})+)*$")]
    private static partial Regex WrittenSlug();

    /// <summary>
    /// A slug becomes a folder on disk, so only letters, marks, digits and punctuation outside ASCII (a title's Arabic comma) pass,
    /// in parts joined by '-'. No ASCII punctuation at all: no '/', no '\', no '.', no '%', no space.
    /// </summary>
    [GeneratedRegex(@"^(?:[\p{L}\p{M}\p{N}]|[\p{P}-[\x00-\x7F]])+(?:-(?:[\p{L}\p{M}\p{N}]|[\p{P}-[\x00-\x7F]])+)*$")]
    private static partial Regex SafeFolder();

    /// <summary>
    /// A category slug as the present site's category files are named: lower-case letters and digits in parts joined by single dashes.
    /// The API accepts any file name that is one path segment (spec/api.yaml), so this is stricter on purpose: a slug goes into
    /// a link's query and into the script's selectors, and every real slug has this form.
    /// </summary>
    [GeneratedRegex("^[a-z0-9]+(?:-[a-z0-9]+)*$")]
    private static partial Regex CategorySlug();

    public static async Task<IReadOnlyList<SitePage>> PagesAsync(SiteApi api, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(api);
        var summaries = await ReadListAsync(api, ct);
        var categoryList = await ReadCategoriesAsync(api, ct);
        var categories = categoryList.ToDictionary(c => c.Slug!, StringComparer.Ordinal);

        var videos = Home.Videos(await ReadVideosAsync(api, ct), Home.VideosPath, Console.Error.WriteLine);

        var pages = new List<SitePage>
        {
            HomePage(summaries, categoryList, videos),
            new("/articles/", SiteName, typeof(ArticleIndexPage),
                new Dictionary<string, object?>
                {
                    ["Articles"] = summaries,
                    ["Categories"] = categories,
                    ["Panel"] = ArticleFilters.Panel(categoryList),
                    ["FilterData"] = ArticleFilters.DataJson(categoryList, summaries),
                }),
        };

        foreach (var summary in summaries)
        {
            var article = await ReadArticleAsync(api, summary.Slug!, ct);
            var title = TitleText.Decode(article.Title);
            pages.Add(new SitePage($"/articles/{Folder(article.Slug!)}/",$"{title} | {SiteName}", typeof(ArticlePage),
                new Dictionary<string, object?>
                {
                    ["Article"] = article,
                    ["Categories"] = categories,
                    ["Related"] = article.RelatedArticles!.Take(RelatedShown).ToList(),
                },
                Description: article.Excerpt ?? $"Read \"{title}\" on {SiteName}"));
        }

        pages.Add(PublicationsPage(await ReadPublicationsAsync(api, ct)));
        pages.AddRange(FixedPages());
        pages.AddRange(SelfReflection.Pages());
        return pages;
    }

    /// <summary>The home page at the root, with the title and description of the present website's layout.tsx.</summary>
    private static SitePage HomePage(IReadOnlyList<ArticleSummary> summaries, IReadOnlyList<Category> categories, IReadOnlyList<HomeVideo> videos) =>
        new("/", SiteName, typeof(HomePage),
            new Dictionary<string, object?>
            {
                ["Latest"] = Home.Latest(summaries, categories),
                ["Cards"] = ArticleFilters.Cards(categories),
                ["Videos"] = videos,
            },
            Description: "The Path of the Ahle Bait (a.s.)",
            Files: HomePhotos);

    /// <summary>The publications page, with the title and description of the present website's pages/tsr-publications.md.</summary>
    private static SitePage PublicationsPage(IReadOnlyList<Publication> publications) =>
        new("/tsr-publications/", $"TSR Publications - {SiteName}", typeof(PublicationsPage),
            new Dictionary<string, object?> { ["Groups"] = Publications.Groups(publications) },
            Description: "Download the latest publications from The Strong Rope, including Quran resources and study materials in multiple languages.");

    /// <summary>The pages whose text is fixed in their components, with the titles and descriptions of the present website.</summary>
    private static SitePage[] FixedPages()
    {
        var none = new Dictionary<string, object?>();
        return
        [
            new SitePage("/about/", $"About Us | {SiteName}", typeof(AboutPage), none,
                Description: "Learn about The Strong Rope - a cultural, religious, and social organization promoting the teachings of the Holy Quran and Ahlul Bait."),
            new SitePage("/donate/", $"Donate | {SiteName}", typeof(DonatePage), none,
                Description: "Donate to The Strong Rope. Scan the QR code, or use the bank details on this page for a direct transfer.",
                Files: [DonateQrImage]),
        ];
    }

    /// <summary>
    /// The frame's menu, as tsr-web's Navigation.tsx and HamburgerMenu.tsx build it: every category without a parent, in the
    /// API's order, each with those of its children that hold at least one published article.
    /// </summary>
    public static async Task<IReadOnlyList<MenuCategory>> MenuAsync(SiteApi api, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(api);
        var categories = await ReadCategoriesAsync(api, ct);
        return categories
            .Where(category => string.IsNullOrEmpty(category.Parent))
            .Select(parent => new MenuCategory(parent.Slug!, TitleText.Decode(parent.Title), categories
                .Where(child => child.Parent == parent.Slug && child.ArticleCount > 0)
                .Select(child => new MenuCategory(child.Slug!, TitleText.Decode(child.Title), []))
                .ToList()))
            .ToList();
    }

    /// <summary>"N minutes", as tsr-web's article page writes the reading time.</summary>
    public static string ReadingTime(int minutes) =>
        minutes == 1 ? "1 minute" : minutes.ToString(CultureInfo.InvariantCulture) + " minutes";

    private static async Task<IReadOnlyList<ArticleSummary>> ReadListAsync(SiteApi api, CancellationToken ct)
    {
        var summaries = new List<ArticleSummary>();
        for (var page = 0; page < MaxListPages; page++)
        {
            var path = string.Create(CultureInfo.InvariantCulture, $"/api/v1/articles?limit={PageSize}&offset={page * PageSize}");
            var answer = await api.GetAsync<V1Answer<List<ArticleSummary>>>(path, ct);
            var data = Data(answer, path);
            foreach (var summary in data)
            {
                Require(summary.Slug is not null && summary.Title is not null, path, "an article without a slug or a title");
                Require(summary.Categories is not null && summary.Tags is not null, path, "an article without categories or tags");
                Folder(summary.Slug!);
                summaries.Add(summary);
            }

            Require(answer.Pagination is not null, path, "no pagination");
            if (!answer.Pagination!.HasMore)
            {
                return summaries;
            }
        }

        throw new SiteBuildException($"The article list did not end after {MaxListPages} answers; the site is not built.");
    }

    private static async Task<IReadOnlyList<Category>> ReadCategoriesAsync(SiteApi api, CancellationToken ct)
    {
        const string path = "/api/v1/taxonomies/categories?hierarchical=false";
        var categories = Data(await api.GetAsync<V1Answer<List<Category>>>(path, ct), path);
        Require(categories.All(c => c.Slug is not null && c.Title is not null), path, "a category without a slug or a title");
        foreach (var category in categories)
        {
            RequireCategorySlug(category.Slug!, null);
            if (!string.IsNullOrEmpty(category.Parent))
            {
                RequireCategorySlug(category.Parent, category.Slug);
            }
        }

        return categories;
    }

    private static void RequireCategorySlug(string slug, string? childOf)
    {
        if (!CategorySlug().IsMatch(slug))
        {
            var where = childOf is null ? string.Empty : $" (the parent of '{childOf}')";
            throw new SiteBuildException($"Category slug '{slug}'{where} is not lower-case letters, digits and single dashes; the site is not built.");
        }
    }

    /// <summary>The latest videos (spec/api.yaml): the route never fails and sends an empty list when it has none.</summary>
    private static async Task<VideosData> ReadVideosAsync(SiteApi api, CancellationToken ct) =>
        Data(await api.GetAsync<V1Answer<VideosData>>(Home.VideosPath, ct), Home.VideosPath);

    private static async Task<Article> ReadArticleAsync(SiteApi api, string slug, CancellationToken ct)
    {
        var path = "/api/v1/articles/" + slug;
        var article = Data(await api.GetAsync<V1Answer<Article>>(path, ct), path);
        Require(article.Slug == slug, path, "another article's slug");
        Require(article.Title is not null && article.Content is not null, path, "no title or no content");
        Require(article.Categories is not null && article.Tags is not null && article.RelatedArticles is not null, path, "no categories, tags or related articles");
        foreach (var related in article.RelatedArticles!)
        {
            Require(related.Slug is not null && related.Title is not null, path, "a related article without a slug or a title");
            Folder(related.Slug!);
        }

        return article;
    }

    /// <summary>Every publication, in one answer: the route does not page (spec/api.yaml).</summary>
    private static async Task<IReadOnlyList<Publication>> ReadPublicationsAsync(SiteApi api, CancellationToken ct)
    {
        const string path = "/api/v1/publications";
        var publications = Data(await api.GetAsync<V1Answer<List<Publication>>>(path, ct), path);
        Require(publications.All(p => p.Title is not null), path, "a publication without a title");
        Require(publications.All(p => p.File is not null || p.ReadOnlineUrl is not null), path, "a publication with neither a file nor a read-online address");
        foreach (var publication in publications)
        {
            RequireAddress(publication, "file", publication.File, path);
            RequireAddress(publication, "readOnlineUrl", publication.ReadOnlineUrl, path);
        }

        return publications;
    }

    private static void RequireAddress(Publication publication, string field, string? address, string path)
    {
        if (address is not null && !IsAddress(address))
        {
            throw new SiteBuildException(
                $"GET {path} returned the publication '{publication.Title}' with a '{field}' that is not a site or web address (an https address, or a path of one '/' and then a character that is not '/' or a backslash); the site is not built.");
        }
    }

    /// <summary>
    /// An address a page may link to: an absolute https address, or a site path (one leading '/', then not '/' or a backslash). Neither may
    /// hold a backslash, a control character or white space: a browser reads a backslash as '/' and drops tabs and line breaks, so
    /// a backslash after the first '/', or a tab between two, would name another site.
    /// </summary>
    private static bool IsAddress(string address) =>
        address.All(c => c != '\\' && !char.IsControl(c) && !char.IsWhiteSpace(c))
        && (IsSitePath(address) || IsHttps(address));

    private static bool IsSitePath(string address) =>
        address.Length >= 2 && address[0] == '/' && address[1] != '/';

    private static bool IsHttps(string address) =>
        address.StartsWith("https://", StringComparison.Ordinal)
        && Uri.TryCreate(address, UriKind.Absolute, out var uri)
        && uri.Scheme == Uri.UriSchemeHttps
        && uri.Host.Length > 0;

    private static T Data<T>(V1Answer<T> answer, string path)
        where T : class
    {
        Require(answer.Success && answer.Data is not null, path, "no data");
        return answer.Data!;
    }

    private static void Require(bool condition, string path, string problem)
    {
        if (!condition)
        {
            throw new SiteBuildException($"GET {path} returned {problem}; the site is not built.");
        }
    }

    /// <summary>
    /// The folder an article is written to: its slug with every percent-encoded byte decoded, because the server decodes the
    /// address a browser sends before it looks for the folder. Links keep the slug as written. A slug that is not written
    /// as a slug, or whose decoded text is not a safe folder name, stops the build.
    /// </summary>
    private static string Folder(string slug)
    {
        var folder = WrittenSlug().IsMatch(slug) ? Uri.UnescapeDataString(slug) : string.Empty;
        if (!SafeFolder().IsMatch(folder))
        {
            throw new SiteBuildException($"Article slug '{slug}' is not a safe path; the site is not built.");
        }

        return folder;
    }
}
