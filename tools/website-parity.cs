// Compare the Library reads of today's website (tsr-web) with the new API, answer by answer. A file-based app:
// standard library only, no project file and no package.
//
//   dotnet run tools/website-parity.cs -- <tsr-web base URL> <new API base URL>            every line of website-parity.cases
//   dotnet run tools/website-parity.cs -- <tsr-web base URL> <new API base URL> --sweep    every published article, one by one
//   dotnet run tools/website-parity.cs -- <tsr-web base URL> <new API base URL> --timing <path> [<path> ...]
//                                                                                          100 reads of each path from the NEW side only
//
// Compared for each case: the status code, the Cache-Control header and the JSON body, value by value.
// Never compared: meta.timestamp, meta.cache.expires and the ETag header (they change on every answer).
// A case line may end in "| expect <tsr-web status> <new status>": it passes on exactly those two statuses and nothing
// else of it is compared (the sides are known to answer differently). A 5xx from either side fails any case.
// A case holding {TSR_PARITY_DRAFT_SLUG} takes a draft's slug from that environment variable (a draft's slug is never
// written in this public repository); unset, the case is skipped and the summary says so.
// In the sweep an article whose slug is percent-encoded is expected to answer 404 on tsr-web and 200 on the new side.
// data.content (an article's HTML) is compared three times: as HTML after collapsing white space (path data.content), as
// the text a reader sees, tags removed and entities decoded (path data.content(text)), and as its link targets, the href
// and src values in order (path data.content(links)).
// A list whose items all carry a slug of their own is compared item by item matched by slug (path data{slug}.field), and
// its order separately (path data(order)); any other list is compared by position (path data[3].field).
// website-parity.allow lists the known differences, one a line: case | JSON path | reason; * in the first two stands for
// any text, but a path of * alone is refused and a status difference can never be allowed.
// A difference no line allows is printed (case, JSON path, tsr-web value, new value) and fails the run.
// Exit code: 0 no unallowed difference, 1 at least one, 2 a wrong call or a side that did not answer.
// Requests are sequential. Nothing is written anywhere.
using System.Diagnostics;
using System.Globalization;
using System.Net;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.RegularExpressions;

try
{
    return await Parity.RunAsync(args);
}
catch (ParityException e)
{
    Console.Error.WriteLine(e.Message);
    return 2;
}

internal sealed class ParityException(string message) : Exception(message);

internal sealed record Answer(int Status, string CacheControl, JsonElement? Body, string Raw);

internal sealed record Difference(string Case, string Path, string Web, string New);

// Name is what is printed (the line as written); Path is what is fetched. The two statuses are set together or not at all.
internal sealed record Case(string Name, string Path, int? WebStatus = null, int? NewStatus = null);

internal sealed class Tally
{
    public int Equal { get; private set; }
    public int AllowedOnly { get; private set; }
    public int AsExpected { get; private set; }
    public int Failed { get; private set; }

    public void Add(Case @case, int differences, int unallowed)
    {
        if (unallowed > 0) { Failed++; }
        else if (@case.WebStatus is not null) { AsExpected++; }
        else if (differences > 0) { AllowedOnly++; }
        else { Equal++; }
    }

    public override string ToString() =>
        $"equal {Equal}, equal but for allowed differences {AllowedOnly}, the expected statuses {AsExpected}, FAILED {Failed}";
}

internal sealed class AllowLine(Regex @case, Regex path, string text)
{
    public string Text { get; } = text;
    public int Hits { get; set; }
    public bool Matches(Difference d) => @case.IsMatch(d.Case) && path.IsMatch(d.Path);
}

internal static partial class Parity
{
    private const int TimingRequests = 100;
    private const int SweepPageSize = 100;
    private const int SweepMaxPages = 200;
    private const int ShownLength = 90;
    private const int SamplesPerPath = 3;
    private const string Absent = "<absent>";
    private const string DraftSlugVariable = "TSR_PARITY_DRAFT_SLUG";
    private const string ArticlePath = "/api/v1/articles/";
    private static readonly string[] Ignored = ["meta.timestamp", "meta.cache.expires"];

    public static async Task<int> RunAsync(string[] args)
    {
        if (args.Length < 2)
        {
            throw new ParityException("usage: dotnet run tools/website-parity.cs -- <tsr-web base URL> <new API base URL> [--sweep | --timing <path> ...]");
        }
        using var http = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false })
        {
            Timeout = TimeSpan.FromSeconds(120),
            MaxResponseContentBufferSize = 20 * 1024 * 1024,
        };
        http.DefaultRequestHeaders.Add("Accept", "application/json");
        var sides = new Sides(http, args[0].TrimEnd('/'), args[1].TrimEnd('/'));
        var mode = args.Length > 2 ? args[2] : "";
        return mode switch
        {
            "" => await CasesAsync(sides),
            "--sweep" => await SweepAsync(sides),
            "--timing" when args.Length > 3 => await TimingAsync(sides, args[3..]),
            _ => throw new ParityException($"unknown or incomplete option '{mode}'"),
        };
    }

    // ---- the three runs ----

    private static async Task<int> CasesAsync(Sides sides)
    {
        var allow = ReadAllow();
        var draftSlug = DraftSlug();
        var lines = ReadLines("website-parity.cases");
        var cases = lines.Where(l => draftSlug is not null || !l.Contains(DraftPlaceholder, StringComparison.Ordinal)).Select(l => ParseCase(l, draftSlug)).ToList();
        var tally = new Tally();
        foreach (var @case in cases)
        {
            var differences = await CompareAsync(sides, @case);
            var unallowed = Unallowed(differences, allow);
            tally.Add(@case, differences.Count, unallowed.Count);
            foreach (var d in unallowed) { Print(d); }
        }
        PrintAllow(allow);
        var skipped = lines.Count - cases.Count;
        Console.WriteLine($"cases run {cases.Count}: {tally}" + (skipped > 0 ? $"; draft case skipped ({DraftSlugVariable} is not set)" : ""));
        return tally.Failed == 0 ? 0 : 1;
    }

    private static async Task<int> SweepAsync(Sides sides)
    {
        var allow = ReadAllow();
        var slugs = await SlugsAsync(sides.Http, sides.Web);
        var newSlugs = await SlugsAsync(sides.Http, sides.New);
        Console.WriteLine($"published articles: tsr-web {slugs.Count}, new {newSlugs.Count}; only on tsr-web {slugs.Except(newSlugs).Count()}, only on new {newSlugs.Except(slugs).Count()}");
        var tally = new Tally();
        var byPath = new SortedDictionary<string, List<Difference>>(StringComparer.Ordinal);
        foreach (var slug in slugs)
        {
            // tsr-web looks the decoded route value up among slugs kept encoded, so it never finds such an article; the new side does (agreed, 13 Nov 2026).
            var encoded = slug.Contains('%', StringComparison.Ordinal);
            var @case = new Case(ArticlePath + slug, ArticlePath + slug, encoded ? 404 : null, encoded ? 200 : null);
            var differences = await CompareAsync(sides, @case);
            var unallowed = Unallowed(differences, allow);
            tally.Add(@case, differences.Count, unallowed.Count);
            Collect(byPath, unallowed);
        }
        PrintByPath(byPath);
        PrintAllow(allow);
        Console.WriteLine($"articles compared {slugs.Count}: {tally}");
        return tally.Failed == 0 && slugs.SetEquals(newSlugs) ? 0 : 1;
    }

    private static async Task<int> TimingAsync(Sides sides, string[] paths)
    {
        foreach (var path in paths)
        {
            var ms = new List<double>(TimingRequests);
            for (var i = 0; i < TimingRequests; i++)
            {
                var watch = Stopwatch.StartNew();
                var answer = await FetchAsync(sides.Http, sides.New, path);
                watch.Stop();
                if (answer.Status != 200) { throw new ParityException($"{sides.New}{path} answered {answer.Status}"); }
                ms.Add(watch.Elapsed.TotalMilliseconds);
            }
            ms.Sort();
            Console.WriteLine(string.Create(CultureInfo.InvariantCulture,
                $"{path}: {TimingRequests} reads, 95th fastest {ms[94]:F1} ms (fastest {ms[0]:F1}, 50th {ms[49]:F1}, slowest {ms[^1]:F1})"));
        }
        return 0;
    }

    // ---- fetching ----

    private static async Task<Answer> FetchAsync(HttpClient http, string baseUrl, string path)
    {
        try
        {
            using var response = await http.GetAsync(new Uri(baseUrl + path));
            var raw = await response.Content.ReadAsStringAsync();
            var cache = response.Headers.CacheControl?.ToString() ?? "";
            return new Answer((int)response.StatusCode, cache, ParseJson(raw), raw);
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException or UriFormatException)
        {
            throw new ParityException($"{baseUrl}{path} did not answer: {e.GetType().Name}: {e.Message}");
        }
    }

    private static JsonElement? ParseJson(string raw)
    {
        try
        {
            using var document = JsonDocument.Parse(raw);
            return document.RootElement.Clone();
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static async Task<SortedSet<string>> SlugsAsync(HttpClient http, string baseUrl)
    {
        var slugs = new SortedSet<string>(StringComparer.Ordinal);
        for (var page = 0; page < SweepMaxPages; page++)
        {
            var path = string.Create(CultureInfo.InvariantCulture, $"/api/v1/articles?limit={SweepPageSize}&offset={page * SweepPageSize}");
            var answer = await FetchAsync(http, baseUrl, path);
            if (answer.Status != 200 || answer.Body is not { } body) { throw new ParityException($"{baseUrl}{path} answered {answer.Status}"); }
            foreach (var item in body.GetProperty("data").EnumerateArray())
            {
                slugs.Add(item.GetProperty("slug").GetString() ?? "");
            }
            if (!body.GetProperty("pagination").GetProperty("hasMore").GetBoolean()) { return slugs; }
        }
        throw new ParityException($"{baseUrl} lists more than {SweepMaxPages * SweepPageSize} articles");
    }

    // ---- comparing ----

    private static async Task<List<Difference>> CompareAsync(Sides sides, Case @case)
    {
        var web = await FetchAsync(sides.Http, sides.Web, @case.Path);
        var mine = await FetchAsync(sides.Http, sides.New, @case.Path);
        var found = new List<Difference>();
        var at = new Spot(@case.Name, found);
        if (web.Status >= 500 || mine.Status >= 500) { at.Add("$status(5xx)", Invariant(web.Status), Invariant(mine.Status)); }
        if (@case.WebStatus is { } expectedWeb && @case.NewStatus is { } expectedNew)
        {
            if (web.Status != expectedWeb || mine.Status != expectedNew)
            {
                at.Add("$status", $"{web.Status} (expected {expectedWeb})", $"{mine.Status} (expected {expectedNew})");
            }
            return found;
        }
        if (web.Status != mine.Status) { at.Add("$status", Invariant(web.Status), Invariant(mine.Status)); }
        if (web.CacheControl != mine.CacheControl) { at.Add("$header.Cache-Control", web.CacheControl, mine.CacheControl); }
        if (web.Body is { } a && mine.Body is { } b) { Walk(at, "", a, b); }
        else if (web.Body is not null || mine.Body is not null || web.Raw != mine.Raw) { at.Add("$body", web.Raw, mine.Raw); }
        return found;
    }

    private static void Walk(Spot at, string path, JsonElement a, JsonElement b)
    {
        if (Ignored.Contains(path)) { return; }
        if (a.ValueKind != b.ValueKind) { at.Add(path, a.GetRawText(), b.GetRawText()); return; }
        switch (a.ValueKind)
        {
            case JsonValueKind.Object: WalkObject(at, path, a, b); break;
            case JsonValueKind.Array: WalkArray(at, path, a, b); break;
            case JsonValueKind.String: WalkString(at, path, a.GetString() ?? "", b.GetString() ?? ""); break;
            case JsonValueKind.Number when !SameNumber(a, b): at.Add(path, a.GetRawText(), b.GetRawText()); break;
            default: break;
        }
    }

    private static void WalkObject(Spot at, string path, JsonElement a, JsonElement b)
    {
        var names = a.EnumerateObject().Select(p => p.Name).Union(b.EnumerateObject().Select(p => p.Name));
        foreach (var name in names)
        {
            var child = path.Length == 0 ? name : path + "." + name;
            var inA = a.TryGetProperty(name, out var x);
            var inB = b.TryGetProperty(name, out var y);
            if (inA && inB) { Walk(at, child, x, y); }
            else if (!Ignored.Contains(child)) { at.Add(child, inA ? x.GetRawText() : Absent, inB ? y.GetRawText() : Absent); }
        }
    }

    private static void WalkArray(Spot at, string path, JsonElement a, JsonElement b)
    {
        if (SlugsOf(a) is { } slugsA && SlugsOf(b) is { } slugsB)
        {
            WalkBySlug(at, path, (a, slugsA), (b, slugsB));
            return;
        }
        int countA = a.GetArrayLength(), countB = b.GetArrayLength();
        if (countA != countB) { at.Add(path + ".length", Invariant(countA), Invariant(countB)); }
        for (var i = 0; i < Math.Min(countA, countB); i++)
        {
            Walk(at, string.Create(CultureInfo.InvariantCulture, $"{path}[{i}]"), a[i], b[i]);
        }
    }

    // The items' slugs in order, or null unless every item is an object with a text slug that no other item has.
    private static List<string>? SlugsOf(JsonElement array)
    {
        var slugs = new List<string>(array.GetArrayLength());
        foreach (var item in array.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object || !item.TryGetProperty("slug", out var slug) || slug.ValueKind != JsonValueKind.String) { return null; }
            slugs.Add(slug.GetString() ?? "");
        }
        return slugs.Distinct(StringComparer.Ordinal).Count() == slugs.Count ? slugs : null;
    }

    private static void WalkBySlug(Spot at, string path, (JsonElement Items, List<string> Slugs) a, (JsonElement Items, List<string> Slugs) b)
    {
        if (!a.Slugs.SequenceEqual(b.Slugs)) { at.Add(path + "(order)", string.Join(' ', a.Slugs), string.Join(' ', b.Slugs)); }
        for (var i = 0; i < a.Slugs.Count; i++)
        {
            var child = $"{path}{{{a.Slugs[i]}}}";
            var j = b.Slugs.IndexOf(a.Slugs[i]);
            if (j < 0) { at.Add(child, a.Items[i].GetRawText(), Absent); }
            else { Walk(at, child, a.Items[i], b.Items[j]); }
        }
        for (var j = 0; j < b.Slugs.Count; j++)
        {
            if (!a.Slugs.Contains(b.Slugs[j])) { at.Add($"{path}{{{b.Slugs[j]}}}", Absent, b.Items[j].GetRawText()); }
        }
    }

    private static void WalkString(Spot at, string path, string a, string b)
    {
        if (path != "data.content")
        {
            if (a != b) { at.Add(path, a, b); }
            return;
        }
        string htmlA = Collapse(a), htmlB = Collapse(b);
        if (htmlA != htmlB) { at.Add(path, htmlA, htmlB); }
        string textA = VisibleText(a), textB = VisibleText(b);
        if (textA != textB) { at.Add(path + "(text)", textA, textB); }
        string linksA = Links(a), linksB = Links(b);
        if (linksA != linksB) { at.Add(path + "(links)", linksA, linksB); }
    }

    private static bool SameNumber(JsonElement a, JsonElement b) =>
        a.GetRawText() == b.GetRawText() || (a.TryGetDecimal(out var x) && b.TryGetDecimal(out var y) && x == y);

    private static string Collapse(string text) => WhiteSpace().Replace(text, " ").Trim();

    private static string VisibleText(string html) => Collapse(WebUtility.HtmlDecode(Tag().Replace(html, " ")));

    // Every href and src value in order, entities decoded, one a line.
    private static string Links(string html) =>
        string.Join('\n', LinkTarget().Matches(html).Select(m => WebUtility.HtmlDecode(m.Groups[1].Success ? m.Groups[1].Value : m.Groups[2].Value)));

    private static string Invariant(int value) => value.ToString(CultureInfo.InvariantCulture);

    [GeneratedRegex(@"\s+")]
    private static partial Regex WhiteSpace();

    [GeneratedRegex("<[^>]*>")]
    private static partial Regex Tag();

    [GeneratedRegex("""(?<=\s)(?:href|src)\s*=\s*(?:"([^"]*)"|'([^']*)')""", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex LinkTarget();

    [GeneratedRegex(@"\[\d+\]|\{[^}]*\}")]
    private static partial Regex Index();

    [GeneratedRegex(@"^expect ([1-5]\d\d) ([1-5]\d\d)$")]
    private static partial Regex Expectation();

    [GeneratedRegex("^[A-Za-z0-9%._~-]{1,255}$")]
    private static partial Regex SlugText();

    // ---- the cases and the allow file ----

    private static List<string> ReadLines(string name, [CallerFilePath] string source = "")
    {
        var file = Path.Combine(Path.GetDirectoryName(source) ?? ".", name);
        if (!File.Exists(file)) { throw new ParityException($"{file} is missing"); }
        return [.. File.ReadLines(file).Select(l => l.Trim()).Where(l => l.Length > 0 && !l.StartsWith('#'))];
    }

    private const string DraftPlaceholder = "{" + DraftSlugVariable + "}";

    private static string? DraftSlug()
    {
        var slug = Environment.GetEnvironmentVariable(DraftSlugVariable);
        if (string.IsNullOrEmpty(slug)) { return null; }
        return SlugText().IsMatch(slug) ? slug : throw new ParityException($"{DraftSlugVariable} is not a slug");
    }

    private static Case ParseCase(string line, string? draftSlug)
    {
        var parts = line.Split('|', 2, StringSplitOptions.TrimEntries);
        var path = parts[0].Replace(DraftPlaceholder, draftSlug ?? "", StringComparison.Ordinal);
        if (parts.Length == 1) { return new Case(parts[0], path); }
        var expect = Expectation().Match(parts[1]);
        if (!expect.Success) { throw new ParityException($"website-parity.cases: after | a line must say 'expect <tsr-web status> <new status>': {line}"); }
        return new Case(parts[0], path, int.Parse(expect.Groups[1].Value, CultureInfo.InvariantCulture), int.Parse(expect.Groups[2].Value, CultureInfo.InvariantCulture));
    }

    private static List<AllowLine> ReadAllow()
    {
        var lines = new List<AllowLine>();
        foreach (var line in ReadLines("website-parity.allow"))
        {
            var parts = line.Split('|', 3, StringSplitOptions.TrimEntries);
            if (parts.Length != 3 || parts.Any(p => p.Length == 0) || parts[1].Trim('*').Length == 0)
            {
                throw new ParityException($"website-parity.allow: a line must be 'case | JSON path | reason', the path more than a *: {line}");
            }
            lines.Add(new AllowLine(Glob(parts[0]), Glob(parts[1]), line));
        }
        return lines;
    }

    private static Regex Glob(string pattern) =>
        new("^" + Regex.Escape(pattern).Replace("\\*", ".*", StringComparison.Ordinal) + "$", RegexOptions.CultureInvariant | RegexOptions.Singleline);

    private static List<Difference> Unallowed(List<Difference> differences, List<AllowLine> allow)
    {
        var unallowed = new List<Difference>();
        foreach (var d in differences)
        {
            var line = d.Path.StartsWith("$status", StringComparison.Ordinal) ? null : allow.FirstOrDefault(l => l.Matches(d));
            if (line is null) { unallowed.Add(d); }
            else { line.Hits++; }
        }
        return unallowed;
    }

    // ---- printing ----

    private static void Print(Difference d)
    {
        var (web, mine) = Shown(d.Web, d.New);
        Console.WriteLine($"DIFFERENT  {d.Case}\n  path     {d.Path}\n  tsr-web  {web}\n  new      {mine}");
    }

    private static void Collect(SortedDictionary<string, List<Difference>> byPath, List<Difference> unallowed)
    {
        foreach (var d in unallowed)
        {
            var key = Index().Replace(d.Path, "[*]");
            if (!byPath.TryGetValue(key, out var list)) { byPath[key] = list = []; }
            list.Add(d);
        }
    }

    private static void PrintByPath(SortedDictionary<string, List<Difference>> byPath)
    {
        foreach (var (path, list) in byPath)
        {
            var slugs = list.Select(d => d.Case[ArticlePath.Length..]).Distinct(StringComparer.Ordinal).ToList();
            Console.WriteLine($"\n{path}: {list.Count} differences in {slugs.Count} articles");
            foreach (var d in list.Take(SamplesPerPath)) { Print(d); }
            Console.WriteLine("  articles: " + string.Join(' ', slugs));
        }
    }

    private static void PrintAllow(List<AllowLine> allow)
    {
        Console.WriteLine("\nallowed differences (times met):");
        foreach (var line in allow.Where(l => l.Hits > 0)) { Console.WriteLine($"  {line.Hits,5}  {line.Text}"); }
        Console.WriteLine("\nallowed but not met in this run:");
        foreach (var line in allow.Where(l => l.Hits == 0)) { Console.WriteLine($"         {line.Text}"); }
    }

    // Both values cut to the same window, which starts a little before the first character that differs.
    private static (string Web, string New) Shown(string a, string b)
    {
        var shared = 0;
        var end = Math.Min(a.Length, b.Length);
        while (shared < end && a[shared] == b[shared]) { shared++; }
        var from = a.Length <= ShownLength && b.Length <= ShownLength ? 0 : Math.Max(0, shared - 25);
        return (Cut(a, from), Cut(b, from));
    }

    private static string Cut(string text, int from)
    {
        if (from >= text.Length) { return from == 0 ? "" : "...<ends here>"; }
        var part = text.Substring(from, Math.Min(ShownLength, text.Length - from)).ReplaceLineEndings("\\n");
        return (from > 0 ? "..." : "") + part + (from + ShownLength < text.Length ? "..." : "");
    }

    private sealed record Sides(HttpClient Http, string Web, string New);

    private sealed record Spot(string Case, List<Difference> Found)
    {
        public void Add(string path, string web, string mine) => Found.Add(new Difference(Case, path, web, mine));
    }
}
