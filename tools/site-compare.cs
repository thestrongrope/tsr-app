// Compare the generated static site with the present website, page by page (TC-SITE-R10-01). A file-based app:
// standard library only, no project file and no package.
//
//   dotnet run tools/site-compare.cs -- <generated site folder> <present site base URL> [--max <pages>]
//
// The generated site must have been built from the SAME content as the present site serves (a lane loaded with the
// website's content files; docs/testing.md), or every page differs.
//
// Compared:
//   /articles            the page title, the heading and its line of text; and the list itself against the present
//                        site's /search-index.json, the file its page draws the list from in the browser (the list is
//                        not in the page it serves): which articles, their titles, their order.
//   /articles/{slug}     a sample spread evenly over the generated list: the status (200), the page title, and the main
//                        text, which is everything inside <main> with tags removed, entities decoded and ALL white space
//                        removed (so a line broken differently is not a difference).
//
// Bounds: at most 60 requests in all (--max lowers it), one a second at most, 20 seconds each, a plain User-Agent.
// tools/site-compare.allow lists the known differences, one a line: page | kind | reason; * in the page stands for any
// text. Kinds: status, title, heading, intro, list-missing, list-extra, list-title, list-order, main-text, and
// reference-comma (the main text differs only by a comma after a page or volume reference).
// A difference no line allows is printed and fails the run. Allowed ones are counted and named in the summary.
// Exit code: 0 no unallowed difference, 1 at least one, 2 a wrong call or a side that did not answer.
// Nothing is written anywhere.
using System.Globalization;
using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;

try
{
    return await Compare.RunAsync(args);
}
catch (CompareException e)
{
    Console.Error.WriteLine(e.Message);
    return 2;
}

internal sealed class CompareException(string message) : Exception(message);

internal sealed record Difference(string Page, string Kind, string Present, string Generated);

internal sealed record Allowance(Regex Page, string Kind, string Reason);

internal static partial class Compare
{
    private const int MaxRequests = 60;
    private const int ContextLength = 70;
    private static readonly TimeSpan Pause = TimeSpan.FromSeconds(1);

    [GeneratedRegex(@"<title[^>]*>(?<text>.*?)</title>", RegexOptions.Singleline | RegexOptions.IgnoreCase)]
    private static partial Regex TitleTag();

    [GeneratedRegex(@"<main[^>]*>(?<text>.*)</main>", RegexOptions.Singleline | RegexOptions.IgnoreCase)]
    private static partial Regex MainTag();

    [GeneratedRegex(@"<h1[^>]*>(?<text>.*?)</h1>\s*<p[^>]*>(?<intro>.*?)</p>", RegexOptions.Singleline | RegexOptions.IgnoreCase)]
    private static partial Regex HeadingAndIntro();

    [GeneratedRegex(@"<(script|style)\b.*?</\1>|<!--.*?-->", RegexOptions.Singleline | RegexOptions.IgnoreCase)]
    private static partial Regex NotText();

    [GeneratedRegex(@"<[^>]+>")]
    private static partial Regex Tag();

    [GeneratedRegex(@"\s+")]
    private static partial Regex WhiteSpace();

    [GeneratedRegex(@"<a href=""/articles/(?<slug>[^/""?]+)/""[^>]*>.*?<h2[^>]*>(?<title>.*?)</h2>", RegexOptions.Singleline)]
    private static partial Regex Card();

    public static async Task<int> RunAsync(string[] args)
    {
        if (args.Length < 2 || !Directory.Exists(args[0]) || !Uri.TryCreate(args[1].TrimEnd('/') + "/", UriKind.Absolute, out var baseUrl))
        {
            throw new CompareException("usage: dotnet run tools/site-compare.cs -- <generated site folder> <present site base URL> [--max <pages>]");
        }

        var max = MaxRequests;
        if (args.Length == 4 && args[2] == "--max" && int.TryParse(args[3], CultureInfo.InvariantCulture, out var asked))
        {
            max = Math.Clamp(asked, 3, MaxRequests);
        }

        var site = args[0];
        var allowances = ReadAllowances();
        var differences = new List<Difference>();
        using var http = new HttpClient { BaseAddress = baseUrl, Timeout = TimeSpan.FromSeconds(20) };
        http.DefaultRequestHeaders.UserAgent.ParseAdd("site-compare/1.0");

        var generatedList = ReadGenerated(site, "articles");
        var cards = Card().Matches(generatedList).Select(m => (Slug: m.Groups["slug"].Value, Title: Text(m.Groups["title"].Value))).ToList();
        differences.AddRange(await CompareListAsync(http, generatedList, cards));

        var sample = Sample(cards.Select(c => c.Slug).ToList(), max - 2);
        var compared = 1;
        var equal = differences.Count == 0 ? 1 : 0;
        foreach (var slug in sample)
        {
            await Task.Delay(Pause);
            var found = await CompareArticleAsync(http, site, slug);
            compared++;
            equal += found.Count == 0 ? 1 : 0;
            differences.AddRange(found);
        }

        return Report(differences, allowances, compared, equal);
    }

    private static async Task<List<Difference>> CompareListAsync(HttpClient http, string generated, List<(string Slug, string Title)> cards)
    {
        const string page = "/articles";
        var differences = new List<Difference>();
        var (status, present) = await GetAsync(http, "articles");
        if (status != HttpStatusCode.OK)
        {
            throw new CompareException($"The present site answered {(int)status} for {page}.");
        }

        Add(differences, page, "title", Title(present), Title(generated));
        var presentHead = HeadingAndIntro().Match(present);
        var generatedHead = HeadingAndIntro().Match(generated);
        Add(differences, page, "heading", Text(presentHead.Groups["text"].Value), Text(generatedHead.Groups["text"].Value));
        Add(differences, page, "intro", Text(presentHead.Groups["intro"].Value), Text(generatedHead.Groups["intro"].Value));

        await Task.Delay(Pause);
        var (indexStatus, indexJson) = await GetAsync(http, "search-index.json");
        if (indexStatus != HttpStatusCode.OK)
        {
            throw new CompareException($"The present site answered {(int)indexStatus} for /search-index.json.");
        }

        using var index = JsonDocument.Parse(indexJson);
        var listed = index.RootElement.GetProperty("articles").EnumerateArray()
            .Select(a => (Slug: a.GetProperty("slug").GetString() ?? string.Empty, Title: Text(a.GetProperty("title").GetString() ?? string.Empty)))
            .ToList();
        var presentBySlug = listed.GroupBy(a => a.Slug).ToDictionary(g => g.Key, g => g.First().Title);
        var generatedBySlug = cards.GroupBy(c => c.Slug).ToDictionary(g => g.Key, g => g.First().Title);
        foreach (var (slug, title) in listed.Where(a => !generatedBySlug.ContainsKey(a.Slug)))
        {
            differences.Add(new Difference("/articles/" + slug, "list-missing", title, "(not in the generated list)"));
        }

        foreach (var (slug, title) in cards.Where(c => !presentBySlug.ContainsKey(c.Slug)))
        {
            differences.Add(new Difference("/articles/" + slug, "list-extra", "(not in the present list)", title));
        }

        foreach (var (slug, title) in cards.Where(c => presentBySlug.ContainsKey(c.Slug)))
        {
            Add(differences, "/articles/" + slug, "list-title", presentBySlug[slug], title);
        }

        var presentOrder = listed.Select(a => a.Slug).Where(generatedBySlug.ContainsKey).ToList();
        var generatedOrder = cards.Select(c => c.Slug).Where(presentBySlug.ContainsKey).ToList();
        var firstMoved = Enumerable.Range(0, Math.Min(presentOrder.Count, generatedOrder.Count)).FirstOrDefault(i => presentOrder[i] != generatedOrder[i], -1);
        if (firstMoved >= 0)
        {
            differences.Add(new Difference(page, "list-order", $"position {firstMoved + 1}: {presentOrder[firstMoved]}", $"position {firstMoved + 1}: {generatedOrder[firstMoved]}"));
        }

        Console.WriteLine($"list: {listed.Count} articles on the present site, {cards.Count} generated");
        return differences;
    }

    private static async Task<List<Difference>> CompareArticleAsync(HttpClient http, string site, string slug)
    {
        var page = "/articles/" + slug;
        var differences = new List<Difference>();
        var generated = ReadGenerated(site, Path.Combine("articles", Uri.UnescapeDataString(slug)));
        var (status, present) = await GetAsync(http, "articles/" + slug);
        if (status != HttpStatusCode.OK)
        {
            differences.Add(new Difference(page, "status", ((int)status).ToString(CultureInfo.InvariantCulture), "200 (a page is generated)"));
            return differences;
        }

        Add(differences, page, "title", Title(present), Title(generated));
        var presentText = MainText(present);
        var generatedText = MainText(generated);
        if (presentText != generatedText && ReferenceComma().Replace(presentText, "$1") == ReferenceComma().Replace(generatedText, "$1"))
        {
            // The only difference is a comma after a page or volume reference: its own kind, so the allow list can accept it
            // without accepting any other difference in the main text.
            differences.Add(new Difference(page, "reference-comma", "a comma after a reference that the other side lacks", "the same text without it"));
        }
        else if (presentText != generatedText)
        {
            var at = Enumerable.Range(0, Math.Min(presentText.Length, generatedText.Length)).FirstOrDefault(i => presentText[i] != generatedText[i], Math.Min(presentText.Length, generatedText.Length));
            differences.Add(new Difference(page, "main-text", $"[{presentText.Length} characters] at {at}: {Around(presentText, at)}", $"[{generatedText.Length} characters] at {at}: {Around(generatedText, at)}"));
        }

        return differences;
    }

    /// <summary>At most <paramref name="count"/> slugs, spread evenly over the list, the first and the last included.</summary>
    private static List<string> Sample(List<string> slugs, int count)
    {
        if (slugs.Count <= count || count <= 1)
        {
            return slugs.Take(count).ToList();
        }

        return Enumerable.Range(0, count).Select(i => slugs[(int)((long)i * (slugs.Count - 1) / (count - 1))]).Distinct().ToList();
    }

    private static int Report(List<Difference> differences, List<Allowance> allowances, int compared, int equal)
    {
        var unallowed = 0;
        var allowedByReason = new Dictionary<string, int>();
        foreach (var difference in differences)
        {
            var allowance = allowances.FirstOrDefault(a => a.Kind == difference.Kind && a.Page.IsMatch(difference.Page));
            if (allowance is not null)
            {
                allowedByReason[allowance.Reason] = allowedByReason.GetValueOrDefault(allowance.Reason) + 1;
                continue;
            }

            unallowed++;
            Console.WriteLine($"DIFFERENT {difference.Page} [{difference.Kind}]\n  present:   {difference.Present}\n  generated: {difference.Generated}");
        }

        Console.WriteLine($"compared {compared} pages: {equal} equal, {compared - equal} different");
        foreach (var kind in differences.GroupBy(d => d.Kind).OrderBy(g => g.Key))
        {
            Console.WriteLine($"  {kind.Key}: {kind.Count()}");
        }

        foreach (var (reason, count) in allowedByReason)
        {
            Console.WriteLine($"  allowed {count}: {reason}");
        }

        Console.WriteLine($"differences not allowed: {unallowed}");
        return unallowed == 0 ? 0 : 1;
    }

    private static List<Allowance> ReadAllowances()
    {
        var file = Path.Combine(AppContext.GetData("EntryPointFileDirectoryPath") as string ?? "tools", "site-compare.allow");
        if (!File.Exists(file))
        {
            throw new CompareException("The allow list was not found: " + file);
        }

        var allowances = new List<Allowance>();
        foreach (var line in File.ReadLines(file).Select(l => l.Trim()).Where(l => l.Length > 0 && !l.StartsWith('#')))
        {
            var parts = line.Split('|', 3, StringSplitOptions.TrimEntries);
            if (parts.Length != 3 || parts[2].Length == 0)
            {
                throw new CompareException("A line of the allow list is not 'page | kind | reason': " + line);
            }

            var pattern = "^" + Regex.Escape(parts[0]).Replace(@"\*", ".*", StringComparison.Ordinal) + "$";
            allowances.Add(new Allowance(new Regex(pattern, RegexOptions.None, TimeSpan.FromSeconds(1)), parts[1], parts[2]));
        }

        return allowances;
    }

    private static string ReadGenerated(string site, string folder)
    {
        var file = Path.Combine(site, folder, "index.html");
        return File.Exists(file) ? File.ReadAllText(file) : throw new CompareException("The generated site has no " + file);
    }

    private static async Task<(HttpStatusCode Status, string Body)> GetAsync(HttpClient http, string path)
    {
        try
        {
            using var response = await http.GetAsync(new Uri(path, UriKind.Relative));
            return (response.StatusCode, await response.Content.ReadAsStringAsync());
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException)
        {
            throw new CompareException($"The present site did not answer for /{path}: {e.Message}");
        }
    }

    private static void Add(List<Difference> differences, string page, string kind, string present, string generated)
    {
        if (present != generated)
        {
            differences.Add(new Difference(page, kind, present, generated));
        }
    }

    private static string Title(string html) => Text(TitleTag().Match(html).Groups["text"].Value);

    /// <summary>The text a reader sees, on one line: tags removed, entities decoded, runs of white space made one space.</summary>
    private static string Text(string html) =>
        WhiteSpace().Replace(WebUtility.HtmlDecode(Tag().Replace(NotText().Replace(html, string.Empty), string.Empty)), " ").Trim();

    /// <summary>A page or volume reference followed by a comma, in text with its white space removed ("p.201,").</summary>
    [GeneratedRegex(@"((?:vol|p)\.\d+),")]
    private static partial Regex ReferenceComma();

    private static string MainText(string html) =>
        WhiteSpace().Replace(Text(MainTag().Match(html).Groups["text"].Value), string.Empty);

    private static string Around(string text, int at)
    {
        var start = Math.Max(0, at - ContextLength / 2);
        return string.Concat("...", text.AsSpan(start, Math.Min(ContextLength, text.Length - start)), "...");
    }
}
