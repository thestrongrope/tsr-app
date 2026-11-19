using Tsr.Content.Api.Domain;

namespace Tsr.Content.Api.Tests;

/// <summary>
/// The checks over a published content folder (LIB-R27, LIB-R28, LIB-R31): one line per problem, none when the folder is good.
/// It uses the content reader itself, so a file the reader would not publish is a problem here. It takes the directory, so a test can run it on a folder it wrote.
/// </summary>
internal static class ContentGuard
{
    private const string PublicationsPage = "tsr-publications.md";

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
        return problems;
    }

    /// <summary>Rule 1: only README.md, articles/*.md, categories/*.md and pages/tsr-publications.md. A link, a subfolder or any other file is named.</summary>
    private static IEnumerable<string> UnexpectedEntries(string root)
    {
        foreach (var entry in new DirectoryInfo(root).EnumerateFileSystemInfos())
        {
            var allowedFolder = entry is DirectoryInfo && entry.Name is "articles" or "categories" or "pages";
            if (entry.LinkTarget is not null || !(allowedFolder || (entry is FileInfo && entry.Name == "README.md")))
            {
                yield return Unexpected(entry.Name);
                continue;
            }

            if (entry is DirectoryInfo folder)
            {
                foreach (var inner in InFolder(folder))
                {
                    yield return inner;
                }
            }
        }
    }

    private static IEnumerable<string> InFolder(DirectoryInfo folder)
    {
        foreach (var entry in folder.EnumerateFileSystemInfos())
        {
            var isFile = entry is FileInfo && entry.LinkTarget is null;
            var named = folder.Name == "pages" ? entry.Name == PublicationsPage : entry.Name.EndsWith(".md", StringComparison.Ordinal);
            if (!isFile || !named)
            {
                yield return Unexpected($"{folder.Name}/{entry.Name}");
            }
        }
    }

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
        return problems;
    }
}
