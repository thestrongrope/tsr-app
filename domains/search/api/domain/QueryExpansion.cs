using System.Text.RegularExpressions;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// How the website widens a search text before it asks Elasticsearch, ported from tsr-web <c>web/src/app/api/lib/search-service.ts</c> (the lecture search holds a copy of the same code):
/// <c>normalizeArabicTransliteration</c>, the synonym table and the expansion loop of <c>searchArticlesElasticsearch</c>, and <c>extractSearchTerms</c>.
/// The order of every replacement and of the synonym table is part of the answer. JavaScript's own rules are kept: <c>$</c> is the end of the text only (<c>\z</c> here),
/// a name is replaced once, and white space is JavaScript's <c>\s</c>. The output only ever goes into JSON string values (SRCH-Q3).
/// One difference, on purpose: tsr-web throws on a term called <c>constructor</c> (it reads the synonym table as an object and calls <c>join</c> on a function, which gives a 500); here that term has no synonyms.
/// Lower-casing is the invariant culture's, which equals JavaScript's for every letter except a few (for example a dotted capital I).
/// </summary>
internal static partial class QueryExpansion
{
    private static readonly (string Key, string[] Synonyms)[] SynonymTable =
    [
        ("fight", ["war", "battle", "conflict", "combat"]),
        ("war", ["fight", "battle", "conflict", "combat"]),
        ("tears", ["weep", "weeping", "crying", "cry"]),
        ("weep", ["tears", "weeping", "crying", "cry"]),
        ("ameerul momineen", ["imam ali", "ali ibn abi talib", "ali"]),
        ("imam ali", ["ameerul momineen", "ali ibn abi talib", "amirul momineen"]),
        ("imam husain", ["imam hussain", "hussain", "husain", "aba abdillah"]),
        ("imam hussain", ["imam husain", "hussain", "husain", "aba abdillah"]),
        ("imam mahdi", ["qaim", "hujjat", "sahib al-zaman", "imam zamana"]),
        ("qaim", ["imam mahdi", "hujjat", "sahib al-zaman"]),
        ("lady fatima", ["fatimah", "fatemah", "zahra", "hazrat fatima"]),
        ("fatemah", ["fatimah", "fatima", "zahra", "lady fatima"]),
        ("dhahabi", ["zahabi", "dahabi", "thahabi"]),
        ("zahabi", ["dhahabi", "dahabi", "thahabi"]),
        ("husain", ["hussain", "husayn", "hussein"]),
        ("hussain", ["husain", "husayn", "hussein"]),
        ("jafar", ["jaafar", "ja'far", "jaffar"]),
        ("sadiq", ["sadeq", "sadek", "saadiq"]),
    ];

    private static readonly (string Name, string Expansion)[] NameExpansions =
    [
        ("ameerul momineen", "imam ali"),
        ("amirul momineen", "imam ali"),
        ("aba abdillah", "imam husain"),
        ("qaim", "imam mahdi"),
        ("sahib al-zaman", "imam mahdi"),
    ];

    private static readonly HashSet<string> Stopwords = new(StringComparer.Ordinal)
    {
        "the", "a", "an", "of", "in", "on", "at", "to", "for", "and", "or", "is", "are", "was", "were", "be", "been", "being", "have", "has", "had",
        "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "shall", "can", "need", "dare", "ought", "used",
        "a.s.", "a.s", "s.a.", "peace", "upon", "him", "her", "them", "a.t.f.s.", "a.t.f.s",
    };

    /// <summary>The text with the Franco-Arab digits turned into letters and the spelling variants folded, as the website does it.</summary>
    public static string Normalize(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        var s = text.ToLowerInvariant()
            .Replace("2", string.Empty, StringComparison.Ordinal)
            .Replace("3", string.Empty, StringComparison.Ordinal)
            .Replace("5", "kh", StringComparison.Ordinal)
            .Replace("6", "t", StringComparison.Ordinal)
            .Replace("7", "h", StringComparison.Ordinal)
            .Replace("8", "q", StringComparison.Ordinal)
            .Replace("9", "s", StringComparison.Ordinal);
        s = DoubleA().Replace(s, "a");
        s = DoubleE().Replace(s, "i");
        s = DoubleI().Replace(s, "i");
        s = DoubleO().Replace(s, "u");
        s = DoubleU().Replace(s, "u");
        s = s.Replace("dh", "z", StringComparison.Ordinal)
            .Replace("th", "s", StringComparison.Ordinal)
            .Replace("gh", "g", StringComparison.Ordinal)
            .Replace("kh", "k", StringComparison.Ordinal)
            .Replace("sh", "s", StringComparison.Ordinal);
        s = EndAh().Replace(s, "a");
        s = EndEh().Replace(s, "a");
        s = EndHOrP().Replace(s, string.Empty);
        s = EndY().Replace(s, "i");
        s = EndEy().Replace(s, "i");
        return s
            .Replace("hussain", "husain", StringComparison.Ordinal)
            .Replace("hussein", "husain", StringComparison.Ordinal)
            .Replace("husein", "husain", StringComparison.Ordinal);
    }

    /// <summary>The text for the "expanded" clause: the text, its normal form, then the synonyms of every table key found in either, in table order.</summary>
    public static string Expand(string query)
    {
        ArgumentNullException.ThrowIfNull(query);
        var normalized = Normalize(query);
        var lower = query.ToLowerInvariant();
        var expanded = query + " " + normalized;
        foreach (var (key, synonyms) in SynonymTable)
        {
            if (lower.Contains(key, StringComparison.Ordinal) || normalized.Contains(key, StringComparison.Ordinal))
            {
                expanded += " " + string.Join(' ', synonyms);
            }
        }

        return expanded;
    }

    /// <summary>The concept terms of a text: names expanded once each, white space split, words of two characters or fewer and stopwords dropped, <c>imam</c> joined to the next word.</summary>
    public static IReadOnlyList<string> ExtractTerms(string query)
    {
        ArgumentNullException.ThrowIfNull(query);
        var expanded = query.ToLowerInvariant();
        foreach (var (name, expansion) in NameExpansions)
        {
            var at = expanded.IndexOf(name, StringComparison.Ordinal);
            if (at >= 0)
            {
                expanded = string.Concat(expanded.AsSpan(0, at), expansion, expanded.AsSpan(at + name.Length));
            }
        }

        var words = SplitOnScriptWhiteSpace(expanded).Where(word => word.Length > 2 && !Stopwords.Contains(word)).ToList();
        var terms = new List<string>(words.Count);
        var i = 0;
        while (i < words.Count)
        {
            if (words[i] == "imam" && i + 1 < words.Count)
            {
                terms.Add(words[i] + " " + words[i + 1]);
                i += 2;
            }
            else
            {
                terms.Add(words[i]);
                i++;
            }
        }

        return terms;
    }

    /// <summary>The text of one term's <c>multi_match</c>: the term, a space, then its synonyms (none gives a trailing space, as the website sends it).</summary>
    public static string TermQuery(string term)
    {
        ArgumentNullException.ThrowIfNull(term);
        var lower = term.ToLowerInvariant();
        foreach (var (key, synonyms) in SynonymTable)
        {
            if (key == lower)
            {
                return term + " " + string.Join(' ', synonyms);
            }
        }

        return term + " ";
    }

    private static List<string> SplitOnScriptWhiteSpace(string text)
    {
        var words = new List<string>();
        var start = -1;
        for (var i = 0; i < text.Length; i++)
        {
            if (IsScriptWhiteSpace(text[i]))
            {
                if (start >= 0)
                {
                    words.Add(text[start..i]);
                    start = -1;
                }
            }
            else if (start < 0)
            {
                start = i;
            }
        }

        if (start >= 0)
        {
            words.Add(text[start..]);
        }

        return words;
    }

    // JavaScript's \s: the white space of the language, which is not .NET's (it has U+FEFF and not U+0085).
    private static bool IsScriptWhiteSpace(char c) =>
        c is '\t' or '\n' or '\v' or '\f' or '\r' or ' ' or (char)0x00a0 or (char)0x1680 or (char)0x2028 or (char)0x2029 or (char)0x202f or (char)0x205f or (char)0x3000 or (char)0xfeff
        || c is >= (char)0x2000 and <= (char)0x200a;

    [GeneratedRegex("aa+")]
    private static partial Regex DoubleA();

    [GeneratedRegex("ee+")]
    private static partial Regex DoubleE();

    [GeneratedRegex("ii+")]
    private static partial Regex DoubleI();

    [GeneratedRegex("oo+")]
    private static partial Regex DoubleO();

    [GeneratedRegex("uu+")]
    private static partial Regex DoubleU();

    [GeneratedRegex("ah\\z")]
    private static partial Regex EndAh();

    [GeneratedRegex("eh\\z")]
    private static partial Regex EndEh();

    [GeneratedRegex("[hp]\\z")]
    private static partial Regex EndHOrP();

    [GeneratedRegex("y\\z")]
    private static partial Regex EndY();

    [GeneratedRegex("ey\\z")]
    private static partial Regex EndEy();
}
