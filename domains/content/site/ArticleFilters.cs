using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Tsr.Shared.Site;

namespace Tsr.Content.Site;

/// <summary>One entry of the filter panel: a category that holds published articles, with its children that do.</summary>
public sealed record FilterCategory(string Slug, string Title, int Count, IReadOnlyList<FilterCategory> Children);

/// <summary>
/// The rules of the article list's filters, as tsr-web's ArticlesList.tsx and CategoryFilter.tsx have them. They are applied
/// when the site is built; the script (hosts/site/wwwroot/site.js) only compares strings and shows or hides.
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
    /// an article; counted here over the articles, by the slug itself (a parent does not count its children's articles). An
    /// entry without an article of its own is left out, and so is the whole of a parent without one.
    /// </summary>
    public static IReadOnlyList<FilterCategory> Panel(IReadOnlyList<Category> categories, IReadOnlyList<ArticleSummary> articles)
    {
        ArgumentNullException.ThrowIfNull(categories);
        ArgumentNullException.ThrowIfNull(articles);
        var counts = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var slug in articles.SelectMany(article => article.Categories ?? []))
        {
            counts[slug] = counts.GetValueOrDefault(slug) + 1;
        }

        return categories
            .Where(category => string.IsNullOrEmpty(category.Parent) && counts.GetValueOrDefault(category.Slug!) > 0)
            .Select(parent => new FilterCategory(parent.Slug!, TitleText.Decode(parent.Title), counts[parent.Slug!], categories
                .Where(child => child.Parent == parent.Slug && counts.GetValueOrDefault(child.Slug!) > 0)
                .Select(child => new FilterCategory(child.Slug!, TitleText.Decode(child.Title), counts[child.Slug!], []))
                .ToList()))
            .ToList();
    }

    private sealed record CategoryInfo(string Title, string? Parent, string? Description, string? Chip);

    private sealed record Data(Dictionary<string, CategoryInfo> Categories, Dictionary<string, string> Tags);

    /// <summary>
    /// What the script needs to word the heading: each category's title, its parent's title, its description and the title the
    /// filter's chip shows (only for a category in the panel: the present site's chip falls back to the slug for the others);
    /// and, for each tag slug, the first spelling met walking the articles in list order.
    /// </summary>
    public static string DataJson(IReadOnlyList<Category> categories, IReadOnlyList<ArticleSummary> articles)
    {
        ArgumentNullException.ThrowIfNull(categories);
        ArgumentNullException.ThrowIfNull(articles);
        var titles = categories.ToDictionary(category => category.Slug!, category => TitleText.Decode(category.Title), StringComparer.Ordinal);
        var inPanel = Panel(categories, articles).SelectMany(parent => parent.Children.Prepend(parent)).Select(entry => entry.Slug).ToHashSet(StringComparer.Ordinal);
        var data = new Data(new Dictionary<string, CategoryInfo>(StringComparer.Ordinal), new Dictionary<string, string>(StringComparer.Ordinal));
        foreach (var category in categories)
        {
            var parentTitle = category.Parent is not null && titles.TryGetValue(category.Parent, out var title) ? title : null;
            var description = string.IsNullOrEmpty(category.Description) ? null : TitleText.Decode(category.Description);
            data.Categories[category.Slug!] = new CategoryInfo(titles[category.Slug!], parentTitle, description, inPanel.Contains(category.Slug!) ? titles[category.Slug!] : null);
        }

        foreach (var tag in articles.SelectMany(article => article.Tags ?? []))
        {
            data.Tags.TryAdd(Slugify(tag), tag);
        }

        return JsonSerializer.Serialize(data, Json);
    }
}
