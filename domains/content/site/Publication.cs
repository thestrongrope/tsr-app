using System.Globalization;

namespace Tsr.Content.Site;

/// <summary>
/// One publication as GET /api/v1/publications sends it (spec/api.yaml, V1Publication). Every value is plain text, never HTML.
/// A field the content file lacks is left out of the answer, so it is null here.
/// </summary>
public sealed record Publication(
    string? Title,
    string? Summary,
    string? Type,
    string? Size,
    string? Updated,
    string? Language,
    string? File,
    string? ReadOnlineUrl,
    bool DownloadOnly);

/// <summary>One tab of the publications page: a language and its publications, sorted by title.</summary>
public sealed record PublicationGroup(string Language, IReadOnlyList<Publication> Items);

/// <summary>The rules of the publications page, as tsr-web's app/tsr-publications/page.tsx and components/PublicationsTabs.tsx have them.</summary>
public static class Publications
{
    private const string FirstLanguage = "English";

    private const string NoLanguage = "Other";

    /// <summary>
    /// The order a reader expects, as the present site's localeCompare gives it: by letter before by case, so "beta" stands
    /// between "Alpha" and "Zeta". The invariant culture, so every build machine sorts alike.
    /// </summary>
    private static readonly StringComparer ReaderOrder = StringComparer.Create(CultureInfo.InvariantCulture, ignoreCase: false);

    /// <summary>
    /// The tabs: one per language (the name trimmed; "Other" for a publication without one), English first and the rest by
    /// name, each tab's publications by title.
    /// </summary>
    public static IReadOnlyList<PublicationGroup> Groups(IReadOnlyList<Publication> publications)
    {
        ArgumentNullException.ThrowIfNull(publications);
        return publications
            .GroupBy(LanguageOf, StringComparer.Ordinal)
            .Select(group => new PublicationGroup(group.Key, group.OrderBy(p => p.Title, ReaderOrder).ToList()))
            .OrderBy(group => group.Language != FirstLanguage)
            .ThenBy(group => group.Language, ReaderOrder)
            .ToList();
    }

    /// <summary>The line above a tab when the search finds nothing. The script shows it, with the next two, from the page's data- attributes.</summary>
    public const string NoMatches = "No matches";

    /// <summary>The line above a tab for one publication.</summary>
    public const string OneAvailable = "1 publication available";

    /// <summary>The line above a tab for any other number; "{count}" is where the script puts it.</summary>
    public const string ManyAvailable = "{count} publications available";

    /// <summary>"1 publication", "3 publications".</summary>
    public static string Count(int count) => Counted(count, "publication");

    /// <summary>"1 publication available", "3 publications available": the line above a tab before any search.</summary>
    public static string Available(int count) => Count(count) + " available";

    /// <summary>"1 language", "3 languages".</summary>
    public static string Counted(int count, string noun) =>
        count.ToString(CultureInfo.InvariantCulture) + " " + noun + (count == 1 ? string.Empty : "s");

    /// <summary>A size or a date as the card shows it: trimmed, and a dash when the route sends none.</summary>
    public static string Detail(string? value) => string.IsNullOrWhiteSpace(value) ? "\u2014" : value.Trim();

    /// <summary>As an article's title: right aligned when the text holds Arabic script.</summary>
    public static string? RightAligned(string text) => TitleText.IsRightToLeft(text) ? "text-right" : null;

    /// <summary>As an article's title: right to left when the text holds Arabic script.</summary>
    public static string? Direction(string text) => TitleText.IsRightToLeft(text) ? "direction: rtl" : null;

    /// <summary>
    /// "ur" for a right-to-left text of an Urdu publication: the stylesheet's [lang="ur"] rule gives it the Urdu font. Any other
    /// right-to-left text keeps the page's font, as an article's title does.
    /// </summary>
    public static string? Lang(string text, string? language) =>
        TitleText.IsRightToLeft(text) && string.Equals(language?.Trim(), "Urdu", StringComparison.OrdinalIgnoreCase) ? "ur" : null;

    private static string LanguageOf(Publication publication) =>
        string.IsNullOrWhiteSpace(publication.Language) ? NoLanguage : publication.Language.Trim();
}
