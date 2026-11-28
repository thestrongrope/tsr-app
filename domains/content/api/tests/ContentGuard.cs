using System.Text.Json;
using System.Text.RegularExpressions;
using Tsr.Content.Api.Domain;

namespace Tsr.Content.Api.Tests;

/// <summary>
/// The checks over a published content folder (LIB-R27, LIB-R28, LIB-R31, LIB-R37): one line per problem, none when the folder is good.
/// It uses the content reader itself, so a file the reader would not publish is a problem here. It takes the directory, so a test can run it on a folder it wrote.
/// </summary>
internal static partial class ContentGuard
{
    private const string PublicationsPage = "tsr-publications.md";
    private const string LecturesFile = "lectures.ndjson";

    private static readonly HashSet<string> LectureKeys = new(["slug", "title", "url", "excerpt", "content", "search_phrases", "key_points", "tags", "language", "publishedDate", "durationSec", "chapters", "embedding"], StringComparer.Ordinal);

    private static readonly HashSet<string> ChapterKeys = new(["start_sec", "title", "summary", "url"], StringComparer.Ordinal);

    /// <summary>The text keys of a lecture: the keys whose words a phone number could be spoken in (LEC-R10). Not slug, url, chapters[].url, publishedDate, durationSec, language or embedding.</summary>
    private static readonly string[] ChapterTextKeys = ["title", "summary"];

    private static readonly string[] TextKeys = ["title", "excerpt", "content", "search_phrases", "key_points", "tags"];

    /// <summary>A phone-like run (LEC-R10, the same pattern as tools/content-import.sh): an optional +, then 10 to 13 digits in all, single spaces, dots, hyphens or parentheses allowed between digits, no digit before or after. It cannot cross a letter.</summary>
    [GeneratedRegex(@"(?<![0-9])\+?[0-9]([ .()-]?[0-9]){9,12}(?![0-9])")]
    private static partial Regex PhoneLikeRun();

    /// <summary>Rule 2 of LEC-R10 (the same pattern as tools/content-import.sh): after whatsapp, phone, mobile or contact and then number or no (any case), or after a [number removed], a run of 4 or more digits in all (an optional +, single spaces, dots, hyphens or parentheses between digits) that begins within the next 80 characters. 1 to 3 digits stay.</summary>
    [GeneratedRegex(@"(\b(whatsapp|phone|mobile|contact)\s+(number|no)\b|\[number removed\])(.|\n){0,80}?(?<![0-9])\+?[0-9]([ .()-]?[0-9]){3,}(?![0-9])", RegexOptions.IgnoreCase)]
    private static partial Regex NumberWordThenDigits();

    public static IReadOnlyList<string> Problems(string contentDirectory)
    {
        if (!Directory.Exists(contentDirectory))
        {
            return [$"no such folder: {contentDirectory}"];
        }

        var problems = new List<string>();
        problems.AddRange(UnexpectedEntries(contentDirectory));
        var articles = Files(contentDirectory, "articles");
        var categories = Files(contentDirectory, "categories");
        if (articles.Count == 0 || categories.Count == 0)
        {
            problems.Add("the folder needs at least one article and one category");
        }

        problems.AddRange(articles.SelectMany(article => NotOnePublishedArticle(contentDirectory, article)));
        problems.AddRange(SetProblems(contentDirectory, articles.Count, categories.Count));
        problems.AddRange(LectureProblems(contentDirectory));
        return problems;
    }

    /// <summary>Rule 1: only README.md, articles/*.md, categories/*.md and pages/tsr-publications.md. A link, a subfolder or any other file is named.</summary>
    private static IEnumerable<string> UnexpectedEntries(string root)
    {
        foreach (var entry in new DirectoryInfo(root).EnumerateFileSystemInfos())
        {
            var allowedFolder = entry is DirectoryInfo && entry.Name is "articles" or "categories" or "pages" or "downloads" or "lectures";
            if (entry.LinkTarget is not null || !(allowedFolder || (entry is FileInfo && entry.Name == "README.md")))
            {
                yield return Unexpected(entry.Name);
                continue;
            }

            if (entry is DirectoryInfo folder)
            {
                foreach (var inner in InsideFolder(folder))
                {
                    yield return inner;
                }
            }
        }
    }

    private static IEnumerable<string> InsideFolder(DirectoryInfo folder) => folder.Name switch
    {
        "downloads" => InDownloads(folder, "downloads"),
        "lectures" => InLectures(folder),
        _ => InFolder(folder),
    };

    /// <summary>Rule 10: lectures/ holds the one regular file lectures.ndjson.</summary>
    private static IEnumerable<string> InLectures(DirectoryInfo folder)
    {
        foreach (var entry in folder.EnumerateFileSystemInfos())
        {
            if (entry is not FileInfo || entry.LinkTarget is not null || entry.Name != LecturesFile)
            {
                yield return Unexpected($"lectures/{entry.Name}");
            }
        }
    }

    /// <summary>Rule 11 (LEC-R9, LEC-R10): the file exists, every line is a JSON object of the thirteen keys, every chapter holds start_sec, title, summary and url only, and no text key holds a phone-like run.</summary>
    private static List<string> LectureProblems(string root)
    {
        var path = Path.Combine(root, "lectures", LecturesFile);
        if (!File.Exists(path))
        {
            return ["the folder needs lectures/lectures.ndjson"];
        }

        var problems = new List<string>();
        var number = 0;
        foreach (var line in File.ReadLines(path))
        {
            number++;
            if (line.Length == 0)
            {
                continue;
            }

            problems.AddRange(LectureLineProblems(number, line));
        }

        return problems;
    }

    private static List<string> LectureLineProblems(int number, string line)
    {
        JsonDocument document;
        try
        {
            document = JsonDocument.Parse(line);
        }
        catch (JsonException)
        {
            return [$"lectures/lectures.ndjson line {number}: not a JSON object"];
        }

        using (document)
        {
            if (document.RootElement.ValueKind != JsonValueKind.Object)
            {
                return [$"lectures/lectures.ndjson line {number}: not a JSON object"];
            }

            var lecture = document.RootElement;
            var slug = lecture.TryGetProperty("slug", out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : "?";
            var where = $"lectures/lectures.ndjson line {number}, lecture {slug}";
            var problems = new List<string>();
            problems.AddRange(lecture.EnumerateObject().Select(property => property.Name).Where(name => !LectureKeys.Contains(name))
                .Select(name => $"{where}: key {name} is not one of the thirteen"));
            problems.AddRange(TextKeys.Where(key => lecture.TryGetProperty(key, out var text) && HoldsPhoneLikeRun(text))
                .Select(key => $"{where}: key {key} holds a phone-like run"));
            if (lecture.TryGetProperty("chapters", out var chapters) && chapters.ValueKind == JsonValueKind.Array)
            {
                var chapterObjects = chapters.EnumerateArray().Where(chapter => chapter.ValueKind == JsonValueKind.Object).ToList();
                problems.AddRange(chapterObjects.SelectMany(chapter => chapter.EnumerateObject().Select(property => property.Name))
                    .Where(name => !ChapterKeys.Contains(name))
                    .Select(name => $"{where}: chapter key {name} is not start_sec, title, summary or url"));
                problems.AddRange(chapterObjects.SelectMany(chapter => ChapterTextKeys.Where(key => chapter.TryGetProperty(key, out var text) && HoldsPhoneLikeRun(text)))
                    .Distinct().Select(key => $"{where}: key chapters.{key} holds a phone-like run"));
            }

            return problems;
        }
    }

    private static bool HoldsPhoneLikeRun(JsonElement element) => element.ValueKind switch
    {
        JsonValueKind.String => PhoneLikeRun().IsMatch(element.GetString()!) || NumberWordThenDigits().IsMatch(element.GetString()!),
        JsonValueKind.Array => element.EnumerateArray().Any(HoldsPhoneLikeRun),
        _ => false,
    };

    private static IEnumerable<string> InFolder(DirectoryInfo folder)
    {
        foreach (var entry in folder.EnumerateFileSystemInfos())
        {
            var isFile = entry is FileInfo && entry.LinkTarget is null;
            var named = entry.Name.EndsWith(".md", StringComparison.Ordinal);
            if (!isFile || !named)
            {
                yield return Unexpected($"{folder.Name}/{entry.Name}");
            }
        }
    }

    /// <summary>Rule 6: below downloads/ only folders and regular .pdf files, at any depth.</summary>
    private static IEnumerable<string> InDownloads(DirectoryInfo folder, string path)
    {
        foreach (var entry in folder.EnumerateFileSystemInfos())
        {
            var entryPath = $"{path}/{entry.Name}";
            if (entry.LinkTarget is not null)
            {
                yield return Unexpected(entryPath);
            }
            else if (entry is DirectoryInfo inner)
            {
                foreach (var problem in InDownloads(inner, entryPath))
                {
                    yield return problem;
                }
            }
            else if (!entry.Name.EndsWith(".pdf", StringComparison.Ordinal))
            {
                yield return Unexpected(entryPath);
            }
        }
    }

    /// <summary>The regular .pdf files below downloads/, as paths from the content folder with "/" (names as the directory listing returns them).</summary>
    private static List<string> DownloadFiles(string root)
    {
        var path = Path.Combine(root, "downloads");
        if (!Directory.Exists(path))
        {
            return [];
        }

        return
        [
            .. new DirectoryInfo(path).EnumerateFileSystemInfos("*", SearchOption.AllDirectories)
                .Where(entry => entry is FileInfo && entry.LinkTarget is null && entry.Name.EndsWith(".pdf", StringComparison.Ordinal))
                .Select(entry => Path.GetRelativePath(root, entry.FullName).Replace(Path.DirectorySeparatorChar, '/')),
        ];
    }

    /// <summary>Rules 7 to 9: every file link of the publications page is under /downloads/ and names a file the folder holds (exact case), and every PDF is linked.</summary>
    private static List<string> LinkProblems(string root, ContentSet set)
    {
        const string Prefix = "/downloads/";
        var held = DownloadFiles(root).ToHashSet(StringComparer.Ordinal);
        var linked = new HashSet<string>(StringComparer.Ordinal);
        var problems = new List<string>();
        foreach (var link in set.Publications.Select(publication => publication.File).OfType<string>())
        {
            if (!link.StartsWith(Prefix, StringComparison.Ordinal))
            {
                problems.Add($"the publications page links a file outside /downloads/: {link}");
                continue;
            }

            linked.Add(link[1..]);
            if (!held.Contains(link[1..]))
            {
                problems.Add($"the publications page links a file the folder does not hold: {link}");
            }
        }

        foreach (var (page, link) in PageLinks(root))
        {
            linked.Add(link[1..]);
            if (!held.Contains(link[1..]))
            {
                problems.Add($"pages/{page} links a file the folder does not hold: {link}");
            }
        }

        problems.AddRange(held.Where(path => !linked.Contains(path)).Order(StringComparer.Ordinal).Select(path => $"no publication links this file: {path}"));
        return problems;
    }

    /// <summary>Every "/downloads/...pdf" address written in a page other than the publications page (that one is read through its entries), with the page name.</summary>
    private static IEnumerable<(string Page, string Link)> PageLinks(string root)
    {
        var folder = Path.Combine(root, "pages");
        if (!Directory.Exists(folder))
        {
            yield break;
        }

        foreach (var page in Files(root, "pages").Where(name => name != PublicationsPage))
        {
            foreach (Match match in DownloadLink().Matches(File.ReadAllText(Path.Combine(folder, page))))
            {
                yield return (page, match.Value);
            }
        }
    }

    [GeneratedRegex(@"/downloads/[^\s)\x22'<>?#]*\.pdf")]
    private static partial Regex DownloadLink();

    private static string Unexpected(string path) => $"unexpected entry: {path}";

    /// <summary>The names of the regular .md files of one folder.</summary>
    private static List<string> Files(string root, string folder)
    {
        var path = Path.Combine(root, folder);
        if (!Directory.Exists(path))
        {
            return [];
        }

        return
        [
            .. new DirectoryInfo(path).EnumerateFileSystemInfos()
                .Where(entry => entry is FileInfo && entry.LinkTarget is null && entry.Name.EndsWith(".md", StringComparison.Ordinal))
                .Select(entry => entry.Name)
                .Order(StringComparer.Ordinal),
        ];
    }

    /// <summary>Rule 3: the file, written alone into a directory, is read as exactly one published article.</summary>
    private static List<string> NotOnePublishedArticle(string root, string name)
    {
        var alone = Directory.CreateTempSubdirectory("tsr-guard-one-");
        try
        {
            Directory.CreateDirectory(Path.Combine(alone.FullName, "articles"));
            File.Copy(Path.Combine(root, "articles", name), Path.Combine(alone.FullName, "articles", name));
            var read = ContentFiles.Read(alone.FullName, TimeProvider.System, CancellationToken.None);
            if (!read.IsSuccess)
            {
                return [$"articles/{name}: cannot be read ({read.Error})"];
            }

            return read.Value!.Articles.Count == 1 ? [] : [$"articles/{name}: not a published article (its status is not publish or published)"];
        }
        finally
        {
            alone.Delete(recursive: true);
        }
    }

    /// <summary>Rules 4 and 5: the folder reads whole, with every file counted and a publication, and every category of an article has a file.</summary>
    private static List<string> SetProblems(string root, int articleFiles, int categoryFiles)
    {
        var read = ContentFiles.Read(root, TimeProvider.System, CancellationToken.None);
        if (!read.IsSuccess)
        {
            return [$"the set cannot be read ({read.Error})"];
        }

        var set = read.Value!;
        var problems = new List<string>();
        if (set.Articles.Count != articleFiles)
        {
            problems.Add($"the reader finds {set.Articles.Count} published articles in {articleFiles} article files");
        }

        if (set.Categories.Count != categoryFiles)
        {
            problems.Add($"the reader finds {set.Categories.Count} categories in {categoryFiles} category files");
        }

        if (set.Publications.Count == 0)
        {
            problems.Add("the publications list is empty");
        }

        var slugs = set.Categories.Select(category => category.Slug).ToHashSet(StringComparer.Ordinal);
        problems.AddRange(set.Articles.SelectMany(article => article.Categories.Where(name => !slugs.Contains(name)).Select(name => $"{article.Slug} -> {name}")));
        problems.AddRange(LinkProblems(root, set));
        return problems;
    }
}
