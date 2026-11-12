using Tsr.Shared.Api;

namespace Tsr.Search.Api.Domain;

/// <summary>A valid request: the trimmed text to look for and the kinds to search, in the order given.</summary>
internal sealed record ParsedSearch(string Text, IReadOnlyList<string> Kinds);

/// <summary>
/// What <c>q</c> and <c>kinds</c> may be (PHP route_search, search.php:29). <c>q</c>: trimmed (PHP trim, which also strips NUL), 2 to 100
/// characters (code points, as mb_strlen), and, stricter than PHP, no NUL inside it. <c>kinds</c>: a comma list of the known kinds (all when
/// blank); empty items and "0" are dropped as PHP's array_filter does, duplicates once, an unknown kind refuses the request.
/// </summary>
internal static class SearchRequestRules
{
    public const int MinLength = 2;

    public const int MaxLength = 100;

    private static readonly char[] PhpTrim = [' ', '\t', '\n', '\r', '\0', '\v'];

    public static Result<ParsedSearch> Parse(string? q, string? kinds)
    {
        var text = (q ?? string.Empty).Trim(PhpTrim);
        var length = text.EnumerateRunes().Count();
        if (length < MinLength)
        {
            return Result.Fail<ParsedSearch>("q must be at least 2 characters");
        }

        if (length > MaxLength)
        {
            return Result.Fail<ParsedSearch>("q must be at most 100 characters");
        }

        if (text.Contains('\0'))
        {
            return Result.Fail<ParsedSearch>("q must not contain NUL characters");
        }

        var asked = (kinds ?? string.Empty).Trim(PhpTrim);
        if (asked.Length == 0)
        {
            return Result.Ok(new ParsedSearch(text, SearchPlans.Kinds));
        }

        var list = asked.Split(',')
            .Select(k => k.Trim(PhpTrim))
            .Where(k => k.Length > 0 && k != "0")
            .Distinct(StringComparer.Ordinal)
            .ToList();
        return list.Exists(k => !SearchPlans.Kinds.Contains(k))
            ? Result.Fail<ParsedSearch>("kinds must be a list of " + string.Join(", ", SearchPlans.Kinds))
            : Result.Ok(new ParsedSearch(text, list));
    }
}
