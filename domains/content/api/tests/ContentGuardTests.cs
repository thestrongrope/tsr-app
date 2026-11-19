using System.Globalization;
using NUnit.Framework;

namespace Tsr.Content.Api.Tests;

/// <summary>The guard over the published content folder (LIB-R27, LIB-R28, LIB-R31), on folders a test writes. Invented text only.</summary>
public sealed class ContentGuardTests
{
    private DirectoryInfo root = null!;

    [SetUp]
    public void Start() => root = Directory.CreateTempSubdirectory("tsr-guard-");

    [TearDown]
    public void Stop() => root.Delete(recursive: true);

    private string Path(string relative) => System.IO.Path.Combine(root.FullName, relative);

    private void Write(string relative, string text)
    {
        var path = Path(relative);
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(path)!);
        File.WriteAllText(path, text);
    }

    private void Article(string slug, string status = "publish", string category = "study-habits") =>
        Write($"articles/{slug}.md", string.Create(CultureInfo.InvariantCulture, $"""
            ---
            title: Title of {slug}
            slug: {slug}
            publishedDate: '2024-01-01T08:00:00.000Z'
            {(status.Length == 0 ? "" : "status: " + status)}
            categories:
              - {category}
            ---
            A short invented paragraph about planning a week of study.
            """));

    private void GoodFolder()
    {
        Article("first-article");
        Article("second-article");
        Write("categories/study-habits.md", "---\ntitle: Study Habits\nslug: study-habits\n---\n");
        Write("pages/tsr-publications.md", "---\ntitle: Sample\npublications:\n- title: A Booklet\n  file: /downloads/a-booklet.pdf\n---\n");
        Write("README.md", "Invented folder for a test.\n");
    }

    [Test]
    public void A_good_folder_has_no_problem()
    {
        GoodFolder();

        Assert.That(ContentGuard.Problems(root.FullName), Is.Empty);
    }

    [Test]
    public void An_empty_folder_and_an_unexpected_file_are_problems()
    {
        const string NeedsContent = "the folder needs at least one article and one category";
        Assert.That(ContentGuard.Problems(root.FullName), Does.Contain(NeedsContent), "an empty folder");

        GoodFolder();
        File.Delete(Path("articles/first-article.md"));
        File.Delete(Path("articles/second-article.md"));
        Assert.That(ContentGuard.Problems(root.FullName), Does.Contain(NeedsContent), "a category and a page, no article");

        GoodFolder();
        foreach (var (path, named) in new[] { ("articles/x.markdown", "articles/x.markdown"), ("articles/sub/x.md", "articles/sub"), ("pages/other.md", "pages/other.md"), ("notes.txt", "notes.txt") })
        {
            Write(path, "---\ntitle: X\n---\n");
            var problems = ContentGuard.Problems(root.FullName);

            Assert.That(problems.Count(problem => problem.Contains(named, StringComparison.Ordinal)), Is.GreaterThanOrEqualTo(1), path);

            File.Delete(Path(path));
            if (path.Contains("sub/", StringComparison.Ordinal))
            {
                Directory.Delete(Path("articles/sub"));
            }

            Assert.That(ContentGuard.Problems(root.FullName), Is.Empty, "after removing " + path);
        }
    }

    [Test]
    public void A_link_is_a_problem_that_names_the_path()
    {
        if (OperatingSystem.IsWindows())
        {
            Assert.Ignore("A symbolic link needs a privilege on Windows.");
        }

        GoodFolder();
        File.CreateSymbolicLink(Path("articles/linked.md"), Path("articles/first-article.md"));

        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("articles/linked.md"));
    }

    [TestCase("draft")]
    [TestCase("Publish")]
    [TestCase("")]
    public void A_draft_is_a_problem_that_names_the_file(string status)
    {
        GoodFolder();
        Article("not-published", status);

        var problems = ContentGuard.Problems(root.FullName);

        Assert.That(problems, Has.Some.Contain("articles/not-published.md"));
        Assert.That(problems.Where(problem => problem.Contains("first-article", StringComparison.Ordinal) || problem.Contains("second-article", StringComparison.Ordinal)), Is.Empty);
    }

    [Test]
    public void A_category_without_a_file_is_a_problem_that_names_both()
    {
        GoodFolder();
        Article("third-article", category: "no-such-category");

        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("third-article -> no-such-category"));
    }

    [Test]
    public void A_folder_that_does_not_exist_is_a_problem_not_an_exception()
    {
        Assert.That(ContentGuard.Problems(Path("missing")), Has.Some.Contain("missing"));
    }

    [Test]
    public void A_folder_without_a_publication_is_a_problem()
    {
        GoodFolder();
        File.Delete(Path("pages/tsr-publications.md"));

        Assert.That(ContentGuard.Problems(root.FullName), Is.Not.Empty);
    }
}
