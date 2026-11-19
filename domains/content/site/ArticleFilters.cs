using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Tsr.Shared.Site;

namespace Tsr.Content.Site;

/// <summary>One entry of the filter panel: a category that holds published articles, with its children that do.</summary>
public sealed record FilterCategory(string Slug, string Title, int Count, IReadOnlyList<FilterCategory> Children, string? Description = null);

/// <summary>
/// The rules of the article list's filters, as tsr-web's ArticlesList.tsx and CategoryFilter.tsx have them. They are applied
/// when the site is built; the script (hosts/site/wwwroot/site.js) reads the address, compares strings, fills the page's own words with a name and shows or hides.
/// </summary>
public static partial class ArticleFilters
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    [GeneratedRegex("[^a-z0-9]+")]
    private static partial Regex OtherRun();

    /// <summary>
    /// ArticlesList.tsx's slugify: lower case, every run of characters outside a-z and 0-9 one dash, no dash at either end.
    /// The present site compares a tag three ways (exact, case-insensitive, slugified); the slugified match holds whenever
    /// the other two do, so this is the one comparison. U+0130 is spelled as JavaScript's toLowerCase spells it.
    /// </summary>
    public static string Slugify(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        var lower = text.Replace("İ", "i̇",StringComparison.Ordinal).ToLowerInvariant();
        return OtherRun().Replace(lower, "-").Trim('-');
    }

    /// <summary>
    /// A card's values as the script compares them: each between pipes, "|a|b|", nothing for none. A pipe cannot be in a
    /// value, or "a|b" would match a card holding a and b.
    /// </summary>
    public static string Tokens(IEnumerable<string> values)
    {
        ArgumentNullException.ThrowIfNull(values);
        var list = values.ToList();
        if (list.Any(value => value.Contains('|', StringComparison.Ordinal)))
        {
            throw new SiteBuildException("A category or tag holds a '|'; the article list cannot filter by it, so the site is not built.");
        }

        return list.Count == 0 ? string.Empty : "|" + string.Join('|', list) + "|";
    }

    /// <summary>
    /// The panel of app/articles/page.tsx: the categories without a parent, in the API's order, each with the children that hold
    /// an article; the count of an entry is the route's articleCount, the published articles filed under the slug itself (a
    /// parent does not count its children's articles, spec/api.yaml). An entry without an article of its own is left out, and so
    /// is the whole of a parent without one.
    /// </summary>
    public static IReadOnlyList<FilterCategory> Panel(IReadOnlyList<Category> categories) =>
        Cards(categories).Where(parent => parent.Count > 0).ToList();

    /// <summary>
    /// The home page's category cards (app/page.tsx): the same tree and counts as <see cref="Panel"/>, but every parent is kept,
    /// also one without an article of its own (it shows 0, and its children that hold an article). Children without an
    /// article are left out. Each entry carries its description.
    /// </summary>
    public static IReadOnlyList<FilterCategory> Cards(IReadOnlyList<Category> categories)
    {
        ArgumentNullException.ThrowIfNull(categories);
        return categories
            .Where(category => string.IsNullOrEmpty(category.Parent))
            .Select(parent => new FilterCategory(parent.Slug!, TitleText.Decode(parent.Title), parent.ArticleCount, categories
                .Where(child => child.Parent == parent.Slug && child.ArticleCount > 0)
                .Select(child => new FilterCategory(child.Slug!, TitleText.Decode(child.Title), child.ArticleCount, [], Described(child)))
                .ToList(), Described(parent)))
            .ToList();
    }

    private static string? Described(Category category) =>
        string.IsNullOrEmpty(category.Description) ? null : TitleText.Decode(category.Description);

    private sealed record CategoryInfo(string Title, string? Parent, string? Description, string? Chip);

    /// <summary>
    /// Every sentence the script shows for a filter, written once here; "{name}" is where the script puts a tag. The unfiltered
    /// heading and description in ArticleIndexPage.razor are written from <see cref="AllArticles"/> and <see cref="DefaultDescription"/>.
    /// </summary>
    private sealed record Texts(
        string AllArticles, string DefaultDescription, string TagTitle, string TagDescription, string TagChip,
        string NoneTitle, string NoneInCategory, string NoneWithTag, string HintTag, string HintCategory);

    private sealed record Data(Texts Texts, Dictionary<string, CategoryInfo> Categories, Dictionary<string, string> Tags);

    /// <summary>The heading of the unfiltered list.</summary>
    public const string AllArticles = "All Articles";

    /// <summary>The line under a heading that has no description of its own.</summary>
    public const string DefaultDescription = "Explore our collection of articles on the path of the Ahle Bait (a.s.)";

    private static readonly Texts Words = new(
        AllArticles,
        DefaultDescription,
        "Articles tagged \u201C{name}\u201D",
        "Showing all articles with the tag \"{name}\"",
        "Tag: {name}",
        "No articles found",
        " in this category",
        " with tag \"{name}\"",
        "Try selecting a different tag",
        "Try selecting a different category");

    /// <summary>
    /// What the script needs to word the heading: the words themselves, each category's title, its parent's title, its description and the title the
    /// filter's chip shows (only for a category in the panel: the present site's chip falls back to the slug for the others);
    /// and, for each tag slug, the first spelling met walking the articles in list order.
    /// </summary>
    public static string DataJson(IReadOnlyList<Category> categories, IReadOnlyList<ArticleSummary> articles)
    {
        ArgumentNullException.ThrowIfNull(categories);
        ArgumentNullException.ThrowIfNull(articles);
        var titles = categories.ToDictionary(category => category.Slug!, category => TitleText.Decode(category.Title), StringComparer.Ordinal);
        var inPanel = Panel(categories).SelectMany(parent => parent.Children.Prepend(parent)).Select(entry => entry.Slug).ToHashSet(StringComparer.Ordinal);
        var data = new Data(Words, new Dictionary<string, CategoryInfo>(StringComparer.Ordinal), new Dictionary<string, string>(StringComparer.Ordinal));
        foreach (var category in categories)
        {
            var parentTitle = category.Parent is not null && titles.TryGetValue(category.Parent, out var title) ? title : null;
            data.Categories[category.Slug!] = new CategoryInfo(titles[category.Slug!], parentTitle, Described(category), inPanel.Contains(category.Slug!) ? titles[category.Slug!] : null);
        }

        foreach (var tag in articles.SelectMany(article => article.Tags ?? []))
        {
            data.Tags.TryAdd(Slugify(tag), tag);
        }

        return JsonSerializer.Serialize(data, Json);
    }
}
